local fs = require("filesystem")
local zip

local compression_level = {
    store = 0,
    fastest = 1,
    fast = 3,
    normal = 5,
    default = 6,
    high = 7,
    max = 9,
}

local function add_directory_sub(fh, path, base_path, include_top, level)
    local added = 0
    path = fs.ensure_path(path)

    for _, file in ipairs(path:list()) do
        local zip_path = file:to_relative(base_path, include_top)
        if file:is_directory() then
            local added_sub = add_directory_sub(fh, file, base_path, include_top)
            added = added + added_sub
            if added_sub == 0 then
                fh:create_directory(zip_path)
                added = added + 1
            end
        else
            fh:add_file(file, zip_path, level)
            added = added + 1
        end
    end
    return added
end

local function add_directory(fh, path, include_top, level)
    level = level == nil and compression_level.default or level
    return add_directory_sub(fh, path, path, include_top, level)
end

return function(lzip)
    zip = lzip
    zip.level = compression_level
    return {
        add_directory = add_directory
    }
end
