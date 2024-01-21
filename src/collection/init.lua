local function iterate(collection, func)
    if collection._is_collection and collection._type == 'key' then
        for item, _ in pairs(collection._items) do
            if func(item) == nil then
                return false
            end
        end
    elseif collection._is_collection and collection._type == 'index' then
        for _, item in ipairs(collection._items) do
            if func(item) == nil then
                return false
            end
        end
    else
        for _, item in ipairs(collection) do
            if func(item) == nil then
                return false
            end
        end
    end
    return true
end


return {
    iterate = iterate
}
