local lu = require 'luaunit'
local fs = require "filesystem"

RUN_ALL = true

for fileName in sorted_pairs(fs.dir("./test/")) do
    if fileName:find("test_.*%.lua") then
        require("test/" .. fileName:sub(1, -5))
    end
end

os.exit(lu.LuaUnit.run('-v'))
