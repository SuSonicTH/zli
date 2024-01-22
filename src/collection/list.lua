local stream = require "stream"
local iterate = require("collection").iterate

local list = {
    _is_collection = true,
    _type = 'list',
}

local list_mt

function list:new(init)
    local obj = {
        _size = 0
    }
    setmetatable(obj, list_mt)

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

list_mt = {
    __index    = list,
    __tostring = list.tostring,
    __len      = list.size,
}

return {
    new = list.new
}
