--[[ base class for all collections]]
local stream = require "stream"
local base = {}

function base:iterate(func)
    if self._is_collection and self._type == 'set' then
        for item, _ in pairs(self._items) do
            local ret = func(item)
            if ret == false or ret == nil then
                return false
            end
        end
    elseif self._is_collection and self._type == 'list' then
        for _, item in ipairs(self._items) do
            local ret = func(item)
            if ret == false or ret == nil then
                return false
            end
        end
    else
        for _, item in ipairs(self) do
            local ret = func(item)
            if ret == false or ret == nil then
                return false
            end
        end
    end
    return true
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
    base.iterate(items, function(item) return self:add(item) end)
    return self
end

function base:remove_all(collection)
    arg_check_type("collection:remove_all", 1, collection, 'table')
    base.iterate(collection, function(item) return self:remove(item) end)
    return self
end

function base:contains_all(collection)
    arg_check_type("set:contains_all", 1, collection, 'table')
    local finished = self.iterate(collection,
        function(item)
            return self:contains(item)
        end)
    return finished;
end

function base:equals(collection)
    arg_check_type("collection:equals", 1, collection, 'table')
    local count = 0
    local finished = self.iterate(collection,
        function(item)
            count = count + 1
            return self:contains(item)
        end
    )
    return finished and count == self._size
end

function base:copy()
    return self:new(self)
end

function base:stream()
    return stream(self:next())
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
    local index = 1

    self:iterate(function(item)
        array[index] = item
        index = index + 1
        return true
    end)

    return array
end

local mod = { base = base }
package.loaded.collection = mod

mod.set = require "collection.set"
mod.list = require "collection.list"
mod.map = require "collection.map"

return mod
