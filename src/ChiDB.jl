module ChiDB
using Toolips
import Toolips: on_start
using AlgebraFrames
using AlgebraStreamFrames
using Nettle

struct DBCommand{T} end

struct DBUser
    username::String
    pwd::String
    access_key::String
    table::String
end

struct Transaction
    cmd::Char
    operands::Vector{Any}
    username::String
end

mutable struct DeeBee <: Toolips.AbstractExtension
    dir::String
    tables::Dict{String, StreamFrame}
    # (transaction ID, status)
    command_available::Dict{UInt16, UInt8}
    # IP, transactionID
    transaction_ids::Dict{String, UInt16}
    # Stored transaction history (occassionally dumped)
    transactions::Vector{Transaction}
    # (opcode, transactionid)
    opcode::Dict{UInt16, UInt16}
    cursors::Vector{DBUser}
    enc::Encryptor
    dec::Decryptor
    function DeeBee(dir::String)
        command_available = Dict{UInt16, UInt8}()
    end
end

function command!(db::DeeBee, command::DBCommand{<:Any})
    false::Bool
end

load_schema!(db::DeeBee) = begin
    for path in readdir(db.dir)
        table_path::String = db.dir * "/" * path
        if ~(isdir(table_path)) || path == "db"
            continue
        end
        features = []
        references = []
        for file in readdir(table_path)
            if contains(file, ".ff")
                push!(features, replace(file, ".ff" => "") => table_path * "/$file")
            elseif contains(file, ".ref")
                push!(references, replace(file, ".ref" => ""))
            end
        end
        this_frame = StreamFrame(features ...)
        for ref in references
            T = AlgebraStreamFrames.infer_type(readlines(db.dir * "/" * replace(ref, "_" => "/"))[1])
            namesplits = split(ref, "_")
            colname = namesplits[2]
            framename = namesplits[1]
            join!(this_frame, string(colname) => T) do e
                db.tables[framename][colname][e]
            end
        end
        push!(db, path => this_frame)
    end
end

function dump_transactions!(db::DeeBee)

end

function setup_dbdir(db::DeeBee; dir::Bool = false)
    if dir
        mkdir(db.dir * "/db")
    end
    touch(db.dir * "/secrets.txt")
    users_dir = db.dir * "/users.txt"
    touch(users_dir)
    touch(db.dir * "/history.txt")
    keydir = db.dir * "/key.pem"
    touch(keydir)
    hmac = Toolips.gen_ref(32)
    admin_ref = Toolips.gen_ref(16)
    open(keydir, "w") do o::IOStream
        write(o, hmac)
    end
    db.enc = Encryptor("AES256", hmac)
    open(users_dir) do o::IOStream
        write(o, "admin")
    end
    open(secrets_dir) do o::IOStream
        write(o, encrypt(db.enc, admin_ref))
    end
    @info "ChiDB server started for the first time at $(db.dir)"
    @info "admin login: admin $admin_ref"
    @info "pem: $hmac"
end

function load_db!(db::DeeBee)
    if ~(isdir(db.dir * "/db"))
        setup_dbdir(db, true)
    elseif ~(isfile(db.dir * "/secrets.txt"))
        setup_dbdir(db)
    end
    hmac = read(db.dir * "/secrets.txt", String)
    db.enc = Encryptor("AES256", hmac)
    db.dec = Decryptor("AES256", hmac)
end

function on_start(data::Dict{Symbol, Any}, db::DeeBee)
    load_db!(db)
    load_schema!(db)
    push!(data, :DB => db)
end

#==
1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 | 16
|    opcode   | transac ID    |          command byte           |       
==#

function parse_db_header(header::String)
    if ~(length(header) == 2)
        throw("Invalid DB header: length does not equal two.")
    end
    optrans = bitstring(UInt32(header[1]))
    opcode = parse(UInt16, optrans[1:4])
    transaction_id = parse(UInt16, optrans[5:8])
    return(opcode, transaction_id, header[2])
end

verify = handler() do c::Toolips.SocketConnection
    query::String = read_all(c)
    n = length(query)
    if ~(n > 3)
        return
    end
    opcode::UInt16, trans_id::UInt16, cmd::Char = parse_db_header(query[1:2])
    if ~(cmd == 'S')
        return
    end
    operands = query[3:end]
    write!(c, "")
end

#==
example set header
OPTRANSB|S|username db_key password
==#


multi_handler = MultiHandler(verify, ip4 = false)

function start(path::String, ip::IP4 = "127.0.0.1":8000)
    DB_EXTENSION.dir = path
    start!(ChiDB, ip)
end

export multi_handler
end # module ChiDB
