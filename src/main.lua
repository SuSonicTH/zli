local version_string = "zli - Zig Lua Interpreter " .. ZLI.version
local fs = require "filesystem"

if os.home == nil or os.home == "" then
    print("Error: could not determine the home directory (HOME is not set)")
    os.exit(1)
end

local config = os.home .. "/.config"
if not fs.exists(config) then
    fs.create_tree(config)
end

local config_zli = config .. "/zli"
if not fs.exists(config_zli) then
    fs.create_tree(config_zli)
end

local init = config_zli .. "/init.lua"
if not fs.exists(init) then
    io.write_file(init, [==[
--[================================================================================[
    zli init file

    you can put global initialisations here that will get executed on every
    invocation of zli before the program or script is executed
    it is useful to set local configuration or load default libraries
--]================================================================================]


]==])
end

package.loaded.filesystem = nil
dofile(init)

if arg[1] == "@" then
    --single @ without name fowards the arguments without @ to handler below
    table.remove(arg, 1)
else
    local unloadUnZip = not package.loaded.unzip
    local unloadFilesystem = not package.loaded.filesystem

    local unzip = require "unzip"
    local payload = unzip.open(ZLI.exe_path or arg[0])

    if unloadUnZip then package.loaded.unzip = nil end
    if unloadFilesystem then package.loaded.filesystem = nil end

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
    print([=[

Usage: zli [-h|--help] [-v|--version] [--test <test>] [--repl] [--sqlite]
           [--compile <config>] [--manual] [--serve [directory]] [<script>]

]=] .. version_string .. [=[

A cross platform lua interpreter with batteries included

Arguments:
    script                script to execute

Options:
    -h, --help            show this help message and exit
    -v, --version         print the version and exit
    --test <test>         run unit tests in file <test>
    --repl                run the interactive Read-Eval-Print Loop
    --sqlite              run the SQLite CLI tool
    --compile <config>    create a standalone executable from <config>
    --manual              serve the Lua manual to be read in a browser
    --serve [directory]   serve a directory over http, defaults to ./
]=])
end

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

local function serve(dir)
    dir = dir or "./"
    local server = require "httpserver"

    print("serving at http://127.0.0.1:8080/")
    print("your browser should automatically open")
    if os.is_windows then
        os.execute("start http://127.0.0.1:8080/")
    elseif os.is_linux then
        os.execute("xdg-open http://127.0.0.1:8080/")
    end

    server.serve {
        web_root = dir,
        cache_web_root = false,
    }
end

if arg[1] == '-h' or arg[1] == '--help' then
    print_usage()
elseif arg[1] == '-v' or arg[1] == '--version' then
    print(version_string)
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
    local source = io.read_file(config_name)
    local chunk, err = load("return {" .. source .. "}", config_name)
    if chunk == nil then
        chunk, err = load(source, config_name)
    end
    if chunk == nil then
        print("Error: could not parse compile config '" .. config_name .. "': " .. tostring(err))
        os.exit(1)
    end
    local ok, config = pcall(chunk)
    if not ok then
        print("Error: could not execute compile config '" .. config_name .. "': " .. tostring(config))
        os.exit(1)
    end
    if type(config) ~= "table" then
        print("Error: compile config '" .. config_name .. "' must return a table")
        os.exit(1)
    end
    require("compile").execute(config)
elseif arg[1] == '--manual' then
    serve(manual_path())
elseif arg[1] == '--serve' then
    serve(arg[2])
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
