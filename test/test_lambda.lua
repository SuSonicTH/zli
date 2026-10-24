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

function Test_lambda.Test_local_variable()
    local base = 40
    lu.assertEquals(42, L("it + base")(2))
end

function Test_lambda.Test_local_after_scope()
    local function make()
        local base = 40
        local fn = L("it + base")
        return fn
    end
    lu.assertEquals(42, make()(2))
end

function Test_lambda.Test_upvalue()
    local base = 40
    local function make()
        local fn = L("base + it")
        return fn
    end
    lu.assertEquals(42, make()(2))
end

function Test_lambda.Test_outer_scope()
    local prefix = "Hello "
    local function make()
        return L("prefix .. it")
    end
    lu.assertEquals("Hello lambda", make()("lambda"))
end

function Test_lambda.Test_local_function()
    local function greet(name)
        return "Hello " .. name
    end
    lu.assertEquals("Hello lambda", L("greet(it)")("lambda"))
end

function Test_lambda.Test_stream_lambda()
    local multiplier = 2
    local stream = require "stream"
    lu.assertEquals({ 2, 4, 6 }, stream({ 1, 2, 3 }):map("it * multiplier"):toarray())
end

function Test_lambda.Test_upvalue_is_live()
    local value = 1
    local function make()
        local fn = L("value")
        value = 2
        return fn
    end
    lu.assertEquals(2, make()())
end

if not RUN_ALL then
    os.exit(lu.LuaUnit.run('-v'))
end
