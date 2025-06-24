#==
COMMAND TABLE:
# server
S - login
U - list users
C - create user
K - set password

# query
#  table management
l - list tables
s - select
t - create table
m - view table

# get-store
g - get
r - get row
i - get index
a - store

# column management
j - join
b - reference join
k - set type
e - rename

# deleters
d - delete at
z - delete

# built-in operations
p - compare
n - in
==#
#==
Table Commands
==#
# list tables
function perform_command!(user::DBUser, cmd::Type{DBCommand{:l}}, args::AbstractString ...)
    if length(args) > 0
        name = args[1]
        if ~(name in keys(DB_EXTENSION.tables))
            return(2, "$name is not a table, to list all tables provide no arguments.")
        end
        selected_table = DB_EXTENSION.tables[name]
        colstr = join((begin
            "$(selected_table.names[e]) $(selected_table.T[e])!N"
        end for e in 1:length(selected_table.names)))
        return(0, "$name ($(length(selected_table.names)) columns $(length(selected_table)) rows !N" * colstr)
    end
    list = keys(DB_EXTENSION.tables)
    return(0, 
        join(
    "$k ($(length(DB_EXTENSION.tables[k].names)) columns)\n" for k in keys(DB_EXTENSION.tables)))
end
# select table
function perform_command!(user::DBUser, cmd::Type{DBCommand{:s}}, args::AbstractString ...)
    if length(args) < 1
        return(2, "provide a table name to select.")
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
        return(2, "create table requires name")
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
        return(2, "create column requires a column directory")
    end
    table_selected = ""
    col_selected = ""
    if ~(contains(args[1], "/"))
        if user.table == ""
            return(2, "proper table path not selected")
        end
        table_selected = user.table
        col_selected = args[1]
    else
        splts = split(args[1], "/")
        table_selected = splts[1]
        col_selected = splts[2]
    end
    if n > 1
        range_sel = args[2]
        selected_ind = 1
        if range_sel == "where"
            wherelookup = Dict("==" => ==, "<" => <, "<=" => <=, 
                ">=" => >=, ">" => >)
            if n < 5
                if ~(args[4] in keys(wherelookup))

                end
                filter
                wherelookup[args[4]](args[3], args[5])
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
                parse(Int64, vals[1]):parse(Int64, vals[2])
            catch
                return(2, "could not parse index")
            end
        end
        
        return(0, join((string(gen) for gen in generated[selected_ind]), ";"))
    end
    generated = DB_EXTENSION.tables[string(table_selected)][string(col_selected)]
    return(0, join((string(gen) for gen in generated), ";"))
end
# get row
function perform_command!(user::DBUser, cmd::Type{DBCommand{:r}}, args::AbstractString ...)
    colrow = args[1]

end
# get index
function perform_command!(user::DBUser, cmd::Type{DBCommand{:i}}, args::AbstractString ...)
    colrow = args[1]

end
