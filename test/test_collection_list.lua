local lu = require 'luaunit'
lu.ORDER_ACTUAL_EXPECTED = false

local list = require("collection").list

local tbl = { 6 }
local func = function() return "8" end
local eight_elemets = { 1, "2", "three", 4.1, "5", tbl, true, func }

Test_collection_list = {}

function Test_collection_list.Test_new_list_is_empty()
    local l = list:new()

    lu.assertEquals(0, l:size())
    lu.assertIsTrue(l:is_empty())
end

function Test_collection_list.Test_add_with_index_insert()
    local l = list:new():add_all({ 1, 2, 4 }):add(3, 3)
    lu.assertEquals({ 1, 2, 3, 4 }, l._items)
end

function Test_collection_list.Test_add_with_index_at_end()
    local l = list:new():add_all({ 1, 2 }):add(3, 3)
    lu.assertEquals({ 1, 2, 3 }, l._items)
end

function Test_collection_list.Test_add_with_index_at_start()
    local l = list:new():add_all({ 2, 3 }):add(1, 1)
    lu.assertEquals({ 1, 2, 3 }, l._items)
end

function Test_collection_list.Test_add_one_size_is_1()
    local l = list:new():add("test")

    lu.assertEquals(1, l:size())
end

function Test_collection_list.Test_addall_with_8_size_is_8()
    local l = list:new():add_all(eight_elemets)

    lu.assertEquals(8, l:size())
end

function Test_collection_list.Test_addall_with_index()
    local l = list:new():add_all({ 1, 2, 6 }):add_all(3, { 3, 4, 5 })
end

function Test_collection_list.Test_iterate()
    local l = list:new():add_all({ 'a', 'b', 'c', 'd', 'e' })
    local str = ""
    for item in l:iterate() do
        str = str .. item .. ","
    end
    lu.assertEquals("a,b,c,d,e,", str)
end

function Test_collection_list.Test_iterate_index()
    local l = list:new():add_all({ 'a', 'b', 'c', 'd', 'e' })
    local str = ""
    for i, item in l:iterate_indexed() do
        str = str .. i .. ":" .. item .. ","
    end
    lu.assertEquals("1:a,2:b,3:c,4:d,5:e,", str)
end

function Test_collection_list.Test_get()
    local l = list:new():add_all({ 'a', 'b', 'c' })
    lu.assertEquals('a', l:get(1))
    lu.assertEquals('b', l:get(2))
    lu.assertEquals('c', l:get(3))
    lu.assertIsNil(l:get(5))
end

function Test_collection_list.Test_set()
    local l = list:new():add_all({ 'a', 'b', 'c' })
    l:set(1, 'aa')
    l:set(3, 'cc')
    l:set(2, 'bb')
    lu.assertEquals({ 'aa', 'bb', 'cc' }, l._items)
end

function Test_collection_list.Test_index_of()
    local l = list:new():add_all({ 'a', 'b', 'c' })
    lu.assertEquals(1, l:index_of('a'))
    lu.assertEquals(2, l:index_of('b'))
    lu.assertEquals(3, l:index_of('c'))
    lu.assertEquals(0, l:index_of('x'))
end

function Test_collection_list.Test_last_index_of()
    local l = list:new():add_all({ 'a', 'b', 'b', 'c', 'b', 'd', 'e' })
    lu.assertEquals(1, l:last_index_of('a'))
    lu.assertEquals(5, l:last_index_of('b'))
    lu.assertEquals(4, l:last_index_of('c'))
    lu.assertEquals(7, l:last_index_of('e'))
    lu.assertEquals(0, l:last_index_of('x'))
end

function Test_collection_list.Test_remove_index()
    local l = list:new():add_all({ 'a', 'b', 'c', 'd', 'e' })

    l:remove_index(2)
    lu.assertEquals({ 'a', 'c', 'd', 'e' }, l._items)
    lu.assertEquals(4, l:size())

    l:remove_index(3)
    lu.assertEquals({ 'a', 'c', 'e' }, l._items)
    lu.assertEquals(3, l:size())

    l:remove_index(3)
    lu.assertEquals({ 'a', 'c' }, l._items)
    lu.assertEquals(2, l:size())

    l:remove_index(1)
    lu.assertEquals({ 'c' }, l._items)
    lu.assertEquals(1, l:size())
end

function Test_collection_list.Test_list_is_empty_after_clear()
    local l = list:new():add_all(eight_elemets):clear()

    lu.assertEquals(0, l:size())
    lu.assertIsTrue(l:is_empty())
end

function Test_collection_list.Test_remove_2_of_8_elemets_size_is_6()
    local l = list:new():add_all(eight_elemets)
    lu.assertTrue(l:remove("2"))
    lu.assertTrue(l:remove(true))
    lu.assertFalse(l:remove("Not in set"))

    lu.assertEquals(6, l:size())
end

function Test_collection_list.Test_remove_3_of_8_elemets_size_is_5()
    local l = list:new():add_all(eight_elemets)
    lu.assertIsTrue(l:remove_all { 1, 4.1, "5", "not", "in", "set" })
    lu.assertIsFalse(l:remove_all { "not", "in", "set" })
    lu.assertEquals(5, l:size())
end

function Test_collection_list.Test_retain_3_of_8_elemets_size_is_3()
    local l = list:new():add_all(eight_elemets)
    l:retain_all { 1, 4.1, "5", "not", "in", "set" }

    lu.assertEquals(3, l:size())
end

function Test_collection_list.Test_contains()
    local l = list:new():add_all(eight_elemets)
    for _, item in ipairs(eight_elemets) do
        lu.assertIsTrue(l:contains(item))
    end

    lu.assertEquals(false, l:contains("Not in set"))
    lu.assertEquals(false, l:contains(10))
    lu.assertEquals(false, l:contains(false))
end

function Test_collection_list.Test_contains_all()
    local l = list:new():add_all(eight_elemets)

    lu.assertIsTrue(l:contains_all(eight_elemets))
    lu.assertIsTrue(l:contains_all { 1, "2", "three" })
    lu.assertEquals(false, l:contains_all { 1, 2, "three" })
end

function Test_collection_list.Test_copy_equals_orig()
    local l = list:new():add_all(eight_elemets)
    local l2 = l:copy()

    lu.assertEquals(l:size(), l2:size())
    lu.assertIsTrue(l2:contains_all(eight_elemets))
    lu.assertIsTrue(l2:remove_all(eight_elemets))
    lu.assertIsTrue(l2:is_empty())
end

function Test_collection_list.Test_table_equals_list()
    local l = list:new():add_all(eight_elemets)

    lu.assertIsTrue(l:equals(eight_elemets))
    lu.assertEquals(false, l:equals({ 1, "2", "three" }))
end

function Test_collection_list.Test_union()
    local l1 = list:new():add_all({ 1, "2", "three", 4.1, "5" })
    local l2 = list:new():add_all({ tbl, true, func })
    local union = l1:union(l2)

    lu.assertIsTrue(union:equals(eight_elemets))
    lu.assertEquals(5, l1:size())
    lu.assertEquals(3, l2:size())
end

function Test_collection_list.Test_intersection()
    local l1 = list:new():add_all(eight_elemets)
    local l2 = list:new():add_all({ 1, "2", "three", 99, "not there" })
    local intersection = l1:intersection(l2)

    lu.assertIsTrue(intersection:equals({ 1, "2", "three" }))
    lu.assertEquals(8, l1:size())
    lu.assertEquals(5, l2:size())
end

function Test_collection_list.Test_difference()
    local l1 = list:new():add_all(eight_elemets)
    local l2 = list:new():add_all({ tbl, true, func })
    local difference = l1:difference(l2)

    lu.assertIsTrue(difference:equals({ 1, "2", "three", 4.1, "5" }))
    lu.assertEquals(8, l1:size())
    lu.assertEquals(3, l2:size())
end

function Test_collection_list.Test_stream()
    lu.assertEquals(15, list:new():add_all({ 1, 2, 3, 4, 5 }):stream():sum())
end

function Test_collection_list.Test_sub_list()
    local l = list:new():add_all({ 'a', 'b', 'c', 'd', 'e' })

    lu.assertEquals({ 'a', 'b', 'c' }, l:sublist(1, 3)._items)
    lu.assertEquals({ 'b', 'c', 'd' }, l:sublist(2, 4)._items)
    lu.assertEquals({ 'c', 'd', 'e' }, l:sublist(3, 5)._items)
end

function Test_collection_list.Test_to_array()
    local items = { 'a', 'b', 'c', 'd', 'e' }
    local l = list:new():add_all(items)

    lu.assertEquals(items, l:to_array())
end

function Test_collection_list.Test_for_each()
    local items = { 'a', 'b', 'c', 'd', 'e' }
    local l = list:new():add_all(items)
    local str = ""
    l:for_each(function(item) str = str .. item end)
    lu.assertEquals("abcde", str)
end

function Test_collection_list.Test_for_each_index()
    local items = { 'a', 'b', 'c', 'd', 'e' }
    local l = list:new():add_all(items)
    local str = ""
    l:for_each_index(function(i, item) str = str .. i .. ":" .. item .. ',' end)
    lu.assertEquals("1:a,2:b,3:c,4:d,5:e,", str)
end

function Test_collection_list.Test_sorted_list()
    local items = { 'b', 'a', 'e', 'd', 'c' }
    local l = list:new_sorted():add_all(items)
    local str = ""
    l:for_each_index(function(i, item) str = str .. i .. ":" .. item .. ',' end)
    lu.assertEquals("1:a,2:b,3:c,4:d,5:e,", str)
end

if not RUN_ALL then
    os.exit(lu.LuaUnit.run('-v'))
end
