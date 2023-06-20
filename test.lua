local sqlite3 = require "sqlite3"
local lpeg = require "lpeg"
require "lfs" -- patch lfs to not set a global variable
local zlib = require "zlib"
local lu = require "luaunit"
local re = require "re"
local aux = require "aux"
local csv = require "csv"
local json = require "cjson"
local argparse = require "argparse"
local log = require "log"
local string_builder = require "string_builder"
local zip = require "zip"

TestLibraries = {}

function TestLibraries:test_zlib()
    local test_string = "abcdefghijklmnopqrstuvabcdefghijklmnopqrstuv"
    local deflated = zlib.deflate()(test_string, "finish")
    local inflated = zlib.inflate()(deflated, "finish")
    lu.assertEquals(inflated, test_string)
end

function TestLibraries:test_lpeg()
    local number = lpeg.R "09" ^ 1 / tonumber
    local list = number * ("," * number) ^ 0
    local function add(acc, newvalue)
        return acc + newvalue
    end
    local sum = lpeg.Cf(list, add)
    lu.assertEquals(sum:match("10,30,43"), 83)
end

function TestLibraries:test_re()
    lu.assertEquals(re.gsub("hello World", "[aeiou]", "."), "h.ll. W.rld")
end

function TestLibraries:test_lfs()
    local actual = {}
    for file in lfs.dir("./lua/") do
        actual[#actual + 1] = file
    end
    table.sort(actual)
    lu.assertEquals(actual, { ".", "..", "Makefile", "README", "doc", "src" })
end

function TestLibraries:test_sqlite()
    local db = sqlite3.open("test.sqlite3")
    db:exec [=[
              CREATE TABLE numbers(num,val);
              INSERT INTO numbers VALUES(1,'one');
              INSERT INTO numbers VALUES(2,'two');
              INSERT INTO numbers VALUES(3,'three');
            ]=]

    local actual = {}
    for result in db:nrows("SELECT num, val FROM numbers order by 1") do
        actual[#actual + 1] = result.num .. ":" .. result.val
    end
    db:close()
    os.remove("test.sqlite3")

    local expected = { "1:one", "2:two", "3:three" }

    lu.assertEquals(actual, expected)
end

TestAuxLib = {}

function TestAuxLib:test_string()
    local TEST = "   TEST   "
    lu.assertEquals(aux.ltrim(TEST), "TEST   ")
    lu.assertEquals(aux.rtrim(TEST), "   TEST")
    lu.assertEquals(aux.trim(TEST), "TEST")
    lu.assertEquals({ aux.split("1,2,3") }, { "1", "2", "3" })
end

function TestAuxLib:test_string_extended()
    local TEST = "   \tTEST   \n"
    local list = "1,2,3"
    lu.assertEquals(TEST:ltrim(), "TEST   \n")
    lu.assertEquals(TEST:rtrim(), "   \tTEST")
    lu.assertEquals(TEST:trim(), "TEST")
    lu.assertEquals({ list:split() }, { "1", "2", "3" })
end

function TestAuxLib:test_kpairs()
    local tbl = {
        y = "two",
        z = "three",
        x = "one"
    }

    local actual = ""
    for k, v in aux.kpairs(tbl) do
        actual = actual .. k .. ":" .. v .. "\n"
    end
    lu.assertEquals("x:one\ny:two\nz:three\n", actual)
end

function TestAuxLib:test_copytyble()
    local tbl = {
        y = "two",
        z = "three",
        x = "one"
    }
    lu.assertEquals(tbl, aux.copytable(tbl))
    lu.assertEquals(tbl, table.copy(tbl))
end

function TestAuxLib:test_concats()
    local tbl = { 1, "2", 3 }
    lu.assertEquals(aux.concats(tbl), "123")
    lu.assertEquals(aux.concats(tbl, ","), "1,2,3")
end

function TestAuxLib:test_table_to_String()
    local tbl = {
        1,
        "2",
        3,
        key = "value"
    }
    lu.assertEquals(aux.tabletostring(tbl, "tbl"), 'tbl = {\n  1,\n  2,\n  3,\n  key = "value",\n}')
    lu.assertEquals(table.tostring(tbl, "tbl"), 'tbl = {\n  1,\n  2,\n  3,\n  key = "value",\n}')
end

function TestLibraries:test_csv_create_and_read()
    aux.writefile("test.csv", [[
A,B,C
A1,B1,C1
A2,B2,C2
A3,B3,C3
]])

    local actual = {}
    for r, row in ipairs(csv.read("test.csv", true)) do
        actual[#actual + 1] = r .. ":" .. row[1] .. "-" .. row[2] .. "-" .. row[3]
    end

    lu.assertEquals(actual, { "1:A1-B1-C1", "2:A2-B2-C2", "3:A3-B3-C3" })
    os.remove("test.csv")
end

function TestLibraries:test_cjson_decode_encode()
    local decoded = json.decode('{"test":true,"name":"test_cjson_decode_encode", "days":[1,2,3]}')
    lu.assertEquals(decoded.test, true)
    lu.assertEquals(decoded.name, "test_cjson_decode_encode")
    lu.assertEquals(decoded.days, { 1, 2, 3 })

    local encoded = json.encode(decoded)
    lu.assertEquals(json.decode(encoded), {
        test = true,
        name = "test_cjson_decode_encode",
        days = { 1, 2, 3 }
    })
end

function TestLibraries:test_argparse()
    local parser = argparse("script", "An example.")
    parser:argument("input", "Input file.")
    parser:option("-o --output", "Output file.", "a.out")
    parser:option("-I --include", "Include locations."):count("*")

    local args = parser:parse({ 'inputFile', '-I', 'incl', '-o', 'outputFile' })
    lu.assertEquals(args.input, "inputFile")
    lu.assertEquals(args.output, "outputFile")
    lu.assertEquals(args.include, { 'incl' })
end

function logCollector()
    local collector = {
        logs = {}
    }
    function collector:append(logger, level, message)
        self.logs[#self.logs + 1] = { logger._name, level, message }
    end

    return collector
end

function TestLibraries:test_log()
    local appender = logCollector();
    log:setAppender(appender)
    log:info("First line")

    local testlog = log["TEST"]
    testlog:setLevel(log.level.ERROR)
    testlog:info("Not shown")
    testlog:error("Some error")

    log:info("Last line")

    log:setLevel(log.level.ERROR)
    log:info("Not shown")
    log:error("Some error")

    lu.assertEquals(appender.logs, {
        { 'ROOT', 5, "First line" },
        { 'TEST', 3, "Some error" },
        { 'ROOT', 5, "Last line" },
        { 'ROOT', 3, "Some error" },
    })
end

function TestLibraries:test_string_builder()
    local sb = string_builder.new()
    lu.assertEquals(sb:len(), 0)
    lu.assertEquals(sb:tostring(), "")

    sb:add("Hello"):add(" "):add("World"):add("!")
    lu.assertEquals(sb:len(), 12)
    lu.assertEquals(sb:tostring(), "Hello World!")

    sb:reset()
    lu.assertEquals(sb:len(), 0)
    lu.assertEquals(sb:tostring(), "")

    sb:add("Hello"," ","World","!")
    lu.assertEquals(sb:tostring(), "Hello World!")
    
    sb:reset():add(1,',',true,',',23.56,',',false)
    lu.assertEquals(sb:tostring(), "1,true,23.56,false")
    
    sb:reset():add("A", string_builder.new():add("B","C"),"D")
    lu.assertEquals(sb:tostring(), "ABCD")
end

function TestLibraries:test_zip()
    local testfile = "test.zip"
    local inputfile = "README.md"
    os.remove(testfile)

    local testzip = zip.create(testfile)
    testzip:addfile(inputfile,inputfile)
    testzip:close()

    local file = zip.open(testfile)
    lu.assertEquals(file.files[inputfile].name, inputfile)
    lu.assertEquals(file.files[inputfile].uncompressed_size, lfs.attributes(inputfile).size)
    file:close()
    
    print(os.remove(testfile))
end
