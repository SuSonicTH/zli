local lu = require 'luaunit'
lu.ORDER_ACTUAL_EXPECTED = false

local luastrip = require "luastrip"

Test_luastrip = {}

function Test_luastrip.Test_string_one_liner()
    lu.assertEquals("local a=1", luastrip.string("\t local\t a = 1 \n"))
end

function Test_luastrip.Test_bigger_block()
    local block = "\r\n" .. [=[

-- Some bigger script



    local a =   1
local   b =   2

--[[ Big Block of comment
        should be removed
]]
print ( 'result =\''  ..
( a + b ) ..
 '\'')



    ]=]

    lu.assertEquals("local a=1 local b=2 print('result =\\''..(a+b)..'\\'')", luastrip.string(block))
end

if not RUN_ALL then
    os.exit(lu.LuaUnit.run('-v'))
end
