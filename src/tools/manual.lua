local fs = require "filesystem"
local serve = require("serve_lib").serve

local function executable_dir()
    local exe = arg[0] or "zli"
    local dir = exe:match("^(.*)[/\\][^/\\]*$")
    if dir == nil or dir == "" then
        return "."
    end
    return dir
end

local function manual_path()
    -- the manual is part of the source tree, not the binary. Try the current
    -- directory first and then fall back to the directory of the executable.
    local candidates = {
        "doc/lua_55_manual/",
        executable_dir() .. "/doc/lua_55_manual/",
        executable_dir() .. "/../doc/lua_55_manual/",
    }
    for _, path in ipairs(candidates) do
        if fs.exists(path) then
            return path
        end
    end
    return "doc/lua_55_manual/"
end

serve(manual_path())
