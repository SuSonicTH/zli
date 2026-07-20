local lu = require "luaunit"
local fs = require "filesystem"

RUN_ALL = true


local function cleanTestTemp()
    for _, file in ipairs(fs.list("./test/temp")) do
        if file.name ~= ".gitignore" then
            if (file:is_directory()) then
                file:delete_tree();
            else
                file:delete()
            end
        end
    end
end


--delete everything in ./test/temp except .gitignore
cleanTestTemp()
--require all test_*.lua files in ./test/
for fileName in sorted_pairs(fs.dir("./test/")) do
    if fileName:find("test_.*%.lua") then
        require("test/" .. fileName:sub(1, -5))
    end
end

local ret = lu.LuaUnit.run('-v')
cleanTestTemp()
os.exit(ret)
