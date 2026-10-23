local lu = require 'luaunit'
lu.ORDER_ACTUAL_EXPECTED = false

local grid = require "grid"

Test_grid = {}

function Test_grid.Test_dot_call()
    local g = grid.new { { name = "a" }, { name = "b" } }
    g:add_row(1, 2)
    local text = g:tostring()
    lu.assertStrContains(text, "a")
    lu.assertStrContains(text, "b")
    lu.assertStrContains(text, "1")
    lu.assertStrContains(text, "2")
end

function Test_grid.Test_colon_call_is_supported()
    local g = grid:new { { name = "a" } }
    g:add_row("value")
    lu.assertStrContains(g:tostring(), "value")
end

function Test_grid.Test_empty_grid_tostring()
    local g = grid.new { { name = "only" } }
    local ok, text = pcall(function() return g:tostring() end)
    lu.assertIsTrue(ok, tostring(text))
    lu.assertStrContains(text, "only")
end

function Test_grid.Test_tostring_metamethod()
    local g = grid.new { { name = "a" } }
    g:add_row(1)
    lu.assertStrContains(tostring(g), "1")
end

if not RUN_ALL then
    os.exit(lu.LuaUnit.run('-v'))
end
