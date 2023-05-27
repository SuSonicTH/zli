local argparse = require "argparse"

local parser = argparse("FullMoon", "A cross platform interpreter with batteries included")
parser:argument("script", "script to execute"):args("?")
parser:option("-t --test", "run unit tests")

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
end

if (args.script) then
    assert(loadfile(args.script))()
end
