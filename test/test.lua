local lu = require 'luaunit'
local fs = require "filesystem"

RUN_ALL = true

for _, file in ipairs(fs.list("./test/")) do
    if file.name:find("test_.*%.lua") then
        require("test/" .. file.name:sub(1, -5))
    end
end

os.exit(lu.LuaUnit.run('-v'))
