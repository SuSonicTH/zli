--[[ base class for all collections]]
local stream = require "stream"
local base = {}

function base:iterate(func)
    if self._is_collection and self._type == 'set' then
        for item, _ in pairs(self._items) do
            if func(item) == nil then
                return false
            end
        end
    elseif self._is_collection and self._type == 'list' then
        for _, item in ipairs(self._items) do
            if func(item) == nil then
                return false
            end
        end
    else
        for _, item in ipairs(self) do
            if func(item) == nil then
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

function base:tostring(level)
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

function base:retain_all(collection)
    arg_check_type("base:retain_all", 1, collection, 'table')
    if collection._is_collection and collection._type == 'key' then
        for item, _ in pairs(self._items) do
            if collection:contains(item) == false then
                self._items[item] = nil
                self._size = self._size - 1
            end
        end
    else
        local keep = {}
        local size = 0
        base.iterate(collection, function(item)
            if self._items[item] then
                keep[item] = true
                size = size + 1
            end
            return true
        end)
        self._items = keep
        self._size = size
    end
    return self
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

--[[ Module ]]--

local collection = {base = base}
package.loaded.collection = collection

collection.set = require "collection.set"
collection.list = require "collection.list"

return collection
