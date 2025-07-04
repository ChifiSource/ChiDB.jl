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
@testset "chifi database server" verbose = true begin
    testdb_dir = SRCDIR * "/testdb"
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

        end
        @testset "create (t)" begin

        end
        @testset "get (g)" begin

        end
    end
    @testset "query commands" verbose = true begin

    end
    @testset "broken queries" verbose = true begin

    end
end
