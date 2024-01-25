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
    lu.assertEquals(true, l:is_empty())
end

function Test_collection_list.Test_add_one_size_is_1()
    local l = list:new():add("test")

    lu.assertEquals(1, l:size())
end

function Test_collection_list.Test_addall_with_8_size_is_8()
    local l = list:new():add_all(eight_elemets)

    lu.assertEquals(8, l:size())
end

function Test_collection_list.Test_list_is_empty_after_clear()
    local l = list:new():add_all(eight_elemets):clear()

    lu.assertEquals(0, l:size())
    lu.assertEquals(true, l:is_empty())
end

function Test_collection_list.Test_remove_2_of_8_elemets_size_is_6()
    local l = list:new():add_all(eight_elemets)
    l:remove("2")
    l:remove(true)
    l:remove("Not in set")

    lu.assertEquals(6, l:size())
end

function Test_collection_list.Test_remove_3_of_8_elemets_size_is_5()
    local l = list:new():add_all(eight_elemets)
    l:remove_all { 1, 4.1, "5", "not", "in", "set" }

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
        lu.assertEquals(true, l:contains(item))
    end

    lu.assertEquals(false, l:contains("Not in set"))
    lu.assertEquals(false, l:contains(10))
    lu.assertEquals(false, l:contains(false))
end

function Test_collection_list.Test_contains_all()
    local l = list:new():add_all(eight_elemets)

    lu.assertEquals(true, l:contains_all(eight_elemets))
    lu.assertEquals(true, l:contains_all { 1, "2", "three" })
    lu.assertEquals(false, l:contains_all { 1, 2, "three" })
end

function Test_collection_list.Test_copy_equals_orig()
    local l = list:new():add_all(eight_elemets)
    local l2 = l:copy()

    lu.assertEquals(l:size(), l2:size())
    lu.assertEquals(true, l2:contains_all(eight_elemets))
    lu.assertEquals(true, l2:remove_all(eight_elemets):is_empty())
end

function Test_collection_list.Test_table_equals_list()
    local l = list:new():add_all(eight_elemets)

    lu.assertEquals(true, l:equals(eight_elemets))
    lu.assertEquals(false, l:equals({ 1, "2", "three" }))
end

function Test_collection_list.Test_union()
    local l1 = list:new():add_all({ 1, "2", "three", 4.1, "5" })
    local l2 = list:new():add_all({ tbl, true, func })
    local union = l1:union(l2)

    lu.assertEquals(true, union:equals(eight_elemets))
    lu.assertEquals(5, l1:size())
    lu.assertEquals(3, l2:size())
end

function Test_collection_list.Test_intersection()
    local l1 = list:new():add_all(eight_elemets)
    local l2 = list:new():add_all({ 1, "2", "three", 99, "not there" })
    local intersection = l1:intersection(l2)

    lu.assertEquals(true, intersection:equals({ 1, "2", "three" }))
    lu.assertEquals(8, l1:size())
    lu.assertEquals(5, l2:size())
end

function Test_collection_list.Test_difference()
    local l1 = list:new():add_all(eight_elemets)
    local l2 = list:new():add_all({ tbl, true, func })
    local difference = l1:difference(l2)

    lu.assertEquals(true, difference:equals({ 1, "2", "three", 4.1, "5" }))
    lu.assertEquals(8, l1:size())
    lu.assertEquals(3, l2:size())
end

function Test_collection_list.Test_stream()
    lu.assertEquals(15, list:new():add_all({ 1, 2, 3, 4, 5 }):stream():sum())
end

if not RUN_ALL then
    os.exit(lu.LuaUnit.run('-v'))
end
