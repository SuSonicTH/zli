local fs = require("filesystem")
local zip

local function extract(zipPath, destination)
    zipPath = fs.get_path(zipPath)
    destination = type(destination) == 'table' and destination or fs.path(destination)
    local zfh = zip.open(zipPath)
    for _, file in ipairs(zfh:files()) do
        local destination_path = fs.path(destination, file);
        if (file.is_directory) then
            fs.create_tree(destination_path)
        else
            file:extract(destination_path)
        end
    end
end

return function(lzip)
    zip = lzip
    zip.extract = extract

    return {
        path_to_path_and_name = fs.path_to_path_and_name
    }
end
