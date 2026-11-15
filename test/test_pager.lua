local lu = require 'luaunit'
lu.ORDER_ACTUAL_EXPECTED = false

local support = require "test/support"
local pager = require "pager"

Test_pager = {}

function Test_pager.Test_non_terminal_prints_everything()
    local script = support.temp_file("pager_non_tty", [[
local pager = require "pager"
print(pager.print("one\ntwo"))
print(pager.print({ "three", "four" }))
]])
    local stdout, status = support.run({ script }, { home = support.temp_dir("pager_home") })

    lu.assertEquals(0, status, stdout)
    lu.assertStrContains(stdout, "one\ntwo\n")
    lu.assertStrContains(stdout, "three\nfour\n")
    lu.assertNotStrContains(stdout, "false\n")
end

function Test_pager.Test_configure_validates_height()
    lu.assertTrue(pcall(pager.configure, { height = 5, prompt = "go on" }))
    lu.assertFalse(pcall(pager.configure, { height = 0 }))
    lu.assertFalse(pcall(pager.configure, { height = "many" }))
end

if not RUN_ALL then
    os.exit(lu.LuaUnit.run('-v'))
end
