local collection = require("collection")

local map = {
    _is_collection = true,
    _type = 'map',
}

local map_mt

function map:new(init)
    return setmetatable({}, map_mt):clear(init)
end

function map:new_ordered(init)
    return setmetatable({ _order = {} }, map_mt):clear(init)
end

function map:clear(size)
    self._size = 0
    local items
    local init_size
    if type(size) == 'nil' then
        self._items = {}
        self._order_key = {}
    elseif type(size) == 'number' then
        init_size = size
    elseif type(size) == 'table' then
        items = size
        if type(size.size) == 'function' then
            init_size = size:size()
        else
            init_size = #size
        end
    else
        arg_error("set:clear", 1, "expecting size or no argument", 2)
    end

    if init_size then
        self._items = {}
        if self._order then
            self._order = {}
            self._order_key = {}
        end
    end
    if items then self:put_all(items) end
    return self
end

function map:size()
    return self._size
end

function map:is_empty()
    return self._size == 0
end

function map:tostring()
    return table.tostring(self._items)
end

function map:put(key, value)
    if value == nil then
        return self:remove(key)
    end

    local old = self._items[key]
    if old == nil then
        self._size = self._size + 1
        if self._order then
            self._order[self._size] = key
            self._order_key[key] = self._size
        end
    end
    self._items[key] = value
    return old
end

function map:iterate()
    if self._order then
        local index = 1
        return function()
            local key = self._order[index]
            index = index + 1
            return key, self._items[key]
        end
    else
        return pairs(self._items)
    end
end

function map:iterator(func)
    for key, item in self:iterate() do
        local ret = func(key, item)
        if ret == false or ret == nil then
            return false
        end
    end
    return true
end

function map:get(key)
    return self._items[key]
end

function map:get_or_default(key, default)
    local val = self._items[key]
    if val == nil then
        return default
    end
    return val
end

function map:put_all(tbl)
    arg_check_type("map:add", 1, tbl, "table")
    if tbl._is_collection then
        if tbl._type ~= 'map' then
            arg_error("map:put_all", 1, "expecting a key value table or map", 2)
        end
        tbl = tbl._items
    end
    for k, v in pairs(tbl) do
        self:put(k, v)
    end
    return self
end

function map:put_if_absent(key, value)
    local old = self._items[key]
    if old == nil and value ~= nil then
        self._size = self._size + 1
        self._items[key] = value
    else
        return old
    end
end

function map:remove(key, value)
    local old = self._items[key]
    if old == nil then
        return
    end

    if value ~= nil then
        if old == value then
            self._size = self._size - 1
            self._items[key] = nil
            if self._order then
                table.remove(self._order, self._order_key[key])
                self._order_key[key] = nil
            end
            return true
        else
            return false
        end
    end

    self._size = self._size - 1
    self._items[key] = nil
    if self._order then
        table.remove(self._order, self._order_key[key])
        self._order_key[key] = nil
    end
    return old
end

function map:merge(key, value, func)
    local old_value = self._items[key]
    if self._items[key] ~= nil then
        value = func(key, value)
    end
    if old_value ~= value then
        self:put(key, value)
    end
    return value
end

function map:replace(key, value, new)
    local old = self._items[key]

    if old ~= nil then
        if new ~= nil then
            if old == value then
                self:put(key, new)
            end
        else
            self:put(key, value)
        end
    end

    return old
end

function map:contains_key(key)
    return self._items[key] ~= nil
end

function map:contains_value(value)
    for _, v in pairs(self._items) do
        if v == value then
            return true
        end
    end
    return false
end

function map:entry_set()
    local set = collection.set:new()
    for k, v in pairs(self._items) do
        set:add({ key = k, value = v })
    end
    return set
end

function map:key_set()
    local set = collection.set:new()
    for k, _ in pairs(self._items) do
        set:add(k)
    end
    return set
end

function map:values()
    local list = collection.list:new()
    for _, v in pairs(self._items) do
        list:add(v)
    end
    return list
end

function map:equals(other)
    arg_check_type("map:equals", 1, other, "table")
    if other._is_collection then
        if other._type ~= 'map' or self:size() ~= other:size() then
            return false
        end
        other = other._items
    end

    local match = 0
    for k, v in pairs(other) do
        if self._items[k] ~= v then
            return false
        end
        match = match + 1
    end

    return match == self._size
end

function map:compute(key, func)
    local value = func(key, self._items[key])
    self._items[key] = value
    return value
end

function map:compute_if_absent(key, func)
    local value = self._items[key]
    if value == nil then
        value = func(key)
        self._items[key] = value
    end
    return value
end

function map:compute_if_present(key, func)
    local value = self._items[key]
    if value ~= nil then
        value = func(key, value)
        self._items[key] = value
        if value == nil then
            self._size = self._size - 1
        end
    end
    return value
end

function map:for_each(func)
    for k, v in self:iterate() do
        func(k, v)
    end
    return self
end

map_mt = {
    __index    = map,
    __tostring = map.tostring,
    __len      = map.size,
}

return {
    new = map.new,
    new_ordered = map.new_ordered,
}
