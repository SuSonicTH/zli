local sqlite3 = require "sqlite3"
local lpeg = require "lpeg"
require "lfs" -- patch lfs to not set a global variable
local zlib = require "zlib"
local lu = require "luaunit"
local re = require "re"
local csv = require "csv"
local json = require "cjson"
local argparse = require "argparse"
local log = require "log"
local zip = require "zip"
local stream = require "stream"

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
    for file in lfs.dir("./src/lib/lua") do
        actual[#actual + 1] = file
    end
    table.sort(actual)
    lu.assertEquals(actual, { ".", "..", "lauxlib.h", "lua.h", "luaconf.h", "lualib.h" })
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
    lu.assertEquals(string.ltrim("   "), "")
    lu.assertEquals(string.ltrim(TEST), "TEST   ")
    lu.assertEquals(string.rtrim(TEST), "   TEST")
    lu.assertEquals(string.trim(TEST), "TEST")
    lu.assertEquals({ string.split("1,2,3") }, { "1", "2", "3" })
    lu.assertEquals(string.to_table("1,2,3"), { "1", "2", "3" })
end

function TestAuxLib:test_string_extended()
    local TEST = "   \tTEST   \n"
    local list = "1,2,3"
    lu.assertEquals(TEST:ltrim(), "TEST   \n")
    lu.assertEquals(TEST:rtrim(), "   \tTEST")
    lu.assertEquals(TEST:trim(), "TEST")
    lu.assertEquals({ list:split() }, { "1", "2", "3" })
end

function TestAuxLib:test_spairs()
    local tbl = {
        y = "two",
        z = "three",
        x = "one"
    }

    local actual = ""
    for k, v in table.spairs(tbl) do
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
    lu.assertEquals(tbl, table.copy(tbl))
end

function TestAuxLib:test_concats()
    local tbl = { 1, "2", 3 }
    lu.assertEquals(table.concats(tbl), "123")
    lu.assertEquals(table.concats(tbl, ","), "1,2,3")
end

function TestAuxLib:test_table_to_String()
    local tbl = {
        1,
        "2",
        3,
        key = "value"
    }
    lu.assertEquals(table.tostring(tbl, "tbl"), 'tbl = {\n    1,\n    "2",\n    3,\n    key = "value"\n}')
end

function TestAuxLib:test_insert_sorted()
    local tbl = {}
    for _, value in ipairs({ 9, 1, 5, 3, 6, 2, 7, 8, 4 }) do
        table.insert_sorted(tbl, value)
    end
    lu.assertEquals(tbl, { 1, 2, 3, 4, 5, 6, 7, 8, 9 })
end

function TestLibraries:test_csv_create_and_read()
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

    lu.assertEquals(actual, { "1:A1-B1-C1", "2:A2-B2-C2", "3:A3-B3-C3" })
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
    local sb = string.builder()
    lu.assertEquals(sb:len(), 0)
    lu.assertEquals(sb:isempty(), true)
    lu.assertEquals(sb:tostring(), "")

    sb:add("Hello"):add(" "):add("World"):add("!")
    lu.assertEquals(sb:len(), 12)
    lu.assertEquals(sb:tostring(), "Hello World!")

    sb:clear()
    lu.assertEquals(sb:len(), 0)
    lu.assertEquals(sb:tostring(), "")

    sb:add("Hello", " ", "World", "!")
    lu.assertEquals(sb:tostring(), "Hello World!")

    sb:clear():add(1, ',', true, ',', 23.56, ',', false)
    lu.assertEquals(sb:tostring(), "1,true,23.56,false")

    sb:clear():add("A", string.builder():add("B", "C"), "D")
    lu.assertEquals(sb:tostring(), "ABCD")
end

function TestLibraries:test_string_joiner()
    local joiner = string.joiner { delimiter = ',' }
    lu.assertEquals(joiner:len(), 0)
    lu.assertEquals(joiner:isempty(), true)
    lu.assertEquals(joiner:tostring(), "")

    joiner:add("one"):add("two"):add("three")
    --lu.assertEquals(joiner:len(), 13)
    lu.assertEquals(joiner:tostring(), "one,two,three")

    joiner:clear()
    lu.assertEquals(joiner:len(), 0)
    lu.assertEquals(joiner:tostring(), "")

    joiner = string.joiner { delimiter = ',', prefix = '[', suffix = ']' }

    joiner:add("one"):add("two")
    lu.assertEquals(joiner:tostring(), "[one,two]")

    joiner:add("three")
    lu.assertEquals(joiner:tostring(), "[one,two,three]")

    joiner:clear():add(1, true, 23.56, false)
    lu.assertEquals(joiner:tostring(), "[1,true,23.56,false]")
end

function TestLibraries:test_zip()
    local testfile = "test.zip"
    local inputfile = "README.md"
    os.remove(testfile)

    local testzip = zip.create(testfile)
    testzip:addfile(inputfile, inputfile)
    testzip:close()

    local file = zip.open(testfile)
    lu.assertEquals(file.files[inputfile].name, inputfile)
    lu.assertEquals(file.files[inputfile].uncompressed_size, lfs.attributes(inputfile).size)
    file:close()

    os.remove(testfile)
end

TestStreamLib = {}

function TestStreamLib:test_concat()
    lu.assertEquals(stream({ 1, 2, 3, 4, 5 }):concat(","), "1,2,3,4,5")
end

function TestStreamLib:test_toarray()
    lu.assertEquals(stream({ 1, 2, 3, 4, 5 }):toarray(), { 1, 2, 3, 4, 5 })
end

function TestStreamLib:test_map()
    lu.assertEquals(stream({ 1, 2, 3, 4, 5 }):map(function(v) return v + 1 end):toarray(), { 2, 3, 4, 5, 6 })
end

function TestStreamLib:test_filter()
    lu.assertEquals(stream({ 1, 2, 3, 4, 5 }):filter(function(v) return v % 2 == 1 end):toarray(), { 1, 3, 5 })
    lu.assertEquals(stream({ 1, 2, 3, 4, 5 }):filter(function(v) return v % 2 == 0 end):toarray(), { 2, 4 })
end

function TestStreamLib:test_skip()
    lu.assertEquals(stream({ 1, 2, 3, 4, 5 }):skip(0):toarray(), { 1, 2, 3, 4, 5 })
    lu.assertEquals(stream({ 1, 2, 3, 4, 5 }):skip(1):toarray(), { 2, 3, 4, 5 })
    lu.assertEquals(stream({ 1, 2, 3, 4, 5 }):skip(4):toarray(), { 5 })
end

function TestStreamLib:test_limit()
    lu.assertEquals(stream({ 1, 2, 3, 4, 5 }):limit(10):toarray(), { 1, 2, 3, 4, 5 })
    lu.assertEquals(stream({ 1, 2, 3, 4, 5 }):limit(5):toarray(), { 1, 2, 3, 4, 5 })
    lu.assertEquals(stream({ 1, 2, 3, 4, 5 }):limit(1):toarray(), { 1 })
    lu.assertEquals(stream({ 1, 2, 3, 4, 5 }):limit(3):toarray(), { 1, 2, 3 })
end

function TestStreamLib:test_reverse()
    lu.assertEquals(stream({ 1, 2, 3, 4, 5 }):reverse():toarray(), { 5, 4, 3, 2, 1 })
end

function TestStreamLib:test_sort()
    lu.assertEquals(stream({ 4, 5, 1, 3, 2 }):sort():toarray(), { 1, 2, 3, 4, 5 })
end

function TestStreamLib:test_maptonumber()
    lu.assertEquals(stream({ 1, 2, 3, 4, 5 }):maptonumber():toarray(), { 1, 2, 3, 4, 5 })
    lu.assertEquals(stream({ '1', '2', '3', '4', '5' }):maptonumber():toarray(), { 1, 2, 3, 4, 5 })
end

function TestStreamLib:test_distinct()
    lu.assertEquals(stream({ 1, 1, 5, 2, 3, 2, 3, 4, 1, 5, 1, 4, 5 }):distinct():sort():toarray(), { 1, 2, 3, 4, 5 })
end

function TestStreamLib:test_split()
    local odd, even = stream({ 1, 2, 3, 4, 5, 6, 7, 8, 9 }):split(function(num) return num % 2 == 1 end)
    lu.assertEquals(stream(odd):concat(","), "1,3,5,7,9")
    lu.assertEquals(stream(even):concat(","), "2,4,6,8")

    odd, even = stream({ 1, 2, 3, 4, 5, 6, 7, 8, 9 }):split(function(num) return num % 2 == 1 end)
    lu.assertEquals(stream(even):concat(","), "2,4,6,8")
    lu.assertEquals(stream(odd):concat(","), "1,3,5,7,9")
end

function TestStreamLib:test_join()
    lu.assertEquals(
        stream().join(stream({ 1, 2, 3, 4, 5, 6, 7, 8, 9 }):split(function(num) return num % 2 == 1 end)):concat(","),
        "1,3,5,7,9,2,4,6,8"
    )

    lu.assertEquals(
        stream({ 1, 2, 3, 4 }):join(stream({ 5, 6, 7, 8, 9 }), stream({ 10 })):concat(","),
        "1,2,3,4,5,6,7,8,9,10"
    )
end

function TestStreamLib:test_tosortedarray()
    lu.assertEquals(stream({ 4, 5, 1, 3, 2 }):tosortedarray(), { 1, 2, 3, 4, 5 })
end

function TestStreamLib:test_allmatch()
    lu.assertEquals(stream({ 1, 3, 5, 7, 9 }):allmatch(function(val) return val % 2 == 1 end), true)
    lu.assertEquals(stream({ 1, 3, 5, 2, 7, 9 }):allmatch(function(val) return val % 2 == 1 end), false)
end

function TestStreamLib:test_firstmatch()
    lu.assertEquals(stream({ 1, 2, 3, 4, 5 }):firstmatch(function(val) return val > 3 end), 4)
end

function TestStreamLib:test_anymatch()
    lu.assertEquals(stream({ 1, 3, 5, 7, 8, 9 }):anymatch(function(val) return val % 2 == 0 end), true)
    lu.assertEquals(stream({ 1, 3, 5, 7, 9 }):anymatch(function(val) return val % 2 == 0 end), false)
end

function TestStreamLib:test_first()
    lu.assertEquals(stream({ 3, 5, 7, 8, 9 }):first(), 3)
end

function TestStreamLib:test_last()
    lu.assertEquals(stream({ 3, 5, 7, 8, 9 }):last(), 9)
end

function TestStreamLib:test_count()
    lu.assertEquals(stream({ 3, 5, 7, 8, 9 }):count(), 5)
    lu.assertEquals(stream({ 1, 2, 3, 4, 5, 6, 7, 8, 9 }):count(), 9)
end

function TestStreamLib:test_sum()
    lu.assertEquals(stream({ 3, 5, 7, 8, 9 }):sum(), 32)
    lu.assertEquals(stream({ 3 }):sum(), 3)
    lu.assertEquals(stream({}):sum(), 0)
end

function TestStreamLib:test_average()
    lu.assertEquals(stream({ 3, 5, 7, 8, 9 }):average(), 6.4)
    lu.assertEquals(stream({ 3 }):average(), 3)
    lu.assertEquals(stream({}):average(), 0)
end

function TestStreamLib:test_median()
    lu.assertEquals(stream({ 3, 5, 7, 8, 9 }):median(), 7)
    lu.assertEquals(stream({ 8, 9, 3, 5, 7, 10, 1 }):median(), 7)
    lu.assertEquals(stream({ 3 }):median(), 3)
    lu.assertEquals(stream({}):median(), 0)
end

function TestStreamLib:test_reduce()
    lu.assertEquals(stream({ 3, 5, 7, 8, 9 }):reduce(0, function(sum, value) return sum + value end), 32)
end

function TestStreamLib:test_min()
    lu.assertEquals(stream({ 3, 5, 7, 8, 9 }):min(), 3)
    lu.assertEquals(stream({ 5, 7, 8, 9, 3 }):min(), 3)
end

function TestStreamLib:test_max()
    lu.assertEquals(stream({ 3, 5, 7, 8, 9 }):max(), 9)
    lu.assertEquals(stream({ 10, 3, 5, 7, 8, 9 }):max(), 10)
end

function TestStreamLib:test_groupby()
    local map = stream({
        { name = 'test',   id = 1 },
        { name = 'test',   id = 2 },
        { name = 'other',  id = 3 },
        { name = 'other',  id = 4 },
        { name = 'single', id = 5 }
    }):groupby(function(tbl) return tbl.name end)

    lu.assertEquals(#map.test, 2)
    lu.assertEquals(#map.other, 2)
    lu.assertEquals(#map.single, 1)

    lu.assertEquals(map.test[1], { name = 'test', id = 1 })
    lu.assertEquals(map.test[2], { name = 'test', id = 2 })

    lu.assertEquals(map.other[1].id, 3)
    lu.assertEquals(map.other[2].id, 4)

    lu.assertEquals(map.single[1], { name = 'single', id = 5 })
end
