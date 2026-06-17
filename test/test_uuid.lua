local lu = require 'luaunit'
lu.ORDER_ACTUAL_EXPECTED = false

local uuid = require "uuid"
Test_uuid = {}

local uuidPattern = "%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x"

function Test_uuid:Test_v4()
    local v41 = uuid.v4()
    local v42 = uuid.v4()
    lu.assertStrMatches(v41, uuidPattern)
    lu.assertStrMatches(v42, uuidPattern)
    lu.assertNotEquals(v41, v42)
end

function Test_uuid:Test_v7()
    local v71 = uuid.v7()
    local v72 = uuid.v7()
    lu.assertStrMatches(v71, uuidPattern)
    lu.assertStrMatches(v72, uuidPattern)
    lu.assertNotEquals(v71, v72)
    lu.assertEquals(v71:sub(0, 12), v72:sub(0, 12))
end

if not RUN_ALL then
    os.exit(lu.LuaUnit.run('-v'))
end
