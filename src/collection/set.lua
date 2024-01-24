local stream = require "stream"
local collection = require("collection")
local iterate = collection.base.iterate

local set = setmetatable({
    _is_collection = true,
    _type = 'set',
}, {__index = collection.base})

local set_mt

function set:new(init)
    return setmetatable({}, set_mt):clear(init)
end

function set:clear(size)
    self._size = 0
    if type(size) == 'nil' then
        self._items = {}
    elseif type(size) == 'number' then
        self._items = table.create(0, size)
    elseif type(size) == 'table' then
        if type(size.size) == 'function' then
            self._items = table.create(0, size:size())
        else
            self._items = table.create(0, #size)
        end
        self:add_all(size)
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

function set:remove(item)
    if self._items[item] then
        self._size = self._size - 1
        self._items[item] = nil
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

function set:next()
    local key
    return function()
        key = next(self._items, key)
        return key
    end
end

function set:equals(collection)
    arg_check_type("set:equals", 1, collection, 'table')
    local count = 0
    local finished = iterate(collection,
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
