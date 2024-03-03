local lu = require 'luaunit'
lu.ORDER_ACTUAL_EXPECTED = false

local sqlite3 = require "sqlite3"
local lpeg = require "lpeg"
local zlib = require "zlib"
local re = require "re"
local csv = require "csv"
local json = require "cjson"
local argparse = require "argparse"

Test_libraries = {}

function Test_libraries:Test_zlib()
    local test_string = "abcdefghijklmnopqrstuvabcdefghijklmnopqrstuv"
    local deflated = zlib.deflate()(test_string, "finish")
    local inflated = zlib.inflate()(deflated, "finish")
    lu.assertEquals(test_string, inflated)
end

function Test_libraries:Test_lpeg()
    local number = lpeg.R "09" ^ 1 / tonumber
    local list = number * ("," * number) ^ 0
    local function add(acc, newvalue)
        return acc + newvalue
    end
    local sum = lpeg.Cf(list, add)
    lu.assertEquals(83, sum:match("10,30,43"))
end

function Test_libraries:Test_re()
    lu.assertEquals("h.ll. W.rld", re.gsub("hello World", "[aeiou]", "."))
end

function Test_libraries:Test_sqlite()
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

    lu.assertEquals(expected, actual)
end

function Test_libraries:Test_csv_create_and_read()
    local data = [[
A,B,C
A1,B1,C1
A2,B2,C2
A3,B3,C3
]]

    local actual = {}
    for r, row in ipairs(csv.parse(data, ",", { loadFromString = true })) do
        actual[#actual + 1] = r .. ":" .. row.A .. "-" .. row.B .. "-" .. row.C
    end

    lu.assertEquals({ "1:A1-B1-C1", "2:A2-B2-C2", "3:A3-B3-C3" }, actual)
end

function Test_libraries:Test_cjson_decode_encode()
    local decoded = json.decode('{"test":true,"name":"test_cjson_decode_encode", "days":[1,2,3]}')
    lu.assertIsTrue(decoded.test)
    lu.assertEquals("test_cjson_decode_encode", decoded.name)
    lu.assertEquals({ 1, 2, 3 }, decoded.days)

    local encoded = json.encode(decoded)
    lu.assertEquals({
        test = true,
        name = "test_cjson_decode_encode",
        days = { 1, 2, 3 }
    }, json.decode(encoded))
end

function Test_libraries:Test_argparse()
    local parser = argparse("script", "An example.")
    parser:argument("input", "Input file.")
    parser:option("-o --output", "Output file.", "a.out")
    parser:option("-I --include", "Include locations."):count("*")

    local args = parser:parse({ 'inputFile', '-I', 'incl', '-o', 'outputFile' })
    lu.assertEquals("inputFile", args.input)
    lu.assertEquals("outputFile", args.output)
    lu.assertEquals({ 'incl' }, args.include)
end

if not RUN_ALL then
    os.exit(lu.LuaUnit.run('-v'))
end
