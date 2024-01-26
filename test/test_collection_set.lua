local lu = require 'luaunit'
lu.ORDER_ACTUAL_EXPECTED = false

local set = require("collection").set

local tbl = { 6 }
local func = function() return "8" end
local eight_elemets = { 1, "2", "three", 4.1, "5", tbl, true, func }

Test_collection_set = {}

function Test_collection_set.Test_new_set_is_empty()
    local s = set:new()

    lu.assertEquals(0, s:size())
    lu.assertEquals(true, s:is_empty())
end

function Test_collection_set.Test_add_one_size_is_1()
    local s = set:new():add("test")

    lu.assertEquals(1, s:size())
end

function Test_collection_set.Test_addall_with_8_size_is_8()
    local s = set:new():add_all(eight_elemets)

    lu.assertEquals(8, s:size())
end

function Test_collection_set.Test_set_is_empty_after_clear()
    local s = set:new():add_all(eight_elemets):clear()

    lu.assertEquals(0, s:size())
    lu.assertEquals(true, s:is_empty())
end

function Test_collection_set.Test_remove_2_of_8_elemets_size_is_6()
    local s = set:new():add_all(eight_elemets)
    s:remove("2")
    s:remove(true)
    s:remove("Not in set")

    lu.assertEquals(6, s:size())
end

function Test_collection_set.Test_remove_3_of_8_elemets_size_is_5()
    local s = set:new():add_all(eight_elemets)
    s:remove_all { 1, 4.1, "5", "not", "in", "set" }

    lu.assertEquals(5, s:size())
end

function Test_collection_set.Test_retain_3_of_8_elemets_size_is_3()
    local s = set:new():add_all(eight_elemets)
    s:retain_all { 1, 4.1, "5", "not", "in", "set" }

    lu.assertEquals(3, s:size())
end

function Test_collection_set.Test_contains()
    local s = set:new():add_all(eight_elemets)
    for _, item in ipairs(eight_elemets) do
        lu.assertEquals(true, s:contains(item))
    end

    lu.assertEquals(false, s:contains("Not in set"))
    lu.assertEquals(false, s:contains(10))
    lu.assertEquals(false, s:contains(false))
end

function Test_collection_set.Test_contains_all()
    local s = set:new():add_all(eight_elemets)

    lu.assertEquals(true, s:contains_all(eight_elemets))
    lu.assertEquals(true, s:contains_all { 1, "2", "three" })
    lu.assertEquals(false, s:contains_all { 1, 2, "three" })
end

function Test_collection_set.Test_copy_equals_orig()
    local s = set:new():add_all(eight_elemets)
    local s2 = s:copy()

    lu.assertEquals(s:size(), s2:size())
    lu.assertEquals(true, s2:contains_all(eight_elemets))
    lu.assertEquals(true, s2:remove_all(eight_elemets):is_empty())
end

function Test_collection_set.Test_table_equals_set()
    local s = set:new():add_all(eight_elemets)

    lu.assertEquals(true, s:equals(eight_elemets))
    lu.assertEquals(false, s:equals({ 1, "2", "three" }))
end

function Test_collection_set.Test_union()
    local s1 = set:new():add_all({ 1, "2", "three", 4.1, "5" })
    local s2 = set:new():add_all({ tbl, true, func })
    local union = s1:union(s2)

    lu.assertEquals(true, union:equals(eight_elemets))
    lu.assertEquals(5, s1:size())
    lu.assertEquals(3, s2:size())
end

function Test_collection_set.Test_intersection()
    local s1 = set:new():add_all(eight_elemets)
    local s2 = set:new():add_all({ 1, "2", "three", 99, "not there" })
    local intersection = s1:intersection(s2)

    lu.assertEquals(true, intersection:equals({ 1, "2", "three" }))
    lu.assertEquals(8, s1:size())
    lu.assertEquals(5, s2:size())
end

function Test_collection_set.Test_difference()
    local s1 = set:new():add_all(eight_elemets)
    local s2 = set:new():add_all({ tbl, true, func })
    local difference = s1:difference(s2)

    lu.assertEquals(true, difference:equals({ 1, "2", "three", 4.1, "5" }))
    lu.assertEquals(8, s1:size())
    lu.assertEquals(3, s2:size())
end

function Test_collection_set.Test_stream()
    lu.assertEquals(15, set:new():add_all({ 1, 2, 3, 4, 5 }):stream():sum())
end

function Test_collection_set.Test_to_array()
    local items = { 'a', 'b', 'c', 'd', 'e' }
    local l = set:new():add_all(items)
    local array = l:to_array()
    table.sort(array, function(a, b) return a < b end)
    lu.assertEquals(items, array)
end

if not RUN_ALL then
    os.exit(lu.LuaUnit.run('-v'))
end
