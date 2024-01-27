local collection = require("collection")

local map = {
    _is_collection = true,
    _type = 'map',
}

local map_mt

function map:new(init)
    return setmetatable({}, map_mt):clear(init)
end

function map:clear(size)
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
        self:put_all(size)
    else
        arg_error("map:clear", 1, "expecting size or no argument", 2)
    end
    return self
end

function map:size()
    return self._size
end

function map:is_empty()
    return self._size == 0
end

function map:tostring(level)
    return table.tostring(self._items)
end

function map:put(key, value)
    local old = self._items[key]
    if old == nil and value ~= nil then
        self._size = self._size + 1
    elseif value == nil then
        self._size = self._size - 1
    end
    self._items[key] = value
    return old
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
    if tbl._is_collection and tbl._type == 'map' then
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
            return true
        else
            return false
        end
    end

    self._size = self._size - 1
    self._items[key] = nil
    return old
end

map_mt = {
    __index    = map,
    __tostring = map.tostring,
    __len      = map.size,
}

return {
    new = map.new
}
