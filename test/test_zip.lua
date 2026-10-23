local lu = require 'luaunit'
lu.ORDER_ACTUAL_EXPECTED = false

local fs = require "filesystem"
local zip = require "zip"
local unzip = require "unzip"

Test_zip = {}

local archive = "./test/temp/test_archive.zip"

local function remove(path)
    if fs.exists(path) then
        if fs.is_directory(path) then
            fs.delete_tree(path)
        else
            fs.delete(path)
        end
    end
end

function Test_zip.Test_create_list_and_read()
    remove(archive)
    remove("./test/temp/unzip_out")
    remove("./test/temp/extracted.txt")
    remove("./test/temp/extracted2.txt")

    local z = zip.create(archive)
    z:add_file("src/version", "version.txt")
    z:add_file("src/main.lua", "sub/main.lua")
    z:close_zip("test comment")

    lu.assertTrue(fs.exists(archive))

    local u = unzip.open(archive)
    local files = u:list()
    lu.assertEquals(2, #files)

    local version_file = u:read_all("version.txt")

    lu.assertEquals(io.read_file("src/version"), version_file)

    local by_name = {}
    for _, file in ipairs(files) do
        by_name[file.full_path] = file
    end

    lu.assertEquals(io.read_file("src/version"), by_name["version.txt"]:read_all())

    local fh = by_name["version.txt"]:open()
    lu.assertEquals(2, fh:seek("set", 2))
    lu.assertEquals(io.read_file("src/version"):sub(3), fh:read("a"))
    fh:close()
    lu.assertTrue(by_name["version.txt"].is_file)
    lu.assertFalse(by_name["version.txt"].is_directory)

    by_name["version.txt"]:extract("./test/temp/extracted.txt")
    lu.assertEquals(io.read_file("src/version"), io.read_file("./test/temp/extracted.txt"))

    u:extract("version.txt", "./test/temp/extracted2.txt")
    lu.assertEquals(io.read_file("src/version"), io.read_file("./test/temp/extracted2.txt"))

    u:close()
end

function Test_zip.Test_empty_archive()
    local empty = "./test/temp/test_empty.zip"
    remove(empty)
    zip.create(empty):close_zip()
    local u = unzip.open(empty)
    lu.assertEquals(0, #u:list())
    u:close()
end

function Test_zip.Test_extract_all()
    local ok, err = unzip.extract(archive, "./test/temp/unzip_out")
    lu.assertIsTrue(ok, tostring(err))
    lu.assertEquals(io.read_file("src/version"), io.read_file("./test/temp/unzip_out/version.txt"))
    lu.assertEquals(io.read_file("src/main.lua"), io.read_file("./test/temp/unzip_out/sub/main.lua"))
end

if not RUN_ALL then
    os.exit(lu.LuaUnit.run('-v'))
end
