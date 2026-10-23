local version_string = "zli - Zig Lua Interpreter " .. ZLI.version

local function print_usage()
    print([=[

Usage: zli [-h|--help] [-v|--version] [@tool [arguments...]]
       zli [<script> [arguments...]]

]=] .. version_string .. [=[

A cross platform lua interpreter with batteries included

Tools:
    @repl                run the interactive Read-Eval-Print Loop
    @sqlite              run the SQLite CLI tool
    @compile <config>    create a standalone executable from <config>
    @test <test>         run unit tests in file <test>
    @manual              serve the Lua manual in a browser
    @serve [directory]   serve a directory over http, defaults to ./

Without a tool, zli starts the REPL.
]=])
end

if arg[1] == '-h' or arg[1] == '--help' then
    print_usage()
elseif arg[1] == '-v' or arg[1] == '--version' then
    print(version_string)
elseif arg[1] == nil then
    ZLI.dofile("repl.lua")
else
    print_usage()
    print("Error: could not find script '" .. arg[1] .. "'")
    os.exit(1)
end
