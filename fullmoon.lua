local argparse = require "argparse"
local aux = require "aux"
local zip = require "zip"

if arg[1] == "@" then
    table.remove(arg, 1)
else
    local payload = zip.open(arg[0])
    if (payload) then
        local script
        if arg[1] and arg[1]:sub(1, 1) == "@" then
            local name = table.remove(arg, 1):sub(2, -1);
            if payload.files[name] then
                script = name
            else
                name = name .. ".lua"
                if not payload.files[name] then
                    print("Error: executable script '" .. name .. "' not found")
                    os.exit(1)
                end
                script = name
            end
        else
            local exePath = { string.gsub(arg[0], "\\", "/"):split("/") };
            local exe = exePath[#exePath]
            if (exe:lower():sub(-4) == ".exe") then
                exe = exe:sub(1, -5)
            end
            exe = exe .. ".lua"
            for _, name in ipairs { "main.lua", "init.lua", exe } do
                if payload.files[name] then
                    script = name
                    break
                end
            end
            if not script then
                print("Error: no executable script (main.lua, init.lua, " .. exe .. ") found ")
                os.exit(1)
            end
        end
        assert(load(payload.files[script]:get(), script))()
        os.exit(0)
    end
end

local parser = argparse("FullMoon", "A cross platform interpreter with batteries included")
parser:argument("script", "script to execute"):args("?")
parser:option("--test", "run unit tests in file <test>")
parser:option("--repl", "run Read Print Eval Loop."):args("0")
parser:option("--sqlite", "run sqlite cli tool"):args("0")

local args = parser:parse()
if (args.test) then
    local script = io.open(args.test, 'r')
    local source = script:read('a')
    script:close()

    source = source .. [[
        local luaunit = require 'luaunit'
        os.exit(luaunit.LuaUnit.run('--pattern', 'Test'))
    ]]
    assert(load(source, args.test))()
elseif (args.script) then
    assert(loadfile(args.script))()
    return 0;
elseif (args.sqlite) then
    require("sqlite_cli").execute()
elseif (args.repl) then
    require("repl").execute()
else
    require("repl").execute()
end
