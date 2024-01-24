local stream = require "stream"
local collection = require("collection")
local iterate = collection.iterate

local list = setmetatable({
    _is_collection = true,
    _type = 'list',
}, {__index = collection.base})

local list_mt

function list:new(init)
    return setmetatable({}, list_mt):clear(init)
end

function list:clear(size)
    self._size = 0
    if type(size) == 'nil' then
        self._items = {}
    elseif type(size) == 'number' then
        self._items = table.create(size,0)
    elseif type(size) == 'table' then
        if type(size.size) == 'function' then
            self._items = table.create(size:size(),0)
        else
            self._items = table.create(#size,0)
        end
        self:add_all(size)
    else
        arg_error("list:clear", 1, "expecting size or no argument", 2)
    end
    return self
end

--todo: implement add(index,item)
function list:add(item, ...)
    if #{ ... } > 0 then
        arg_error("list:add", 2, "expecting single argument, use list:add_all{} to add mutliple items", 2)
    end
    local index = self._size+1
    self._size = index
    self._items[index] = item
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
