local tar
local fs = require("filesystem")

local function archive_path_sub(t, fs_path, tar_path)
    t:add_dir(tar_path)
    for _, file in ipairs(fs.list(fs_path)) do
        if file:is_directory() then
            t:archive_path(fs_path .. "/" .. file.name, tar_dir)
        else
            t:add_file(file, tar_path .. "/" .. file.name)
        end
    end
end

local function archive_path(t, fs_path, tar_path)
    local path = tar_path or fs_path
    path = path:gsub("^%a:", ""):gsub("\\", "/")
    archive_path_sub(t, fs_path, path)
end

return function(tarlib)
    tar = tarlib

    return {
        archive_path = archive_path
    }
end
