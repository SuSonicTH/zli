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

function Test_collection_map.Test_contains_key()
    local m = map:new(test_map)

    lu.assertIsTrue(m:contains_key('a'))
    lu.assertIsTrue(m:contains_key('b'))
    lu.assertIsTrue(m:contains_key('c'))

    lu.assertIsFalse(m:contains_key('d'))
    lu.assertIsFalse(m:contains_key('z'))
end

function Test_collection_map.Test_contains_value()
    local m = map:new(test_map)

    lu.assertIsTrue(m:contains_value('A'))
    lu.assertIsTrue(m:contains_value('B'))
    lu.assertIsTrue(m:contains_value('C'))

    lu.assertIsFalse(m:contains_value('D'))
    lu.assertIsFalse(m:contains_value('Z'))
end

function Test_collection_map.Test_entry_set()
    local m = map:new(test_map)
    local list = m:entry_set():stream():toarray()
    table.sort(list, L "(a,b)-> a.key<b.key")
    lu.assertEquals({
        {
            key = "a",
            value = "A"
        },
        {
            key = "b",
            value = "B"
        },
        {
            key = "c",
            value = "C"
        }
    }, list)
end

function Test_collection_map.Test_map_equals_same()
    local m1 = map:new(test_map)
    local m2 = map:new(test_map)

    lu.assertIsTrue(m1:equals(m2))
    lu.assertIsTrue(m1:equals(m1))
    lu.assertIsTrue(m2:equals(m1))
    lu.assertIsTrue(m2:equals(m2))
    lu.assertIsTrue(m1:equals({ a = 'A', b = 'B', c = 'C' }))
end

function Test_collection_map.Test_map_equals_diff()
    local m = map:new(test_map)
    local extra = map:new(test_map)
    extra:put('d', 'D')

    lu.assertIsFalse(m:equals(extra))
    lu.assertIsFalse(m:equals({ a = 'A', b = 'B', c = 'C', d = 'D' }))

    local less = map:new(test_map)
    less:remove('b')

    lu.assertIsFalse(m:equals(less))
    lu.assertIsFalse(m:equals({ b = 'B', c = 'C' }))

    local diff_val = map:new(test_map)
    diff_val:put('a', 'a')

    lu.assertIsFalse(m:equals(diff_val))
    lu.assertIsFalse(m:equals({ a = 'A', b = 'b', c = 'C' }))
end

function Test_collection_map.Test_key_set()
    local m = map:new(test_map)

    lu.assertIsTrue(m:key_set():equals({ 'a', 'b', 'c' }))
end

function Test_collection_map.Test_values()
    local m = map:new(test_map)
    local list = m:values():stream():toarray()
    table.sort(list)

    lu.assertEquals(list, { 'A', 'B', 'C' })
end

function Test_collection_map.Test_compute()
    local m = map:new()

    lu.assertEquals("A", m:compute("a", L ":upper"))
    lu.assertEquals("A", m:get('a'))
end

function Test_collection_map.Test_compute_if_absent()
    local m = map:new()

    lu.assertEquals("A", m:compute_if_absent("a", L ":upper"))
    lu.assertEquals("A", m:get('a'))
    lu.assertEquals("A", m:compute_if_absent("a", L "->'Z'"))
end

function Test_collection_map.Test_compute_if_present()
    local m = map:new(test_map)

    lu.assertEquals("X", m:compute_if_present("a", L "->'X'"))
    lu.assertEquals("X", m:get('a'))
    lu.assertEquals(3, m:size())

    lu.assertIsNil(m:compute_if_present("z", L "->'Z'"))
    lu.assertEquals(3, m:size())

    lu.assertIsNil(m:compute_if_present("a", L "->nil"))
    lu.assertEquals(2, m:size())
end

function Test_collection_map.Test_for_each()
    local m = map:new(test_map)
    local tbl = {}
    m:for_each(function(k, v)
        tbl[k] = v
    end)
    lu.assertIsTrue(m:equals(tbl))
end

function Test_collection_map.Test_replace()
    local m = map:new(test_map)
    lu.assertEquals('A', m:replace('a', 'Z'))
    lu.assertEquals('Z', m:get('a'))

    lu.assertIsNil(m:replace('z', 'Z'))
    lu.assertEquals(3, m:size())

    lu.assertEquals('B', m:replace('b', nil))
    lu.assertIsNil(m:get('b'))
    lu.assertEquals(2, m:size())
end

function Test_collection_map.Test_replace_old_equals()
    local m = map:new(test_map)
    lu.assertEquals('A', m:replace('a', 'A', 'Z'))
    lu.assertEquals('Z', m:get('a'))

    lu.assertEquals('B', m:replace('b', 'Z', 'X'))
    lu.assertEquals('B', m:get('b'))

    lu.assertIsNil(m:replace('z', 'Z', 'X'))
    lu.assertEquals(3, m:size())
end

function Test_collection_map.Test_merge()
    local m = map:new(test_map)

    lu.assertEquals('Z', m:merge('z', 'Z'))
    lu.assertEquals('Y', m:merge('a', 'X', L "->'Y'"))
end

function Test_collection_map.Test_iterate()
    local m = map:new(test_map)
    local res = {}
    for k, v in m:iterate() do
        res[k] = v
    end
    lu.assertIsTrue(m:equals(res))
end

function Test_collection_map.Test_ordered_itereator_keeps_order()
    local m = map:new_ordered()
    m:put("a", 'A')
    m:put("b", 'B')
    m:put("c", 'C')
    m:put("d", 'D')

    local list = {}
    for k, v in m:iterate() do
        list[#list + 1] = { k, v }
    end

    lu.assertEquals({
        { "a", 'A' },
        { "b", 'B' },
        { "c", 'C' },
        { "d", 'D' },
    }, list)
end

function Test_collection_map.Test_ordered_for_each_keeps_order()
    local m = map:new_ordered()
    m:put("a", 'A')
    m:put("b", 'B')
    m:put("c", 'C')
    m:put("d", 'D')

    local list = {}
    m:for_each(function(k, v)
        list[#list + 1] = { k, v }
    end)

    lu.assertEquals({
        { "a", 'A' },
        { "b", 'B' },
        { "c", 'C' },
        { "d", 'D' },
    }, list)
end

function Test_collection_map.Test_ordered_iterator_keeps_order()
    local m = map:new_ordered()
    m:put("a", 'A')
    m:put("b", 'B')
    m:put("c", 'C')
    m:put("d", 'D')

    local list = {}
    m:iterator(function(k, v)
        list[#list + 1] = { k, v }
        return true
    end)

    lu.assertEquals({
        { "a", 'A' },
        { "b", 'B' },
        { "c", 'C' },
        { "d", 'D' },
    }, list)
end

function Test_collection_map.Test_ordered_for_each_keeps_order_and_breaks()
    local m = map:new_ordered()
    m:put("a", 'A')
    m:put("b", 'B')
    m:put("c", 'C')
    m:put("d", 'D')
    m:put("e", 'E')

    local list = {}
    m:iterator(function(k, v)
        list[#list + 1] = { k, v }
        if v == 'C' then
            return false
        end
        return true
    end)

    lu.assertEquals({
        { "a", 'A' },
        { "b", 'B' },
        { "c", 'C' },
    }, list)
end

if not RUN_ALL then
    os.exit(lu.LuaUnit.run('-v'))
end
