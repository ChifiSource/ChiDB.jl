module ChiDB
using Toolips
import Toolips: on_start, MultiHandler, route!, set_handler!, get_ip4, string
import Base: parse
using AlgebraStreamFrames
import AlgebraStreamFrames: get_datatype, StreamDataType
using Nettle
#=== header
#==
1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 | 16
|    opcode   | transac ID    |          command byte           |       
==#
#==
OPCODE
------
OK            | error
----------------------------
query accept  | bad packet
0001          | 1000
user created  | login denied (connection closed)
0011          | 1100
password set  | bad dbkey (connection closed)
0101          | 1001
              | command error
              | 1110
              | argument error
              | 1010
              | bad transaction (connection closed)
              | 1111
==#
===#
make_transaction_id() = begin
    sampler = ("0", "1")
    join(sampler[rand(1:2)] for val in 1:4)
end

abstract type AbstractDBCommand end

struct DBCommand{T} <: AbstractDBCommand end

mutable struct DBUser
    username::String
    pwd::String
    key::String
    transaction_id::String
    table::String
end

struct Transaction
    id::String
    cmd::Char
    operands::Vector{Any}
    username::String
end

string(ts::Transaction) = "$(ts.id)|$(ts.username): $(ts.cmd) ; $(operands)\n"

mutable struct DeeBee <: Toolips.SocketServerExtension
    dir::String
    tables::Dict{String, StreamFrame}
    # IP, transactionID
    transaction_ids::Dict{IP4, String}
    # Stored transaction history (occassionally dumped)
    transactions::Vector{Transaction}
    # reference info, helps keep row numbers consistent across all connected tables
    refinfo::Dict{String, Vector{String}}
    cursors::Vector{DBUser}
    enc::Encryptor
    dec::Decryptor
    function DeeBee(dir::String)
        new(dir, Dict{String, StreamFrame}(), 
            Dict{IP4, String}(), Vector{Transaction}(), 
            Dict{String, Vector{String}}(),
            Vector{DBUser}(), Encryptor("AES256", Toolips.gen_ref(32)), 
            Decryptor("AES256", Toolips.gen_ref(32)))
    end
end

load_schema!(db::DeeBee) = begin
    db.tables = Dict{String, StreamFrame}()
    db.refinfo = Dict{String, Vector{String}}()
    for path in readdir(db.dir)
        table_path::String = db.dir * "/" * path
        if ~(isdir(table_path)) || path == "db"
            continue
        end
        features = []
        references = []
        cols = readdir(table_path)
        if length(cols) == 0
            push!(db.tables, path => StreamFrame{:ff}())
            continue
        end
        for file in cols
            if contains(file, ".ff")
                push!(features, replace(file, ".ff" => "") => table_path * "/$file")
            elseif contains(file, ".ref")
                push!(references, replace(file, ".ref" => ""))
            end
        end
        this_frame = StreamFrame(features ...)
        if length(references) > 0
            push!(db.refinfo, path => Vector{String}())
        end
        for ref in references
            T = AlgebraStreamFrames.infer_type(readlines(db.dir * "/" * replace(ref, "_" => "/"))[1])
            namesplits = split(ref, "_")
            colname = namesplits[2]
            framename = namesplits[1]
            join!(this_frame, string(colname) => T) do e
                db.tables[framename][colname][e]
            end
            push!(db.refinfo[path], framename)
        end
        push!(db.tables, path => this_frame)
    end
end

function dump_transactions!(db::DeeBee)
    open(db.dir * "/db/history.txt", "a") do o::IOStream
        for (e, tsact) in enumerate(db.transactions)
            write(o, string(tsact))
        end
    end
    db.transactions = Vector{Transaction}()
end

function setup_dbdir(db::DeeBee, dir::Bool = false)
    dbdir = db.dir * "/db"
    if dir
        mkdir(dbdir)
    end
    secrets_dir = dbdir * "/secrets.txt"
    touch(secrets_dir)
    users_dir = dbdir * "/users.txt"
    touch(users_dir)
    touch(dbdir * "/history.txt")
    keydir = dbdir * "/key.pem"
    touch(keydir)
    hmac = Toolips.gen_ref(32)
    admin_ref = Toolips.gen_ref(16)
    admin_keyenc =Toolips.gen_ref(32)
    db.enc = Encryptor("AES256", hmac)
    open(keydir, "w") do o::IOStream
        write(o, hmac)
    end
    open(users_dir, "w") do o::IOStream
        write(o, "admin")
    end
    open(secrets_dir, "w") do o::IOStream
        write(o, String(encrypt(db.enc, add_padding_PKCS5(Vector{UInt8}(admin_ref), 16))) * "DIV" * admin_keyenc * "!EOF")
    end
    @info "ChiDB server started for the first time at $(db.dir)"
    @info "admin login: ($admin_keyenc) admin $admin_ref"
    @info "pem: $hmac"
end

function load_db!(db::DeeBee)
    db.cursors = Vector{DBUser}()
    if ~(isdir(db.dir * "/db"))
        setup_dbdir(db, true)
    elseif ~(isfile(db.dir * "/db/key.pem"))
        setup_dbdir(db)
    end
    hmac = read(db.dir * "/db/key.pem", String)
    usernames = readlines(db.dir * "/db/users.txt")
    wds = split(read(db.dir * "/db/secrets.txt", String), "!EOF")
    for usere in 1:length(usernames)
        pwd_key = split(wds[usere], "DIV")
        push!(db.cursors, DBUser(usernames[usere], 
            string(pwd_key[1]), 
            string(replace(pwd_key[2], "\n" => "", "!EOF" => "")), "", ""))
        @info "loaded dbuser $(usernames[usere])"
    end
    db.enc = Encryptor("AES256", hmac)
    db.dec = Decryptor("AES256", hmac)
    @info String(decrypt(db.dec, Vector{UInt8}(db.cursors[1].pwd)))
end

function save_users(db::DeeBee)
    secrets = ""
    users = ""
    for user in db.cursors
        pwd = ""
    end
end

function on_start(data::Dict{Symbol, Any}, db::DeeBee)
    load_db!(db)
    load_schema!(db)
    push!(data, :DB => db)
end

function parse_db_header(header::String)
    if ~(length(header) == 2)
        throw("Invalid DB header: length does not equal two.")
    end
    optrans = bitstring(UInt8(header[1]))
    @warn "OPTRANS: $optrans"
    opcode = optrans[1:4]
    transaction_id = optrans[5:8]
    return(opcode, transaction_id, header[2])
end

verify = handler() do c::Toolips.SocketConnection
    query = ""
    selected_user = nothing
    while true
        query::String = query * String(readavailable(c))
        n = length(query)
        if ~(query[end] == '\n')
            yield()
            continue
        else
            @info "completed query"
        end
        opcode::String, trans_id::String, cmd::Char = parse_db_header(query[1:2])
        if ~(cmd == 'S')
            @info "returned bad cmd"
            return
        end
        operands = split(query[3:end], " ")
        db_key = operands[1]
        user = operands[2]
        pwd = string(operands[3])
        @warn "provided user: $user"
        @warn "provided pwd: $pwd"
        @warn length(pwd)
        @warn "provided dbkey: $db_key"
        cursors = c[:DB].cursors
        usere = findfirst(u -> u.username == user, cursors)
        if isnothing(usere)
            header = "1100" * make_transaction_id() * "\n"
            write!(c, "$(Char(parse(UInt8, header, base = 2)))")
            @info "no usere"
            return
        end
        selected_user = cursors[usere]
        if ~(pwd[1:end - 1] == String(trim_padding_PKCS5(decrypt(c[:DB].dec, selected_user.pwd))))
            @info pwd[1:end - 1]
            @warn String(decrypt(c[:DB].dec, selected_user.pwd))
            header = "1100" * make_transaction_id() * "\n"
            write!(c, "$(Char(parse(UInt8, header, base = 2)))")
            return
        end
        if db_key != selected_user.key
            @warn "invalid dbkey return"
            header = "1001" * make_transaction_id() * "\n"
            write!(c, "$(Char(parse(UInt8, header, base = 2)))")
            return
        end
        trans_id = make_transaction_id()
        selected_user.transaction_id = trans_id
        @warn "set trans id: $trans_id"
        push!(c[:DB].transactions, Transaction(trans_id, 'S', [db_key, user], 
        selected_user.username))
        header_b = Char(parse(UInt8, "0001" * trans_id, base = 2))
        write!(c, "$header_b" * "\n")
        @info "verified client $(selected_user.username)"
        break
    end
    query = ""
    while true
        if eof(c.stream)
            query = ""
            break
        end
        current_quer = String(readavailable(c))
        if current_quer == "\n"
            yield()
            continue
        end
        query = query * current_quer
        if ~(length(query) > 0 && query[end] == '\n')
            yield()
            continue
        else
            @info "completed query"
            @warn query
        end
        query = replace(query, "\n" => "")
        if query == "clear"
            query = ""
            yield()
            continue
        end
        opcode, trans_id, cmd = (nothing, nothing, nothing)
        arg_step = false
        try
            try
                opcode, trans_id, cmd = parse_db_header(query[1:2])
            catch
                optrans = bitstring(UInt8(query[1]))
                cmd = query[3]
                opcode = optrans[1:4]
                trans_id = optrans[5:8]
                arg_step = true
            end
        catch e
            @warn "malformed packet recieved from $(get_ip4(c)) (continuing)"
            @warn e
            @warn query
            query = ""
            header = "1000" * make_transaction_id()
            write!(c, "$(Char(parse(UInt8, header, base = 2)))")
            continue
        end
        if trans_id != selected_user.transaction_id
            header = "1111" * make_transaction_id()
            write!(c, "$(Char(parse(UInt8, header, base = 2)))")
            return
        end
        command = DBCommand{Symbol(cmd)}
        args = Vector{SubString{String}}()
        if length(query) > 2
            if arg_step
                args = split(query[4:end], "|!|")
            else
                args = split(query[3:end], "|!|")
            end
        end
        success, output = (nothing, nothing)
        try
            success, output = perform_command!(selected_user, command, args ...)
        catch e
            query = ""
            io = IOBuffer()
            showerror(io, e)
            msg = String(take!(io))
            @warn "Caught Exception" exception_type=typeof(e) message=msg
            	@warn "Stacktrace:"
	        for (i, frame) in enumerate(stacktrace(catch_backtrace()))
		        @warn "$i: $frame"
	        end
            @sync throw(e)
            yield()
            continue
        end
        trans_id = make_transaction_id()
        selected_user.transaction_id = trans_id
        header = ""
        output = "\n" * output
        if success == 0
            header = "0001" * trans_id
            push!(c[:DB].transactions, Transaction(trans_id, cmd, args, 
            selected_user.username))
        elseif success == 1
            # (command error)
            header = "1110" * trans_id
        elseif success == 2
            # argument error
            header = "1010" * trans_id
        elseif success == 4
            break
        end
        write!(c, "$(Char(parse(UInt8, header, base = 2)))%" * output * "\n")
        if length(c[:DB].transactions) > 50
            dump_transactions!(db::DeeBee)
        end
        query = ""
        yield()
        continue
    end
end

DB_EXTENSION = DeeBee("")

function perform_command!(user::DBUser, cmd::Type{<:AbstractDBCommand}, args::AbstractString ...)
    return(1, "command does not exist")
end

include("commands.jl")

function start(path::String, ip::IP4 = "127.0.0.1":8005; async::Bool = false)
    @warn "ChiDB is not yet fully functional or ready for production use."
    @info "this version is primarily being used for testing, at the moment. This project is a work-in-progress."
    DB_EXTENSION.dir = path
    start!(:TCP, ChiDB, ip, async = async)
end

export DB_EXTENSION, verify
end # module ChiDB
