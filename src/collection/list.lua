local stream = require "stream"
local collection = require("collection")
local iterate = collection.iterate

local list = {
    _is_collection = true,
    _type = 'list',
}

local list_mt

function list:new(init)
    return collection.new({_size = 0}, list_mt, init)
end

list_mt = {
    __index    = list,
    __tostring = list.tostring,
    __len      = list.size,
}

return {
    new = list.new
}
