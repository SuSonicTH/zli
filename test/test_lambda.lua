local lu = require 'luaunit'
lu.ORDER_ACTUAL_EXPECTED = false

Test_lambda = {}

function Test_lambda.Test_colon()
    lu.assertEquals("Hello lambda", L(":hello")({ hello = function() return "Hello lambda" end }))
end

function Test_lambda.Test_dot()
    lu.assertEquals("Hello lambda", L(".hello")({ hello = "Hello lambda" }))
end

function Test_lambda.Test_bracket_arg()
    lu.assertEquals("Hello lambda", L("(a,b)-> a..' '..b")("Hello", "lambda"))
end

function Test_lambda.Test_bracket_no_arg()
    lu.assertEquals("Hello lambda", L("()-> 'Hello lambda'")())
end

function Test_lambda.Test_arrow()
    lu.assertEquals("Hello lambda", L("-> 'Hello '..it")('lambda'))
end

function Test_lambda.Test_function()
    lu.assertEquals("Hello lambda", L("'Hello '..it")('lambda'))
end

function Test_lambda.Test_string_L()
    lu.assertEquals("Hello lambda", (("'Hello '..it"):L())('lambda'))
end

function Test_lambda.Test_L()
    lu.assertEquals("Hello lambda", L "'Hello '..it" ('lambda'))
end

if not RUN_ALL then
    os.exit(lu.LuaUnit.run('-v'))
end
