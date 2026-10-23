local lu = require 'luaunit'
lu.ORDER_ACTUAL_EXPECTED = false

Test_config = {}

function Test_config.Test_filesystem_config_updates_same_table()
    local fs = require "filesystem"
    local same = fs:config { error_handling = "raise" }
    lu.assertIsTrue(same == fs)
    lu.assertEquals("raise", fs.error_handling)
    lu.assertError(function() fs.read_all("./test/temp/does-not-exist-config") end)

    fs:config { error_handling = "return" }
    lu.assertEquals("return", fs.error_handling)
    local value, err = fs.read_all("./test/temp/does-not-exist-config")
    lu.assertIsNil(value)
    lu.assertNotIsNil(err)
end

function Test_config.Test_luastrip_config()
    local strip = require "luastrip"
    local same = strip:config { error_handling = "raise" }
    lu.assertIsTrue(same == strip)
    lu.assertEquals("raise", strip.error_handling)
end

if not RUN_ALL then
    os.exit(lu.LuaUnit.run('-v'))
end
