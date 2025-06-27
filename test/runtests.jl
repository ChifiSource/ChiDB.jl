using ChiDB
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
@testset "chifi database server" verbose = true begin
    testdb_dir = SRCDIR * "/testdb"
    @testset "load db and schema" begin
        ext.dir = testdb_dir
        successful_load = try 
            ChiDB.load_db!(ext)
            true
        catch
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
        sel, col = ChiDB.get_selected_col(dbuser, tag)
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
    @testset "server start" begin
        procs = ChiDB.start(testdb_dir, async = true)
        @test typeof(procs) == ChiDB.Toolips.ProcessManager
        server_ns = names(ChiDB, all = true)
        @test :server in server_ns
        # reset tables check
        @test length(ext.tables) == 3
        @test length(ext.cursors) == 1
        sock = nothing
        connected = try
            sock = ChiDB.Toolips.connect("127.0.0.1":8005)
            true
        catch
            false
        end
        @test connected
        if connected
            close(sock)
        end
    end
    sock = ChiDB.Toolips.connect("127.0.0.1":8005)
    @testset "login" begin

    end
    @testset "queries" begin

    end
    @testset "query commands" verbose = true begin

    end
    @testset "broken queries" verbose = true begin

    end
end
