local lu = require "luaunit"
local log = require "log"
--local fs = require("filesystem")

TestLibraries = {}

TestAuxLib = {}

function TestAuxLib:test_table_to_String()
    local tbl = {
        1,
        "2",
        3,
        key = "value"
    }
    lu.assertEquals(table.tostring(tbl, "tbl"), 'tbl = {\n    1,\n    "2",\n    3,\n    key = "value"\n}')
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

--[[removed from lib
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
]]

--[==[removed from lib
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
]==]

--[[re-add after zip impl
function TestLibraries:test_zip()
    local testfile = "test.zip"
    local inputfile = "README.md"
    os.remove(testfile)

    local testzip = zip.create(testfile)
    testzip:addfile(inputfile, inputfile)
    testzip:close()

    local file = zip.open(testfile)
    lu.assertEquals(file.files[inputfile].name, inputfile)
    lu.assertEquals(file.files[inputfile].uncompressed_size, fs.size(inputfile))
    file:close()

    os.remove(testfile)
end
]]
