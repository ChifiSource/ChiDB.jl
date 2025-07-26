#==
COMMAND TABLE:
# server
S - login
U - list users
C - create user
K - set
L - logout
D - rmuser
# query
#  table management
l - list
s - select
t - create
o - columns

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

function perform_command!(user::DBUser, cmd::Type{DBCommand{:o}}, args::AbstractString ...)
    table = args[1]
    if ~(haskey(DB_EXTENSION.tables, table))
        return(2, "$table not found in database")
    end
    return(0, join(DB_EXTENSION.tables[table].names, "!;"))
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
        return(0, "$name ($(length(selected_table.names)) columns $(length(selected_table)) rows)!N" * colstr)
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
    refwrites = Dict{String, SubString}()
    writevals = [writevals ...]
    for cole in 1:length(selected_table.names)
        colname = selected_table.names[cole]
        if ~(colname in table_paths)
            # reftables
            push!(refwrites, colname => writevals[cole])
            continue
        end
        T = selected_table.T[cole]
        if T == CryptString
            writevals[cole] = base64encode(encrypt(DB_EXTENSION.enc, sha256(writevals[cole])))
        end
        lastval = read(selected_table.paths[colname], String)[end]
        open(selected_table.paths[colname], "a") do o::IOStream
            if lastval != '\n'
                write(o, "\n" * writevals[cole])
                return
            end
            write(o,  writevals[cole])
        end
    end
    if tblname in keys(DB_EXTENSION.refinfo)
        for reftable in DB_EXTENSION.refinfo[tblname]
            this_table = DB_EXTENSION.tables[reftable]
            n_names = length(this_table.names)
            vals = (begin
                this_T = this_table.T[cole]
                colname = this_table.names[cole]
                if colname in keys(refwrites)
                    string(refwrites[colname])
                else
                    AlgebraStreamFrames.AlgebraFrames.algebra_initializer(this_T)
                end
            end for cole in 1:length(this_table.names))
            store_into!(reftable, this_table, vals ...)
            this_table.length += 1
        end
    end
end
# set
function perform_command!(user::DBUser, cmd::Type{DBCommand{:v}}, args::AbstractString ...)
    table, col = get_selected_col(user, args[1])
    if typeof(table) <: Integer
        return(table, col)
    end
    if length(args) != 3
        return(2, "set requires a table/column (1), row (2), and value (3)")
    end
    rown = 0
    try
        rown = parse(Int64, args[2])
    catch
        return(2, "failed to parse row: $(args[2])")
    end
    sel_tab = DB_EXTENSION.tables[table]
    path = if ~(col in keys(sel_tab.paths))
        direc = readdir(DB_EXTENSION.dir * "/$table")
        refname = findfirst(x -> contains(x, "$col.ref"), direc)
        ref_table = DB_EXTENSION.refinfo[col]
        ref_tablen = split(direc[refname], "_")[1]
        ref_table = DB_EXTENSION.tables[ref_tablen]
        ref_table.paths[col]
    else
        sel_tab.paths[col]
    end
    all_lines = readlines(path)
    if length(all_lines) <= rown
        return(2, "index error; index $(rown) on $(length(all_lines))")
    end
    all_lines[rown + 1] = args[3]
    open(path, "w") do o::IOStream
        write(o, join(all_lines, "\n"))
    end
    return(0, "value updated")
end
# set row
function perform_command!(user::DBUser, cmd::Type{DBCommand{:w}}, args::AbstractString ...)
    n = length(args)
    inp = ""
    table, rown = if n == 2
        table = user.table
        if user.table == ""
            return(2, "only row and values provided, and no table selected.")
        end
        rown = try
            parse(args[1], Int64)
        catch
            return(2, "failed to parse row: $(args[1])")
        end
        inp = args[2]
        (table, rown)
    elseif n == 3
        table = args[1]
        rown = try
            parse(Int64, args[2])
        catch
            return(2, "failed to parse row: $(args[2])")
        end
        inp = args[3]
        (table, rown)
    else
        return(2, "set row takes three arguments, or two with a table selected.")
    end
    sel_table = DB_EXTENSION.tables[table]
    if rown > length(sel_table)
        return(2, "row requested is greater than length of table ($(length(sel_table)))")
    end
    n = length(sel_table.names)
    valsplts = split(inp, "!;")
    if ~(length(valsplts) == n)
        return(2, "not enough values provided for each row")
    end
    path_keys = keys(sel_table.paths)
    if sel_table.length <= rown
        return(2, "index error; index $(rown) on $(length(vals))")
    end
    for e in 1:n
        colname = sel_table.names[e]
        path = if ~(colname in path_keys)
            direc = readdir(DB_EXTENSION.dir * "/$table")
            refname = findfirst(x -> contains(x, "$colname.ref"), direc)
            direc = direc[refname]
            ref_tablen = split(direc, "_")[1]
            ref_table = DB_EXTENSION.tables[ref_tablen]
            ref_table.paths[colname]
        else
            sel_table.paths[colname]
        end
        vals = readlines(path)
        vals[rown + 1] = valsplts[e]
        open(path, "w") do o::IOStream
            write(o, join(vals, "\n"))
        end
    end
    return(0, "set row values")
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
            if user.table == ""
                return(2, "no table provided to join to")
            end
            colname = string(args[1])
            table = user.table
        end
        T = args[2]
        # reference join?
        if contains(args[2], "/")
            newn = replace(args[2], "/" => "_")
            touch(DB_EXTENSION.dir * "/$table/" * "$(newn).ref")
            nm_splits = split(args[2], "/")
            reftable = string(nm_splits[1]) 
            refcol = string(nm_splits[2])
            if table in keys(DB_EXTENSION.refinfo)
                push!(DB_EXTENSION.refinfo[table], string(reftable))
            else
                DB_EXTENSION.refinfo[table] = Vector{String}([string(reftable)])
            end
            reftab = DB_EXTENSION.tables[reftable]
            axis = findfirst(n -> n == refcol, reftab.names)
            T = reftab.T[axis]
            join!(DB_EXTENSION.tables[table], string(refcol) => T) do e
                reftab[refcol][e]
            end
            return(0, "")
        end
    else
        T = args[3]
        colname = args[2]
        table = args[1]
    end
    n = length(DB_EXTENSION.tables[table])
    DT = get_datatype(AlgebraStreamFrames.StreamDataType{Symbol(T)})
    newpath = DB_EXTENSION.dir * "/$table/$colname.ff"
    touch(newpath)
    open(newpath, "w") do o::IOStream
        write(o, string(T) * "\n")
        if n > 0
            val = AlgebraStreamFrames.AlgebraFrames.algebra_initializer(DT)(1)
            write(o, join((string(val) for x in 1:n), "\n"))
        end
    end
    join!(DB_EXTENSION.tables[table], DT, string(colname) => newpath)
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
    if col in keys(sel_table.paths)
        alllines = read(sel_table.paths[col], String)
        flinef = findfirst("\n", alllines)
        output = if isnothing(flinef)
            args[2] * "\n"
        else
            args[2] * alllines[minimum(flinef):end]
        end
        open(sel_table.paths[col], "w") do o::IOStream
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
    T = sel_table.T[pos]
    new_fpath = DB_EXTENSION.dir * "/$table/$(args[2]).ff"
    mv(sel_table.paths[col], new_fpath)
    sel_table.paths[col] = new_fpath
    sel_table.gen[pos] = if T <: AbstractString
        e::Int64 -> begin
                lines = filter!(x -> AlgebraStreamFrames.is_emptystr(x), 
                    readlines(new_fpath))
            lines[e + 1]
        end
    else
        e::Int64 -> begin
            lines = filter!(x -> AlgebraStreamFrames.is_emptystr(x), 
                    readlines(new_fpath))
            parse(T, lines[e + 1])
        end
    end
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
    ind = nothing
    table = string(args[1])
    tablelen = length(DB_EXTENSION.tables[table])
    try
        ind = if contains(args[2], ":")
            splts = split(args[2], ":")
            val = parse(Int64, splts[1]):parse(Int64, splts[2])
            if minimum(val) < 1
                return(2, "range must start above 0")
            elseif maximum(val) > tablelen
                return(2, "requested index $(val) greater than table length $tablelen")
            end
            val
        else
            val = parse(Int64, args[2])
            if val > tablelen || val < 0
                return(2, "index error: row $(val) with table length $tablelen")
            end
            val
        end
    catch
        return(2, "failed to parse index or range for deletion.")
    end
    deleteat!(DB_EXTENSION.tables[table], ind)
    return(0, "")
end

# delete
function perform_command!(user::DBUser, cmd::Type{DBCommand{:z}}, args::AbstractString ...)
    if contains(args[1], "/")
        table, col = split(args[1], "/")
        sel_tab = DB_EXTENSION.tables[table]
        axis = findfirst(x -> x == col, sel_tab.names)
        AlgebraStreamFrames.drop!(sel_tab, axis, delete = true)
        return(0, "deleted column")
    else
        if ~(args[1] in keys(DB_EXTENSION.tables))
            return(2, "$(args[1]) is not a table or column path. No valid table selected.")
        end
        delete!(DB_EXTENSION.tables, args[1])
        rm(DB_EXTENSION.dir * "/$(args[1])", force = true, recursive = true)
        return(0, "deleted table")
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
    compare_val = args[3]
    if typeof(sel_value) == CryptString
        compare_val = sha256(compare_val)
        sel_value = decrypt(DB_EXTENSION.dec, base64decode(string(sel_value)))
    else
        compare_val = Vector{UInt8}(compare_val)
    end
    if Vector{UInt8}(string(sel_value)) == compare_val
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
    return(0, join((user.username for user in DB_EXTENSION.cursors), "!;"))
end

# create user
function perform_command!(user::DBUser, cmd::Type{DBCommand{:C}}, args::AbstractString ...)
    n = length(args)
    if n == 0
        return(1, "the create user command takes a username and optionally a password.")
    end
    newname = args[1]
    userlist = [user.username for user in DB_EXTENSION.cursors]
    if newname in userlist
        return(2, "$newname already exists!")
    end
    db_dir = DB_EXTENSION.dir * "/db/"
    userd = db_dir * "users.txt"
    secretd = db_dir * "secrets.txt"
    db_dir = nothing
    newpd = if n == 1
        Toolips.gen_ref(32)
    else
        args[2]
    end
    @warn "WROTE $(newname)"
    new_dbkey = Toolips.gen_ref(32)
    open(userd, "a") do o::IOStream
        write(o, "\n" * newname)
    end
    newpd = sha256(newpd)
    crypt_pwd = encrypt(DB_EXTENSION.enc, newpd)
    open(secretd, "a") do o::IOStream
        write(o, base64encode(crypt_pwd) * "DIV" * new_dbkey * "!EOF")
    end
    new_curs = DBUser(newname, String(newpd), new_dbkey, "", "")
    push!(DB_EXTENSION.cursors, new_curs)
    return(0, "$(newname)!;$(newpd)!;$(new_dbkey)")
end
# delete user
function perform_command!(user::DBUser, cmd::Type{DBCommand{:D}}, args::AbstractString ...)
    if ~(length(args) == 1)
        return(2, "delete user only takes one argument, the user's name to delete.")
    end
    selected_name = args[1]
    if selected_name == "admin"
        return(2, "cannot delete 'admin'")
    end
    db_dir = DB_EXTENSION.dir * "/db/"
    userd = db_dir * "users.txt"
    secretd = db_dir * "secrets.txt"
    db_dir = nothing
    curspos = findfirst(x -> x.username == selected_name, DB_EXTENSION.cursors)
    curs = DB_EXTENSION.cursors[curspos]
    user_names = readlines(userd)
    user_secrets = split(read(secretd, String), "!EOF")
    found = findfirst(x -> x == selected_name, user_names)
    secret_found = findfirst(x -> contains(x, curs.key), user_secrets)
    if isnothing(found)
        return(2, "user $selected_name not found")
    end
    deleteat!(user_names, found)
    deleteat!(user_secrets, secret_found)
    open(userd, "w") do o::IOStream
        write(o, join(user_names, "\n"))
    end
    open(secretd, "w") do o::IOStream
        write(o, join(user_secrets, "!EOF"))
    end
    deleteat!(DB_EXTENSION.cursors, curspos)
    return(0, string(args[1]))
end

# set
function perform_command!(user::DBUser, cmd::Type{DBCommand{:K}}, args::AbstractString ...)
    if ~(user.username == "admin")
        return(1, "cannot perform 'userset' unless you are 'admin'.")
    end
    n = length(args)
    if ~(n in (2, 3))
        return(2, "'set' takes at most 3 arguments, at minimum 2 (user, name, pwd)")
    end
    index = findfirst(usr -> usr.username == args[1], DB_EXTENSION.cursors)
    if isnothing(index)
        return(2, "user $(args[1]) not found")
    end
    allnames = [user.username for user in DB_EXTENSION.cursors]
    if args[1] != args[2] && args[2] in allnames
        return(2, "cannot set name, name already taken.")
    end
    this_user = DB_EXTENSION.cursors[index]
    this_user.username = string(args[2])
    new_pwd = base64encode(encrypt(DB_EXTENSION.enc, sha256(args[3])))
    this_user.pwd = new_pwd
    this_user.key = Toolips.gen_ref(32)
    userdirec = DB_EXTENSION.dir * "/db/users.txt"
    usrs = filter!(x -> AlgebraStreamFrames.is_emptystr(x), 
        readlines(userdirec))
    usrs[index] = this_user.username
    open(userdirec, "w") do o::IOStream
        write(o, join(usrs, "\n"))
    end
    usrs = nothing
    userdirec = nothing
    secrets_direc = DB_EXTENSION.dir * "/db/secrets.txt"
    pwdsplts = split(read(secrets_direc, String), "!EOF")
    pwdsplts[index] = "$(new_pwd)DIV$(this_user.key)"
    open(secrets_direc, "w") do o::IOStream
        write(o, join(pwdsplts, "!EOF"))
    end
    @warn this_user
    return(0, "$(this_user.username)!;$(args[2])!;$(this_user.key)")
end
# logout
function perform_command!(user::DBUser, cmd::Type{DBCommand{:L}}, args::AbstractString ...)
    user.table = ""
    return(4, "")
end

