local argparse = require "argparse"
local aux = require "aux"
aux.extendlibs()

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
elseif (args.sqlite) then
    require("sqlite_cli").execute()
elseif (args.repl) then
    require("repl").execute()
else
    require("repl").execute()
end
