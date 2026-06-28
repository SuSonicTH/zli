local tar
local fs = require("filesystem")

local function archive_path(t, path)
end

return function(tarlib)
    tar = tarlib

    return {
        archive_path = archive_path
    }
end
