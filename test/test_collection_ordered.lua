local lu = require 'luaunit'
lu.ORDER_ACTUAL_EXPECTED = false

local collection = require("collection")

Test_collection_ordered = {}

function Test_collection_ordered.Test_set_remove_keeps_order()
    local s = collection.set.new_ordered()
    s:add("a")
    s:add("b")
    s:add("c")
    s:remove("a")
    lu.assertEquals({ "b", "c" }, s:to_array())
end

function Test_collection_ordered.Test_set_clear_keeps_order_consistent()
    local s = collection.set.new_ordered()
    s:add("a")
    s:add("b")
    s:clear()
    s:add("x")
    s:add("y")
    lu.assertEquals({ "x", "y" }, s:to_array())
end

function Test_collection_ordered.Test_set_iterate_indexed()
    local s = collection.set.new_ordered()
    s:add("a")
    s:add("b")
    local values = {}
    for i, value in s:iterate_indexed() do
        values[i] = value
    end
    lu.assertEquals({ "a", "b" }, values)
end

function Test_collection_ordered.Test_map_remove_keeps_order()
    local m = collection.map.new_ordered()
    m:put("a", 1)
    m:put("b", 2)
    m:put("c", 3)
    m:remove("b")

    local keys = {}
    for key in m:iterate() do
        keys[#keys + 1] = key
    end
    lu.assertEquals({ "a", "c" }, keys)
end

function Test_collection_ordered.Test_map_clear_keeps_order_consistent()
    local m = collection.map.new_ordered()
    m:put("a", 1)
    m:put("b", 2)
    m:clear()
    m:put("x", 1)
    m:put("y", 2)

    local keys = {}
    for key in m:iterate() do
        keys[#keys + 1] = key
    end
    lu.assertEquals({ "x", "y" }, keys)
end

function Test_collection_ordered.Test_map_compute_updates_size_and_order()
    local m = collection.map.new_ordered()
    lu.assertEquals(1, m:compute_if_absent("a", function() return 1 end))
    lu.assertEquals(1, m:size())
    lu.assertEquals(2, m:compute("b", function() return 2 end))
    lu.assertEquals(2, m:size())
    m:compute_if_present("a", function() return nil end)
    lu.assertEquals(1, m:size())

    local keys = {}
    for key in m:iterate() do
        keys[#keys + 1] = key
    end
    lu.assertEquals({ "b" }, keys)
end

function Test_collection_ordered.Test_list_remove_index_validates_argument()
    local l = collection.list.new():add_all({ 1, 2, 3 })
    lu.assertError(function() l:remove_index("bad") end)
end

if not RUN_ALL then
    os.exit(lu.LuaUnit.run('-v'))
end
