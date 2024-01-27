local lu = require 'luaunit'
lu.ORDER_ACTUAL_EXPECTED = false

local map = require("collection").map

Test_collection_map = {}

local test_map = { a = 'A', b = 'B', c = 'C' }
function Test_collection_map.Test_new_map_is_empty()
    local m = map:new()

    lu.assertEquals(0, m:size())
    lu.assertEquals(true, m:is_empty())
end

function Test_collection_map.Test_put_one_item()
    local m = map:new()
    m:put("a", "A")

    lu.assertEquals(1, m:size())
    lu.assertEquals(false, m:is_empty())
end

local function assert_map_equals_test_map(m)
    lu.assertEquals(3, m:size())
    lu.assertEquals("A", m:get("a"))
    lu.assertEquals("B", m:get("b"))
    lu.assertEquals("C", m:get("c"))
end

function Test_collection_map.Test_put_three_items_and_get()
    local m = map:new()
    m:put("a", "A")
    m:put("b", "B")
    m:put("c", "C")
    assert_map_equals_test_map(m)
end

function Test_collection_map.Test_get_or_default()
    local m = map:new()
    m:put("a", "A")

    lu.assertEquals("A", m:get_or_default("a", "z"))
    lu.assertEquals("B", m:get_or_default("b", "B"))
end

function Test_collection_map.Test_put_all_with_table()
    local m = map:new():put_all(test_map)
    assert_map_equals_test_map(m)
end

function Test_collection_map.Test_put_all_with_map()
    local m = map:new():put_all(test_map)
    local m2 = map:new():put_all(m)
    assert_map_equals_test_map(m2)
end

function Test_collection_map.Test_put_if_absent()
    local m = map:new()

    m:put('a', 'A')
    lu.assertEquals("A", m:put_if_absent('a', 'Z'))
    lu.assertEquals("A", m:get('a'))

    lu.assertIsNil(m:put_if_absent('b', 'B'))
    lu.assertEquals("B", m:get('b'))
end

function Test_collection_map.Test_remove_key()
    local m = map:new(test_map)
    m:remove('b')

    lu.assertEquals(2, m:size())
    lu.assertEquals("A", m:get("a"))
    lu.assertEquals("C", m:get("c"))
end

function Test_collection_map.Test_remove_key_value()
    local m = map:new(test_map)

    lu.assertIsFalse(m:remove('b', 'Z'))
    assert_map_equals_test_map(m)

    lu.assertIsTrue(m:remove('b', 'B'))
    lu.assertEquals(2, m:size())
    lu.assertEquals("A", m:get("a"))
    lu.assertEquals("C", m:get("c"))
end

if not RUN_ALL then
    os.exit(lu.LuaUnit.run('-v'))
end
