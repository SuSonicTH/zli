local fs = require("filesystem")
local unzip

local function extract(zipPath, destination)
    zipPath = fs.get_path(zipPath)
    destination = type(destination) == 'table' and destination or fs.path(destination)

    local zfh = unzip.open(zipPath)
    if not zfh then
        return nil, "could not open zip file '" .. tostring(zipPath) .. "'"
    end

    for _, file in ipairs(zfh:list()) do
        local destination_path = fs.path(destination, file)
        if (file.is_directory) then
            fs.create_tree(destination_path)
        else
            local parent = destination_path:parent()
            if parent ~= nil then
                fs.create_tree(parent)
            end
            file:extract(destination_path)
        end
    end

    return true
end

return function(lunzip)
    unzip = lunzip
    unzip.extract = extract

    return {
        path_to_path_and_name = fs.path_to_path_and_name
    }
end
