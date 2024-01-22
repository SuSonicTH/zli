local lu = require 'luaunit'
lu.ORDER_ACTUAL_EXPECTED = false

local set = require("collection").set

local eight_elemets = { 1, "2", "three", 4.1, "5", { 6 }, true, function() return "8" end }

function test_new_set_is_empty()
    local s = set:new()
    lu.assertEquals(0, s:size())
    lu.assertEquals(true, s:is_empty())
end

function test_add_one_size_is_1()
    local s = set:new():add("test")
    lu.assertEquals(1, s:size())
end

function test_addall_with_8_size_is_8()
    local s = set:new():add_all(eight_elemets)
    lu.assertEquals(8, s:size())
end

function test_set_is_empty_after_clear()
    local s = set:new():add_all(eight_elemets):clear()
    lu.assertEquals(0, s:size())
    lu.assertEquals(true, s:is_empty())
end

function test_remove_2_of_8_elemets_size_is_6()
    local s = set:new():add_all(eight_elemets)
    s:remove("2")
    s:remove(true)
    s:remove("Not in set")
    lu.assertEquals(6, s:size())
end

function test_remove_3_of_8_elemets_size_is_5()
    local s = set:new():add_all(eight_elemets)
    s:remove_all { 1, 4.1, "5", "not", "in", "set" }
    lu.assertEquals(5, s:size())
end

function test_retain_3_of_8_elemets_size_is_3()
    local s = set:new():add_all(eight_elemets)
    s:retain_all { 1, 4.1, "5", "not", "in", "set" }
    lu.assertEquals(3, s:size())
end

function test_contains()
    local s = set:new():add_all(eight_elemets)
    for _, item in ipairs(eight_elemets) do
        lu.assertEquals(true, s:contains(item))
    end
    lu.assertEquals(false, s:contains("Not in set"))
    lu.assertEquals(false, s:contains(10))
    lu.assertEquals(false, s:contains(false))
end

function test_contains_all()
    local s = set:new():add_all(eight_elemets)
    lu.assertEquals(true, s:contains_all(eight_elemets))
    lu.assertEquals(true, s:contains_all { 1, "2", "three" })
    lu.assertEquals(false, s:contains_all { 1, 2, "three" })
end

function test_copy_equals_orig()
    local s = set:new():add_all(eight_elemets)
    local s2 = s:copy()
    lu.assertEquals(s:size(), s2:size())
    lu.assertEquals(true, s2:contains_all(eight_elemets))
    lu.assertEquals(true, s2:remove_all(eight_elemets):is_empty())
end

return lu.LuaUnit.run('-v')