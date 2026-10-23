local lu = require 'luaunit'
lu.ORDER_ACTUAL_EXPECTED = false

local timer = require "timer"

Test_timer = {}

function Test_timer.Test_start_stop_time()
    local t = timer.new()
    lu.assertIsNil(t:time())
    t:start()
    local elapsed = t:elapsed()
    lu.assertIsTrue(elapsed >= 0)
    local stopped = t:stop()
    lu.assertIsTrue(stopped >= 0)
    lu.assertEquals(stopped, t:time())
end

function Test_timer.Test_laps_and_reset()
    local t = timer.new(true)
    t:lap()
    t:lap()
    lu.assertEquals(2, #t.laps)
    lu.assertIsTrue(t:lap_elapsed() >= 0)
    t:reset()
    lu.assertEquals(0, #t.laps)
    lu.assertIsNil(t:time())
end

if not RUN_ALL then
    os.exit(lu.LuaUnit.run('-v'))
end
