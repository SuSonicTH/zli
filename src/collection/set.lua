local collection = require("collection")

local set = setmetatable({
    _is_collection = true,
    _type = 'set',
}, { __index = collection.base })

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

function set:iterate()
    local key
    return function()
        key = next(self._items, key)
        return key
    end
end

function set:iterate_indexed()
    local key
    local index = 0
    return function()
        key = next(self._items, key)
        if key then
            index = index + 1
            return index, key
        end
    end
end

function set:iterator(func)
    for item in pairs(self._items) do
        local ret = func(item)
        if ret == false or ret == nil then
            return false
        end
    end
    return true
end

function set:iterator_indexed(func)
    local index = 1
    for item in pairs(self._items) do
        local ret = func(index, item)
        if ret == false or ret == nil then
            return false
        end
        index = index + 1
    end
    return true
end

function set:contains(item)
    return self._items[item] ~= nil
end

function set:retain_all(items)
    arg_check_type("base:retain_all", 1, items, 'table')
    local keep = {}
    local size = 0

    for item in collection.base._iterate(items) do
        if self:contains(item) then
            if keep[item] == nil then
                size = size + 1
                keep[item] = true
            end
        end
    end

    self._size = size
    self._items = keep
    return self
end

function set:for_each(func)
    for item, _ in pairs(self._items) do
        func(item)
    end
    return self
end

set_mt = {
    __index    = set,
    __tostring = set.tostring,
    __len      = set.size,
}

return {
    new = set.new
}
