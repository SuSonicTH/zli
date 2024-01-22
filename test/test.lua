local fs = require "filesystem"

for _, file in ipairs(fs.list("./test/")) do
    if file.name:find("test_.*%.lua") then
        print("running " .. file.name .. "...")
        assert(load(file:read_all(), file.name))()
    end
end
