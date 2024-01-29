--[[ base class for all collections]]
local stream = require "stream"
local base = {}

function base._iterate(items)
    if items._is_collection then
        return items:iterate()
    else
        local key
        local value
        return function()
            key, value = next(items, key)
            return value
        end
    end
end

function base:size()
    return self._size
end

function base:is_empty()
    return self._size == 0
end

function base:tostring()
    return table.tostring(self:stream():toarray())
end

function base:add_all(items)
    arg_check_type("collection:add_all", 1, items, 'table')
    for item in base._iterate(items) do
        self:add(item)
    end
    return self
end

function base:remove_all(items)
    arg_check_type("collection:remove_all", 1, items, 'table')
    local ret = false
    for item in base._iterate(items) do
        if not ret then
            ret = self:remove(item)
        else
            self:remove(item)
        end
    end
    return ret
end

function base:contains_all(items)
    arg_check_type("set:contains_all", 1, items, 'table')
    for item in base._iterate(items) do
        if not self:contains(item) then
            return false
        end
    end
    return true;
end

function base:equals(items)
    arg_check_type("collection:equals", 1, items, 'table')
    local count = 0
    for item in base._iterate(items) do
        if not self:contains(item) then
            return false
        end
        count = count + 1
    end
    return count == self._size
end

function base:copy()
    return self:new(self)
end

function base:stream()
    return stream(self:iterate())
end

function base:union(...)
    local ret = self:new(self);
    for _, collection in ipairs { ... } do
        ret:add_all(collection)
    end
    return ret
end

function base:intersection(...)
    local ret = self:new(self);
    for _, collection in ipairs { ... } do
        ret:retain_all(collection)
    end
    return ret
end

function base:difference(...)
    local ret = self:new(self);
    for _, collection in ipairs { ... } do
        ret:remove_all(collection)
    end
    return ret
end

function base:to_array()
    local array = table.create(self._size, 0)

    for index, item in self:iterate_indexed() do
        array[index] = item
    end

    return array
end

local mod = { base = base }
package.loaded.collection = mod

mod.set = require "collection.set"
mod.list = require "collection.list"
mod.map = require "collection.map"

return mod
