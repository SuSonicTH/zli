local file = arg[1]

if not file then
    print("Error: missing script argument to test")
    os.exit(1)
end

local source = io.read_file(file) .. [[
    local luaunit = require 'luaunit'
    os.exit(luaunit.LuaUnit.run('--pattern', 'Test'))
]]
assert(load(source, file))()
