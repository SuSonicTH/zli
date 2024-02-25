local lu = require 'luaunit'
lu.ORDER_ACTUAL_EXPECTED = false

local memoize = require "memoize"

Test_memoize = {}

local called = 0
local function func(...)
    called = called + 1
    return "ret", table.pack(...);
end

function Test_memoize.Test_no_argument()
    called = 0
    local mem = memoize(func)

    for _ = 1, 3 do
        local ret, res = mem()
        lu.assertEquals("ret", ret)
        lu.assertEquals(0, res.n)
        lu.assertEquals(1, called)
    end
end

function Test_memoize.Test_one_argument()
    called = 0
    local mem = memoize(func)

    for _ = 1, 3 do
        local ret, res = mem("test")
        lu.assertEquals("ret", ret)
        lu.assertEquals(1, res.n)
        lu.assertEquals("test", res[1])

        lu.assertEquals(1, called)
    end
end

function Test_memoize.Test_none_and_one_argument()
    called = 0
    local mem = memoize(func)

    for _ = 1, 3 do
        local ret, res = mem()
        lu.assertEquals("ret", ret)
        lu.assertEquals(0, res.n)

        lu.assertEquals(1, called)
    end

    for _ = 1, 3 do
        local ret, res = mem("test")
        lu.assertEquals("ret", ret)
        lu.assertEquals(1, res.n)
        lu.assertEquals("test", res[1])

        lu.assertEquals(2, called)
    end
end

function Test_memoize.Test_three_arguments()
    called = 0
    local mem = memoize(func)

    for _ = 1, 3 do
        local ret, res = mem("one", "two", "three")
        lu.assertEquals("ret", ret)
        lu.assertEquals(3, res.n)
        lu.assertEquals("one", res[1])
        lu.assertEquals("two", res[2])
        lu.assertEquals("three", res[3])

        lu.assertEquals(1, called)
    end

    for _ = 1, 3 do
        local ret, res = mem("one", nil, "three")
        lu.assertEquals("ret", ret)
        lu.assertEquals(3, res.n)
        lu.assertEquals("one", res[1])
        lu.assertIsNil(res[2])
        lu.assertEquals("three", res[3])

        lu.assertEquals(2, called)
    end

    for _ = 1, 3 do
        local ret, res = mem(nil, "two", "three")
        lu.assertEquals("ret", ret)
        lu.assertEquals(3, res.n)
        lu.assertIsNil(res[1])
        lu.assertEquals("two", res[2])
        lu.assertEquals("three", res[3])

        lu.assertEquals(3, called)
    end
end
