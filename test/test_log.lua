local lu = require 'luaunit'
lu.ORDER_ACTUAL_EXPECTED = false

local log = require "log"

Test_log = {}

local function logCollector()
    local collector = {
        logs = {}
    }
    function collector:append(logger, level, message)
        self.logs[#self.logs + 1] = { logger._name, level, message }
    end

    return collector
end

function Test_log:test_logging()
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

if not RUN_ALL then
    os.exit(lu.LuaUnit.run('-v'))
end
