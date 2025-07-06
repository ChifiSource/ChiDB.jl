using ChiDB
using ChiDB.Toolips
using Test
SRCDIR = @__DIR__
const ext = ChiDB.DB_EXTENSION
#==
testdb info
dbkey:
hjqyoktipaporlrzepcdaouwtysqtjch
pwd:
wztycvtmqqkqjrba
username:
admin
==#
testdb_dir = SRCDIR * "/testdb"
curr_dir = readdir(testdb_dir)
if length(curr_dir) > 4
    @info "found bad files in db, cleaning"
    necessary = ("db", "tab1", "tab3", "vals")
    for dir in curr_dir
        if dir in necessary
            continue
        end
        rm(testdb_dir * "/" * dir, force = true, recursive = true)
    end
end

curr_dir = nothing

@testset "chifi database server" verbose = true begin 
    @testset "load db and schema" begin
        ext.dir = testdb_dir
        successful_load = try 
            ChiDB.load_db!(ext)
            true
        catch e
            throw(e)
            false
        end
        @test successful_load
        found = findfirst(user -> user.username == "admin", ext.cursors)
        @test ~(isnothing(found))
        successful_schema_load = try
            ChiDB.load_schema!(ext)
            true
        catch
            false
        end
        @test successful_schema_load
        @test length(ext.tables) == 3
        table_names = keys(ext.tables)
        for x in ["tab1", "vals", "tab3"]
            # one table shall remain empty, to ensure that works
            @test x in table_names
        end
        @test "col1" in ext.tables["tab1"].names
        @test typeof(ext.tables["tab1"]["col1"][1]) == Int64
    end
    @testset "internal functions" begin
        dbuser = ext.cursors[1]
        tab = "tab1/col1"
        sel, col = ChiDB.get_selected_col(dbuser, tab)
        @test sel == "tab1"
        @test col == "col1"
        # error
        sel, col = ChiDB.get_selected_col(dbuser, "col1")
        @test typeof(sel) == Int64
        dbuser.table = "tab1"
        sel, col = ChiDB.get_selected_col(dbuser, "col1")
        @test sel == "tab1"
        @test col == "col1"
        dbuser.table = ""
    end
    sock = nothing
    @testset "server start" begin
        @info "starting dbserver"
        procs = ChiDB.start(testdb_dir, async = true)
        @test typeof(procs) == ChiDB.Toolips.ProcessManager
        server_ns = names(ChiDB, all = true)
        @test :server in server_ns
        # reset tables check
        @test length(ext.tables) == 3
        @test length(ext.cursors) == 1
        connected = try
            sock = ChiDB.Toolips.connect("127.0.0.1":8005)
            true
        catch
            false
        end
        @test connected
    end
    curr_header = 'c'
    @testset "login" begin
        @info "performing login"
        # success   
        write!(sock, "aShjqyoktipaporlrzepcdaouwtysqtjch admin wztycvtmqqkqjrba\n")
        @warn "completed write"
        resp = String(readavailable(sock))
        @warn "completed read"
        header = bitstring(UInt8(resp[1]))
        opcode = header[1:4]
        @test opcode == "0001"
        @test ChiDB.DB_EXTENSION.cursors[1].transaction_id != ""
        curr_header = Char(UInt8(resp[1]))
        #==
        # dbkey error
        sock2 = ChiDB.Toolips.connect("127.0.0.1":8005)
        write!(sock2, "aShjqyoktipaporlrzepcdaouwtyseragargch admin wztycvtmqqkqjrba\n")
        resp = String(readavailable(sock2))
        header = bitstring(UInt8(resp[1]))
        opcode = header[1:4]
        @test opcode == "1010"
        # login error
        sock2 = ChiDB.Toolips.connect("127.0.0.1":8005)
        write!(sock2, "aShjqyoktipaporlrzepcdaouwtysqtjch admin wztychgterehjrba\n")
        resp = String(readavailable(sock))
        header = bitstring(UInt8(resp[1]))
        opcode = header[1:4]
        @test opcode == "1100"
        ==#
    end
    @testset "queries" verbose = true begin
        @info "performing queries"
        @testset "command error" begin

        end
        @testset "list (l)" begin
            write!(sock, "$(curr_header)l\n")
            resp = String(readavailable(sock))
            @test contains(resp, "tab1")
            header = bitstring(UInt8(resp[1]))
            opcode = header[1:4]
            @test opcode == "0001"
            write!(sock, "$(Char(UInt8(resp[1])))ltab1\n")
            resp = String(readavailable(sock))
            @test contains(resp, "col1")
            curr_header = Char(UInt8(resp[1]))
            # argument error
            write!(sock, "$(curr_header)lbabtaejthgejth\n")
            resp = String(readavailable(sock))
            header = bitstring(UInt8(resp[1]))
            opcode = header[1:4]
            @test opcode == "1010"
            curr_header = Char(UInt8(resp[1]))
        end
        @testset "select (s)" begin
            @warn "$(curr_header)stab1\n"
            write!(sock, "$(curr_header)stab1\n")
            resp = String(readavailable(sock))
            header = bitstring(UInt8(resp[1]))
            opcode = header[1:4]
            curr_header = Char(UInt8(resp[1]))
            @test opcode == "0001"
            if opcode != "0001"
                @warn resp
            end
            @test ChiDB.DB_EXTENSION.cursors[1].table == "tab1"
            write!(sock, "$(curr_header)sthrhtrhth\n")
            resp = String(readavailable(sock))
            header = bitstring(UInt8(resp[1]))
            opcode = header[1:4]
            curr_header = Char(UInt8(resp[1]))
            @test opcode == "1010"
        end
        @testset "create (t)" begin
            write!(sock, "$(curr_header)tnewt\n")
            resp = String(readavailable(sock))
            header = bitstring(UInt8(resp[1]))
            opcode = header[1:4]
            curr_header = Char(UInt8(resp[1]))
            @test opcode == "0001"
            @test "newt" in keys(ChiDB.DB_EXTENSION.tables)
            @test isdir(testdb_dir * "/newt")
        end
        @testset "join (j)" begin
            write!(sock, "$(curr_header)jnewt|!|main|!|Integer\n")
            resp = String(readavailable(sock))
            header = bitstring(UInt8(resp[1]))
            opcode = header[1:4]
            curr_header = Char(UInt8(resp[1]))
            @test opcode == "0001"
            sel_tab = ChiDB.DB_EXTENSION.tables["newt"]
            @test "main" in names(sel_tab)
            @test sel_tab.T[1] <: Integer
            
            write!(sock, "$(curr_header)jnewt|!|name|!|String\n")
            resp = String(readavailable(sock))
            header = bitstring(UInt8(resp[1]))
            opcode = header[1:4]
            curr_header = Char(UInt8(resp[1]))
            @test opcode == "0001"
            @test "name" in names(sel_tab)
            # ref col join
            write!(sock, "$(curr_header)jnewt|!|tab1/col1\n")
            resp = String(readavailable(sock))
            header = bitstring(UInt8(resp[1]))
            opcode = header[1:4]
            curr_header = Char(UInt8(resp[1]))
            @test opcode == "0001"
            @test "col1" in names(sel_tab)
            @test length(names(sel_tab)) == 3
            @test length(keys(sel_tab.paths)) == 2
            @test isfile(testdb_dir * "/newt/tab1_col1.ref")
        end
        @testset "store (a)" begin 
            write!(sock, "$(curr_header)anewt|!|6!;sample!;1\n")
            resp = String(readavailable(sock))
            header = bitstring(UInt8(resp[1]))
            opcode = header[1:4]
            curr_header = Char(UInt8(resp[1]))
            @test opcode == "0001"
            @test length(ChiDB.DB_EXTENSION.tables["newt"]) > 0
            @test "sample" in ChiDB.DB_EXTENSION.tables["newt"]["name"]
            
            write!(sock, "$(curr_header)anewt|!|12!;sample2!;7\n")
            resp = String(readavailable(sock))
            header = bitstring(UInt8(resp[1]))
            opcode = header[1:4]
            curr_header = Char(UInt8(resp[1]))
            @test opcode == "0001"
            @test length(ChiDB.DB_EXTENSION.tables["newt"]) > 0
            @test "sample" in ChiDB.DB_EXTENSION.tables["newt"]["name"]
        end
        @testset "get (g)" begin
            write!(sock, "$(curr_header)gnewt/name\n")
            resp = String(readavailable(sock))
            @info "GET RESP: " * resp
            header = bitstring(UInt8(resp[1]))
            opcode = header[1:4]
            curr_header = Char(UInt8(resp[1]))
            @test opcode == "0001"
            vals = replace(resp[3:end], "\n" => "")
            @info vals
            @test contains(vals, "!;")
            splts = filter!(x -> x != "", split(vals, "!;"))
            @test length(splts) == 2
            @test "sample" in splts
            @test "sample2" in splts

            write!(sock, "$(curr_header)gnewt/main|!|1:2\n")
            resp = String(readavailable(sock))
            header = bitstring(UInt8(resp[1]))
            opcode = header[1:4]
            curr_header = Char(UInt8(resp[1]))
            @test opcode == "0001"
            @test contains(vals, "!;")
            vals = resp[3:end]
            splts = filter!(x -> x == "", split(vals, "!;"))
            for x in splts
                successful_parse = try
                    parse(Int64, replace(x, " " => "", "\n" => ""))
                    true
                catch
                    false
                end
                @test successful_parse
            end
        end
        @testset "index (i)" begin
            write!(sock, "$(curr_header)inewt/name|!|sample\n")
            resp = String(readavailable(sock))
            header = bitstring(UInt8(resp[1]))
            opcode = header[1:4]
            curr_header = Char(UInt8(resp[1]))
            @test opcode == "0001"
            val = replace(resp[3:end], "\n" => "")
            i = nothing
            successful_index_parse = try
                i = parse(Int64, val)
                true
            catch
                @warn val
                false
            end
            @test successful_index_parse
            @test i == 1
        end
        @testset "getrow (r)" begin
            write!(sock, "$(curr_header)rnewt|!|1\n")
            resp = String(readavailable(sock))
            header = bitstring(UInt8(resp[1]))
            opcode = header[1:4]
            curr_header = Char(UInt8(resp[1]))
            @test opcode == "0001"
            vals = split(replace(resp[3:end], "\n" => ""), "!;")
            @test length(vals) == 3
            @test vals[2] == "sample"
            successful_parse = try
                parse(Int64, vals[3])
                true
            catch
                false
            end
            @test successful_parse

            # get multirow
            write!(sock, "$(curr_header)rnewt|!|1:2\n")
            resp = String(readavailable(sock))
            header = bitstring(UInt8(resp[1]))
            opcode = header[1:4]
            curr_header = Char(UInt8(resp[1]))
            @test opcode == "0001"
            rows = split(replace(resp[3:end], "\n" => ""), "!N")
            @warn rows
            @test length(rows) == 2
            @test length(split(rows[1], "!;")) == 3
            @test split(rows[2], "!;")[2] == "sample2"
        end
        @testset "set (v)" begin
            write!(sock, "$(curr_header)vnewt/name|!|1|!|frank\n")
            resp = String(readavailable(sock))
            header = bitstring(UInt8(resp[1]))
            opcode = header[1:4]
            curr_header = Char(UInt8(resp[1]))
            @test opcode == "0001"
            @test contains(resp, "value updated")
            @test ChiDB.DB_EXTENSION.tables["newt"]["name"][1] == "frank"
        end
        @testset "setrow (w)" begin

        end
        @testset "type (k)" begin

        end
        @testset "rename (e)" begin

        end
        @testset "deleteat (d)" begin

        end
        @testset "delete (z)" begin

        end
        @testset "compare (p)" begin

        end
        @testset "in (n)" begin
            write!(sock, "$(curr_header)nnewt/name|!|sample2\n")
            resp = String(readavailable(sock))
            header = bitstring(UInt8(resp[1]))
            opcode = header[1:4]
            curr_header = Char(UInt8(resp[1]))
            @test opcode == "0001"
            @test contains(resp[3:end], "1")

            write!(sock, "$(curr_header)nnewt/name|!|great\n")
            resp = String(readavailable(sock))
            header = bitstring(UInt8(resp[1]))
            opcode = header[1:4]
            curr_header = Char(UInt8(resp[1]))
            @test opcode == "0001"
            @test contains(resp[3:end], "0")
        end
    end
    @testset "broken queries" verbose = true begin

    end
end
