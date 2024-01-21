local collection = {}

function collection.iterate(col, func)
    if col._is_collection and col._type == 'key' then
        for item, _ in pairs(collection._items) do
            if func(item) == nil then
                return false
            end
        end
    elseif col._is_collection and col._type == 'index' then
        for _, item in ipairs(collection._items) do
            if func(item) == nil then
                return false
            end
        end
    else
        for _, item in ipairs(col) do
            if func(item) == nil then
                return false
            end
        end
    end
    return true
end

package.loaded.collection = collection

collection.set = require "collection.set"

return collection
