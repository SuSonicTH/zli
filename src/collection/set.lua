local collection = require("collection")

local set = setmetatable({
    _is_collection = true,
    _type = 'set',
}, { __index = collection.base })

local set_mt

function set:new(init)
    return setmetatable({}, set_mt):clear(init)
end

function set:new_ordered(init)
    return setmetatable({ _order = {} }, set_mt):clear(init)
end

function set:clear(size)
    self._size = 0
    local items
    if type(size) == 'nil' then
        self._items = {}
        size = nil
    elseif type(size) == 'number' then
        self._items = table.create(0, size)
    elseif type(size) == 'table' then
        items = size
        if type(size.size) == 'function' then
            size = size:size()
        else
            size = #size
        end
    else
        arg_error("set:clear", 1, "expecting size or no argument", 2)
    end

    if size then
        self._items = table.create(0, size)
        if self._order then self._order = table.create(size, 0) end
    end
    if items then self:add_all(items) end
    return self
end

function set:add(item, ...)
    if #{ ... } > 0 then
        arg_error("set:add", 2, "expecting single argument, use set:add_all{} to add mutliple items", 2)
    end

    if self._items[item] == nil then
        self._size = self._size + 1
        self._items[item] = self._size
        if self._order then self._order[self._size] = item end
    end

    return self
end

function set:remove(item)
    local index = self._items[item]
    if index then
        self._size = self._size - 1
        self._items[item] = nil
        if self._order then table.remove(self._order, index) end
        return true
    end
    return false
end

function set:iterate()
    if self._order then
        local index = 1
        return function()
            local item = self._order[index]
            index = index + 1
            return item
        end
    else
        local key
        return function()
            key = next(self._items, key)
            return key
        end
    end
end

function set:iterate_indexed()
    if self._order then
        return ipairs(self._ordered)
    else
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
end

function set:iterator(func)
    for item in self:iterate() do
        local ret = func(item)
        if ret == false or ret == nil then
            return false
        end
    end
    return true
end

function set:iterator_indexed(func)
    for i, item in self:iterate_indexed() do
        local ret = func(i, item)
        if ret == false or ret == nil then
            return false
        end
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
    for item in self:iterate() do
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
    new = set.new,
    new_ordered = set.new_ordered
}
