local collection = require("collection")

local list = setmetatable({
    _is_collection = true,
    _type = 'list',
}, { __index = collection.base })

local list_mt

function list:new(init)
    return setmetatable({}, list_mt):clear(init)
end

function list:clear(size)
    self._size = 0
    if type(size) == 'nil' then
        self._items = {}
    elseif type(size) == 'number' then
        self._items = table.create(size, 0)
    elseif type(size) == 'table' then
        if type(size.size) == 'function' then
            self._items = table.create(size:size(), 0)
        else
            self._items = table.create(#size, 0)
        end
        self:add_all(size)
    else
        arg_error("list:clear", 1, "expecting size or no argument", 2)
    end
    return self
end

function list:add(i, item, ...)
    if #{ ... } > 0 then
        arg_error("list:add", 2,
            "expecting just an item or an index and an item as arguments, use list:add_all{} to add mutliple items", 2)
    end

    if item == nil then
        local index = self._size + 1
        self._size = index
        self._items[index] = i
    else
        arg_check_type("list:add", 2, i, "number")
        table.insert(self._items, i, item)
        self._size = self._size + 1
    end

    return self
end

function list:add_all(i, col)
    if col == nil then
        collection.base.add_all(self, i)
    else
        for item in collection.base._iterate(col) do
            self:add(i, item)
            i = i + 1
        end
    end
    return self
end

function list:iterate()
    local key
    local value
    return function()
        key, value = next(self._items, key)
        return value
    end
end

function list:iterate_indexed()
    return ipairs(self._items)
end

function list:iterator(func)
    for _, item in ipairs(self._items) do
        local ret = func(item)
        if ret == false or ret == nil then
            return false
        end
    end
    return true
end

function list:iterator_indexed(func)
    for i, item in ipairs(self._items) do
        local ret = func(i, item)
        if ret == false or ret == nil then
            return false
        end
    end
    return true
end

function list:remove(item)
    for index, v in ipairs(self._items) do
        if v == item then
            table.remove(self._items, index)
            self._size = self._size - 1
            return true
        end
    end
    return false
end

function list:remove_index(index)
    arg_check_type("list:remove_index", 1, index, "number")
    table.remove(self._items, index)
    self._size = self._size - 1
    return self
end

function list:contains(item)
    for _, v in ipairs(self._items) do
        if v == item then
            return true
        end
    end
    return false
end

function list:get(index)
    arg_check_type("list:get", 1, index, "number")
    return self._items[index]
end

function list:set(index, item)
    arg_check_type("list:get", 1, index, "number")
    local old = self._items[index]
    self._items[index] = item
    return old
end

function list:index_of(item)
    for index, v in ipairs(self._items) do
        if v == item then
            return index
        end
    end
    return 0
end

function list:last_index_of(item)
    local last = 0
    for index, v in ipairs(self._items) do
        if v == item then
            last = index
        end
    end
    return last
end

function list:retain_all(items)
    arg_check_type("base:retain_all", 1, items, 'table')

    if items.__index ~= 'key' then
        items = collection.set:new(items)
    end

    local keep = {}
    local size = 0

    for item in self:iterate() do
        if items:contains(item) then
            size = size + 1
            keep[size] = item
        end
    end

    self._items = keep
    self._size = size
    return self
end

function list:sublist(from, to)
    arg_check_type("list:sublist", 1, from, "number")
    arg_check_type("list:sublist", 2, to, "number")
    local size = to - from + 1
    local new = list:new(size)
    for i = from, to do
        new:add(self._items[i])
    end
    return new
end

function list:for_each(func)
    for _, v in ipairs(self._items) do
        func(v)
    end
    return self
end

function list:for_each_index(func)
    for i, v in ipairs(self._items) do
        func(i, v)
    end
    return self
end

list_mt = {
    __index    = list,
    __tostring = list.tostring,
    __len      = list.size,
}

return {
    new = list.new
}
