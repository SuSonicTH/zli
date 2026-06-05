local lu = require "luaunit"
local fs = require "filesystem"

RUN_ALL = true

--delete everything in ./test/temp except .gitignore
for _, file in ipairs(fs.list("./test/temp")) do
    if file.name ~= ".gitignore" then
        file:delete()
    end
end

--require all test_*.lua files in ./test/
for fileName in sorted_pairs(fs.dir("./test/")) do
    print(fileName)
    if fileName:find("test_.*%.lua") then
        require("test/" .. fileName:sub(1, -5))
    end
end

os.exit(lu.LuaUnit.run('-v'))
