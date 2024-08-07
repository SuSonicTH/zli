local unzip = require "unzip"
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
    it's usefull to set some local configurations or load default libraries
--]================================================================================]


]==])
end

dofile(init)

if arg[1] == "@" then
    --single @ without name fowards the arguments without @ to handler below
    table.remove(arg, 1)
else
    local payload = unzip.open(arg[0])
    if (payload) then
        --we have a zip attached to the exe
        local script
        local files = payload:dir()
        if arg[1] and arg[1]:sub(1, 1) == "@" then
            --scriptname given with @scriptname
            local name = table.remove(arg, 1):sub(2, -1);
            if files[name] then
                script = name
            else
                script = name .. ".lua"
                if not files[script] then
                    print("Error: executable script '" .. name .. "' not found")
                    os.exit(1)
                end
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
                if files[name] then
                    script = name
                    break
                end
            end
            if not script then
                print("Error: no executable script (main.lua, init.lua, " .. exe .. ") found ")
                os.exit(1)
            end
        end
        assert(load(payload:read_all(script), script))()
        os.exit(0)
    end
end

local function print_usage()
    print [[

Usage: zli [-h|--help] [--test <test>] [--repl] [--sqlite] [--compile <config>] [<script>]

Zig Lua Interpreter - A cross platform interpreter with batteries included

Arguments:
    script                script to execute

Options:
    -h, --help            Show this help message and exit.
    --test <test>         run unit tests in file <test>
    --repl                run Read Print Eval Loop.
    --sqlite              run sqlite cli tool
    --compile <config>    create an exectable compile from <config>
]]
end

if arg[1] == '-h' or arg[1] == '--help' then
    print_usage()
elseif arg[1] == '--test' then
    local test = arg[2]
    if not test then
        print_usage()
        print("error missing script argument to test")
        os.exit(1)
    end

    local source = io.read_file(arg[2]) .. [[
        local luaunit = require 'luaunit'
        os.exit(luaunit.LuaUnit.run('--pattern', 'Test'))
    ]]
    assert(load(source, test))()
elseif arg[1] == '--repl' then
    require("repl").execute()
elseif arg[1] == '--sqlite' then
    require("sqlite_cli").execute()
elseif arg[1] == '--compile' then
    local config_name = arg[2]
    if not config_name then
        print_usage()
        print("error missing config argument to compile")
        os.exit(1)
    end
    local config = assert(load("return {" .. io.read_file(config_name) .. "}", config_name))()
    require("compile").execute(config)
else
    local script = arg[1]
    table.remove(arg, 1)
    if not script then
        require("repl").execute()
    elseif (script == '-') then
        assert(loadfile())()
    else
        assert(loadfile(script))()
    end
end
