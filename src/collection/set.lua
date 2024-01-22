local stream = require "stream"
local iterate = require("collection").iterate

local set = {
    _is_collection = true,
    _type = 'key',
}

local set_mt

function set:new(init)
    local obj = {
        _size = 0
    }
    setmetatable(obj, set_mt)

    local init_type = type(init)
    if init_type == 'number' then
        obj._items = table.create(0, init)
    elseif init_type == 'table' then
        if type(init.size) == 'function' then
            obj._items = table.create(0, init:size())
        else
            obj._items = table.create(0, #init)
        end
        obj:add_all(init)
    else
        obj._items = {}
    end

    return obj
end

function set:tostring(level)
    return table.tostring(self:stream():toarray())
end

function set:size()
    return self._size
end

function set:is_empty()
    return self._size == 0
end

function set:clear(size)
    self._size = 0
    if type(size) == 'nil' then
        self._items = {}
    elseif (type(size) == 'number') then
        self._items = table.create(0, size)
    else
        arg_error("set:clear", 1, "expecting size or no argument", 2)
    end
    return self
end

function set:add(item, ...)
    if #{ ... } > 0 then
        arg_error("set:add", 2, "expecting single argument, use set:add_all{} to add mutliple items", 2)
    end
    if self._items[item] == nil then
        self._size = self._size + 1
    end
    self._items[item] = true
    return self
end

function set:add_all(collection)
    arg_check_type("set:add_all", 1, collection, 'table')
    iterate(collection, function(item) return self:add(item) end)
    return self
end

function set:remove(item)
    if self._items[item] then
        self._size = self._size - 1
        self._items[item] = nil
    end
    return self
end

function set:remove_all(collection)
    arg_check_type("set:remove_all", 1, collection, 'table')
    iterate(collection, function(item) return self:remove(item) end)
    return self
end

function set:retain_all(collection)
    arg_check_type("set:retain_all", 1, collection, 'table')
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
        iterate(collection, function(item)
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

function set:contains(item)
    return self._items[item] ~= nil
end

function set:contains_all(collection)
    arg_check_type("set:contains_all", 1, collection, 'table')
    local finished = iterate(collection,
        function(item)
            return self._items[item]
        end)
    return finished;
end

function set:copy()
    return self:new(self)
end

function set:next()
    local key
    return function()
        key = next(self._items, key)
        return key
    end
end

function set:iterate()
    return self:next()
end

function set:stream()
    return stream(self:next())
end

function set:union(...)
    local ret = new_set(self);
    for _, collection in ipairs { ... } do
        ret:add_all(collection)
    end
    return ret
end

function set:intersection(...)
    local ret = new_set(self);
    for _, collection in ipairs { ... } do
        ret:retain_all(collection)
    end
    return ret
end

function set:difference(...)
    local ret = new_set(self);
    for _, collection in ipairs { ... } do
        ret:remove_all(collection)
    end
    return ret
end

function set:equals(collection)
    arg_check_type("set:equals", 1, collection, 'table')
    local count = 0
    local finished = iterate_collection(collection,
        function(item)
            count = count + 1
            return self._items[item]
        end
    )
    return finished and count == self._size
end

set_mt = {
    __index    = set,
    __tostring = set.tostring,
    __len      = set.size,
}

return {
    new = set.new
}
