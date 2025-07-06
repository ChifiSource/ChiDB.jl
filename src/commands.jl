#==
COMMAND TABLE:
# server
S - login
U - list users
C - create user
K - set
L - logout

# query
#  table management
l - list
s - select
t - create

# get-store
g - get
r - getrow
i - index
a - store
v - set
w - setrow

# column management
j - join
k - type
e - rename

# deleters
d - deleteat
z - delete

# built-in operations
p - compare
n - in
==#
#==
Table Commands
==#
# list tables
function get_selected_col(user::DBUser, arg::AbstractString)
    table_selected = ""
    col_selected = ""
    if ~(contains(arg, "/"))
        if user.table == ""
            return(2, "proper table path not selected")
        end
        table_selected = user.table
        col_selected = arg
    else
        splts = split(arg, "/")
        table_selected = splts[1]
        col_selected = splts[2]
    end
    if ~(table_selected in keys(DB_EXTENSION.tables))
        return(2, "$table_selected not found in DB")
    elseif ~(col_selected in names(DB_EXTENSION.tables[table_selected]))
        return(2, "column $col_selected not found in $table_selected")
    end
    return(table_selected, col_selected)
end

function perform_command!(user::DBUser, cmd::Type{DBCommand{:l}}, args::AbstractString ...)
    if length(args) > 0
        name = args[1]
        if ~(name in keys(DB_EXTENSION.tables))
            return(2, "$name is not a table, to list all tables provide no arguments.")
        end
        selected_table = DB_EXTENSION.tables[name]
        colstr = join([begin
            "$(selected_table.names[e]) $(selected_table.T[e])!N"
        end for e in 1:length(selected_table.names)], "\n")
        return(0, "$name ($(length(selected_table.names)) columns $(length(selected_table)) rows !N" * colstr)
    end
    list = keys(DB_EXTENSION.tables)
    if length(list) < 1
        return(0, "empty data-base (0 columns)")
    end
    return(0, 
        join(
    "$k ($(length(DB_EXTENSION.tables[k].names)) columns)\n" for k in keys(DB_EXTENSION.tables)))
end
# select table
function perform_command!(user::DBUser, cmd::Type{DBCommand{:s}}, args::AbstractString ...)
    if length(args) < 1
        user.table = ""
        return(0, "")
    end
    if ~(args[1] in keys(DB_EXTENSION.tables))
        return(2, "table $(args[1]) does not exist")
    end
    user.table = args[1]
    return(0, "")
end
# create table
function perform_command!(user::DBUser, cmd::Type{DBCommand{:t}}, args::AbstractString ...)
    if length(args) < 1
        return(2, "create requires table name or column")
    end
    newname = args[1]
    if newname in keys(DB_EXTENSION.tables)
        return(2, "table $newname exists")
    end
    new_table = StreamFrame{:ff}()
    push!(DB_EXTENSION.tables, newname => new_table)
    mkdir(DB_EXTENSION.dir * "/$newname")
    return(0, "")
end

#==
Get-store commands
==#
# get
function perform_command!(user::DBUser, cmd::Type{DBCommand{:g}}, args::AbstractString ...)
    n = length(args)
    if n < 1
        return(2, "get column requires a column directory")
    end
    table_selected, col_selected = get_selected_col(user, args[1])
    if typeof(table_selected) == Int64
        return(table_selected, col)
    end
    if n > 1
        range_sel = args[2]
        @info range_sel
        selected_ind = 1
        if range_sel == "where"
            wherelookup = Dict("==" => ==, "<" => <, "<=" => <=, 
                ">=" => >=, ">" => >)
            if n < 5
                if ~(args[4] in keys(wherelookup))
                    return(2, "unrecognized operator: $(args[4])")
                end
                generated = generate(DB_EXTENSION.tables[string(table_selected)])
                filter!(row -> wherelookup[args[4]](string(row[args[3]]), row[args[5]]), generated)
                return(0, "future tablestring")
            end
        end
        if contains(range_sel, ":")
            vals = split(range_sel, ":")
            selected_ind = try
                parse(Int64, vals[1]):parse(Int64, vals[2])
            catch
                return(2, "could not parse range")
            end
        else
            selected_ind = try
                parse(Int64, range_sel)
            catch
                return(2, "could not parse index")
            end
        end
        generated = DB_EXTENSION.tables[string(table_selected)][string(col_selected)]
        return(0, join((string(gen) for gen in generated[selected_ind]), "!;"))
    end
    generated = DB_EXTENSION.tables[string(table_selected)][string(col_selected)]
    return(0, join((string(gen) for gen in generated), "!;"))
end
# get row
function perform_command!(user::DBUser, cmd::Type{DBCommand{:r}}, args::AbstractString ...)
    table_selected = ""
    ind = ""
    if length(args) > 1
        table_selected = args[1]
        ind = args[2]
    else
        if user.table == ""
            return(2, "no table provided or selected for row")
        end
        table_selected = user.table
        ind = args[1]
    end
    if contains(ind, ":")
        parts = split(ind, ":")
        ind = parse(Int64, parts[1]):parse(Int64, parts[2])
    else
        ind = parse(Int64, args[2])
    end
    gen = generate(DB_EXTENSION.tables[table_selected])
    rows = AlgebraStreamFrames.framerows(gen)[ind]
    if typeof(ind) == Int64
        rows = [rows]
    end
    result = join((begin
            join((string(val) for val in row.values), "!;")
        end for row in rows), "!N")
    return(0, result)
end
# get index
function perform_command!(user::DBUser, cmd::Type{DBCommand{:i}}, args::AbstractString ...)
    selected_table, col_selected = get_selected_col(user, args[1])
    if typeof(selected_table) == Int64
        return(selected_table, col)
    end
    value = args[2]
    sel = DB_EXTENSION.tables[string(selected_table)]
    gen = sel[string(col_selected)]
    ind = findfirst(x -> string(x) == value, gen)
    if isnothing(ind)
        return(0, "0")
    end
    return(0, string(ind))
end

# store
function perform_command!(user::DBUser, cmd::Type{DBCommand{:a}}, args::AbstractString ...)
    n = length(args)
    if n < 1
        return(1, "command `a` takes 2-3 arguments")
    end
    tbl = args[1]
    selected_table = DB_EXTENSION.tables[tbl]
    if n == 2
        val = args[2]
        writevals = split(val, "!;")
        store_into!(string(tbl), selected_table, writevals ...)
        selected_table.length += 1
    else n == 3
        pos = args[2]
        val = args[3]
        writevals = split(val, "!;")
        store_into!(parse(pos, Int64), string(tbl), selected_table, writevals ...)
    end
    return(0, "added row")
end

function store_into!(tblname::AbstractString, selected_table::AlgebraStreamFrames.AlgebraFrames.AbstractAlgebraFrame, writevals::Any ...)
    table_paths = keys(selected_table.paths)
    refwrites = Dict()
    for cole in 1:length(selected_table.names)
        colname = selected_table.names[cole]
        if ~(colname in table_paths)
            # reftables
            push!(refwrites, colname => writevals[cole])
            continue
        end
        open(selected_table.paths[colname], "a") do o::IOStream
            write(o, writevals[cole] * "\n")
        end
    end
    if tblname in keys(DB_EXTENSION.refinfo)
        for reftable in DB_EXTENSION.refinfo[tblname]
            this_table = DB_EXTENSION.tables[reftable]
            vals = (begin
                this_T = this_table.T[cole]
                colname = this_table.names[cole]
                if colname in keys(refwrites)
                    string(refwrites[colname]) * "\n"
                else
                    AlgebraStreamFrames.AlgebraFrames.algebra_initializer(this_T)
                end
            end for cole in 1:length(this_table.names))
            store_into!(reftable, this_table, vals ...)
            this_table.length += 1
        end
    end
end

function perform_command!(user::DBUser, cmd::Type{DBCommand{:v}}, args::AbstractString ...)

end

#==
column management
==#
# join
function perform_command!(user::DBUser, cmd::Type{DBCommand{:j}}, args::AbstractString ...)
    n = length(args)
    T = nothing
    colname = nothing
    table = nothing
    if n < 2
        return(2, "invalid arguments (join requires at least 2 arguments)")
    elseif n == 2
        if contains(args[1], "/")
            splts = split(args[1], "/")
            colname = string(splts[2])
            table = string(splts[1])
        else
            table = string(args[1])
        end
        T = args[2]
        # reference join?
        if contains(args[2], "/")
            newn = replace(args[2], "/" => "_")
            @warn "DIR::::"
            @warn DB_EXTENSION.dir * "/$table/" * "$(newn).ref"
            @warn table
            @warn colname
            touch(DB_EXTENSION.dir * "/$table/" * "$(newn).ref")
            nm_splits = split(args[2], "/")
            reftable = string(nm_splits[1]) 
            refcol = string(nm_splits[2])
            reftab = DB_EXTENSION.tables[reftable]
            @info refcol
            @info reftab.names
            axis = findfirst(n -> n == refcol, reftab.names)
            T = reftab.T[axis]
            join!(DB_EXTENSION.tables[table], string(refcol) => T) do e
                DB_EXTENSION.tables[reftable][refcol][e]
            end
            return(0, "")
        end
    else
        T = args[3]
        colname = args[2]
        table = args[1]
    end
    T = get_datatype(AlgebraStreamFrames.StreamDataType{Symbol(T)})
    n = length(DB_EXTENSION.tables[table])
    newpath = DB_EXTENSION.dir * "/$table/$colname.ff"
    touch(newpath)
    open(newpath, "w") do o::IOStream
        write(o, string(T) * "\n")
        val = AlgebraStreamFrames.AlgebraFrames.algebra_initializer(T)(1)
        write(o, join((string(val) for x in 1:n), "\n"))
    end
    join!(DB_EXTENSION.tables[table], T, string(colname) => newpath)
    return(0, "")
end
# set type
function perform_command!(user::DBUser, cmd::Type{DBCommand{:k}}, args::AbstractString ...)
    colrow = args[1]
    if length(args) < 2
        return(2, "set type takes 2 arguments (table)/column Type")
    end
    table, col = get_selected_col(user, args[1])
    if typeof(table) == Int64
        return(table, col)
    end
    if ~(table in keys(DB_EXTENSION.tables))
        return(2, "table $table not found")
    end
    sel_table = DB_EXTENSION.tables[table]
    if ~(col in sel_table.names)
        return(2, "$col not in $table")
    end
    # get axis and actual T
    axis = findfirst(x -> x == col, sel_table.names)
    stream_type = StreamDataType{Symbol(args[2])}
    sel_table.T[axis] = get_datatype(stream_type)
    if col in keys(table.paths)
        alllines = read(table.paths[col], String)
        flinef = findfirst("\n", alllines)
        output = if isnothing(flinef)
            args[2] * "\n"
        else
            args[2] * alllines[flinef:end]
        end
        open(table.paths[col], "w") do o::IOStream
            write(o, output)
        end
        output = nothing
        alllines = nothing
    else
        direc = readdir(DB_EXTENSION.dir * "/$table")
        refname = findfirst(x -> contains(x, "$col.ref"), direc)
        ref_tablen = split(direc[refname], "_")[1]
        ref_table = DB_EXTENSION.tables[ref_tablen]
        axis = findfirst(x -> x == col, ref_table.names)
        ref_table.T[axis] = get_datatype(stream_type)
        alllines = read(ref_table.paths[ref_tablen], String)
        flinef = findfirst("\n", alllines)
        output = if isnothing(flinef)
            args[2] * "\n"
        else
            args[2] * alllines[flinef:end]
        end
        open(ref_table.paths[ref_tablen], "w") do o::IOStream
            write(o, output)
        end
    end
    return(0, "type set")
end
# rename
function perform_command!(user::DBUser, cmd::Type{DBCommand{:e}}, args::AbstractString ...)
    if ~(length(args) == 2)
        return(2, "rename takes two arguments (column and newname)")
    end
    if ~(contains(args[1], "/"))
        if args[1] in keys(DB_EXTENSION.tables)
            mv(DB_EXTENSION.dir * "/$(args[1])", DB_EXTENSION.dir * "/$(args[2])", force = true)
            load_schema!(DB_EXTENSION)
            return(0, "table renamed")
        end
    end
    table, col = get_selected_col(user, args[1])
    if typeof(table) == Int64
        return(table, col)
    end
    sel_table = DB_EXTENSION.tables[table]
    if ~(col in keys(sel_table.paths))
        return(2, "cannot rename a reference column, rename the original column instead")
    end
    pos = findfirst(x -> x == col, sel_table.names)
    sel_table.names[pos] = string(args[2])
    new_fpath = DB_EXTENSION.dir * "/$table/$(args[2]).ff"
    mv(sel_table.paths[col], new_fpath)
    sel_table.paths[col] = new_fpath
    return(0, "column renamed")
end

#==
deleters
==#
# delete at
function perform_command!(user::DBUser, cmd::Type{DBCommand{:d}}, args::AbstractString ...)
    n = length(args)
    if n != 2
        return(2, "deleteat requires two arguments")
    end
    table, col = get_selected_col(user, cmd)
    if typeof(table) == Int64
        return(table, col)
    end 
    this_table = DB_EXTENSION.tables[table][col]
    
end
# delete
function perform_command!(user::DBUser, cmd::Type{DBCommand{:z}}, args::AbstractString ...)
    if length(args) < 1
        if user.table == ""
            return(2, "delete requires a row or table to delete")
        else
            
        end
    end
    table = ""
    col = ""
    if contains(args[1], "/")

    else
        if ~(args[1] in keys(DB_EXTENSION.tables))
            if user.table == ""
                return(2, "$(args[1]) is not a table or column path. No valid table selected.")
            end
            
        end

    end

end
# compare
function perform_command!(user::DBUser, cmd::Type{DBCommand{:p}}, args::AbstractString ...)
    table, col = get_selected_col(user, args[1])
    if typeof(table) == Int64
        return(table, col)
    end
    if length(args) != 3
        return(2, "compare takes three arguments")
    end
    index = parse(Int64, args[2])
    sel_value = DB_EXTENSION.tables[table][col][index]
    if string(sel_value) == args[3]
        return(0, "1")
    else
        return(0, "0")
    end
end
# in
function perform_command!(user::DBUser, cmd::Type{DBCommand{:n}}, args::AbstractString ...)
    if length(args) != 2
        return(2, "in takes a (table)/column and a value")
    end
    table, col = get_selected_col(user, args[1])
    if typeof(table) == Int64
        return(table, col)
    end
    sel_col = DB_EXTENSION.tables[table][col]
    compval = args[2]
    found = findfirst(val -> string(val) == compval, sel_col)
    if ~(isnothing(found))
        return(0, "1")
    else
        return(0, "0")
    end
end

#==
server
==#

function perform_command!(user::DBUser, cmd::Type{DBCommand{:S}}, args::AbstractString ...)
    return(1, "cannot login while logged in. please disconnect first.")
end

# list users
function perform_command!(user::DBUser, cmd::Type{DBCommand{:U}}, args::AbstractString ...)
    return(0, join((user.username for user in DB_EXTENSION.users), "\n"))
end

# create user
function perform_command!(user::DBUser, cmd::Type{DBCommand{:C}}, args::AbstractString ...)
    n = length(args)
    if n == 0
        return(1, "the create user command takes a username and optionally a password.")
    end
    newname = args[1]
    newpd = if n == 1
        gen_ref(32)
    else
        args[2]
    end
    new_dbkey = Toolips.gen_ref(32)
    return(0, "$(newname)!;$(newpd)!;$(new_dbkey)")
end

# set
function perform_command!(user::DBUser, cmd::Type{DBCommand{:K}}, args::AbstractString ...)
    n = length(args)
    if ~(n in (2, 3))
        return(2, "'set' takes at most 3 arguments, at minimum 2 (user, name, pwd)")
    end
    index = findfirst(usr -> usr.username == args[1], DB_EXTENSION.users)
    if isnothing(index)
        return(2, "user $(args[1]) not found")
    end
    this_user = DB_EXTENSION.users[index]
    this_user.username = strings(arg[2])
    this_user.pwd = encrypt(DB_EXTENSION.enc, Nettle.add_padding_PKCS5(Vector{UInt8}(args[3]), 16))
    this_user.key = gen_ref(32)
    return(0, "$(this_user.username)!;$(args[2])!;$(this_user.key)")
end
# logout
function perform_command!(user::DBUser, cmd::Type{DBCommand{:L}}, args::AbstractString ...)
    user.selected_table = ""
    return(4, "")
end

