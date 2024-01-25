local collection = require("collection")

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
    local finished = self.iterate(collection,
        function(item)
            return self._items[item]
        end)
    return finished;
end

function set:retain_all(collection)
    arg_check_type("base:retain_all", 1, collection, 'table')
    local keep = {}
    local size = 0

    local lambda = function (item)
        if self:contains(item) then
            if keep[item] == nil then
                size = size + 1
                keep[item] = true
            end
        end
        return true
    end
    
    self.iterate(collection, lambda)

    self._size = size
    self._items = keep
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
