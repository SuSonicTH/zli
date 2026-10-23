local fs = require("filesystem")

local function archive_path_sub(t, fs_path, tar_path)
    t:add_dir(tar_path)
    for _, file in ipairs(fs.list(fs_path)) do
        local child_fs = fs_path .. "/" .. file.name
        local child_tar = tar_path .. "/" .. file.name
        if file:is_directory() then
            archive_path_sub(t, child_fs, child_tar)
        else
            t:add_file(file, child_tar)
        end
    end
end

local function archive_path(t, fs_path, tar_path)
    fs_path = fs.get_path(fs_path)
    local path = tar_path or fs_path
    path = path:gsub("^%a:", ""):gsub("\\", "/"):gsub("^/+", "")
    archive_path_sub(t, fs_path, path)
end

return function()
    return {
        archive_path = archive_path
    }
end
