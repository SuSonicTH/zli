local argparse = require "argparse"
local zip = require "zip"
local fs = require "filesystem"

local config = os.home .. "/.config"
if not fs.exists(config) then
    fs.mkdir(config)
end

local config_zli = config .. "/zli"
if not fs.exists(config_zli) then
    fs.mkdir(config_zli)
end

local init = config_zli .. "/init.lua"
if not fs.exists(init) then
    io.write_file(init, [==[
--[================================================================================[
    zli init file

    you can put global initialisations here that will get executed on every
    invocation of zli before the programm or script is executed
    it's usefull to set some loacl configurations or load default libraries
--]================================================================================]


]==])
end

dofile(init)

if arg[1] == "@" then
    --single @ without name fowards the arguments without @ to handler below
    table.remove(arg, 1)
else
    local payload = zip.open(arg[0])
    if (payload) then
        --we have a zip attached to the exe
        local script
        if arg[1] and arg[1]:sub(1, 1) == "@" then
            --scriptname given wiht @scriptname
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
            --no scriptname given with @ search for main, init or exename lua scripts in payload
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

local parser = argparse("zli", "Zig Lua Interpreter - A cross platform interpreter with batteries included")
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
    if (args.script == '-') then
        assert(loadfile())()
    else
        assert(loadfile(args.script))()
    end
    return 0;
elseif (args.sqlite) then
    require("sqlite_cli").execute()
elseif (args.repl) then
    require("repl").execute()
else
    require("repl").execute()
end
