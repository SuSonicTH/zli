local lu = require 'luaunit'
lu.ORDER_ACTUAL_EXPECTED = false

local tar = require "tar"
local fs = require "filesystem"

Test_tar = {}

function Test_tar:Test_create_and_read_tar_file_add_file_bytes()
    local tar_name = "./test/temp/test_file.tar"
    local file_name = "hello.txt"
    local file_contents = "Hello tar!"
    tar.create(tar_name)
        :add_file_bytes(file_name, file_contents)
        :close()

    local iter = tar.open(tar_name)
    local file = iter()
    lu.assertEquals(file_name, file.name)
    lu.assertEquals("file", file.type)
    lu.assertEquals(file_contents, file.bytes())
    lu.assertEquals(#file_contents, file.size)
    lu.assertEquals(#file_contents .. " B", file.size_hr)
    lu.assertTrue(file.is_file)
    lu.assertFalse(file.is_directory)
    lu.assertFalse(file.is_link)

    lu.assertIsNil(iter())
end

function Test_tar:Test_create_and_read_tar_file_add_file_bytes_gz_compressed()
    local tar_name = "./test/temp/test_file.tar.gz"
    local file_name = "hello.txt"
    local file_contents = "Hello tar!"
    tar.create(tar_name)
        :add_file_bytes(file_name, file_contents)
        :close()

    local iter = tar.open(tar_name)
    local file = iter()

    lu.assertEquals(file_name, file.name)
    lu.assertEquals("file", file.type)
    lu.assertEquals(file_contents, file.bytes())
    lu.assertEquals(#file_contents, file.size)
    lu.assertEquals(#file_contents .. " B", file.size_hr)
    lu.assertTrue(file.is_file)
    lu.assertFalse(file.is_directory)
    lu.assertFalse(file.is_link)

    lu.assertIsNil(iter())
end

function Test_tar:Test_create_tar_file_add_dir()
    local tar_name = "./test/temp/test_dir.tar"
    tar.create(tar_name)
        :add_dir("test")
        :add_dir("test/hello")
        :close()

    local iter = tar.open(tar_name)
    local file = iter()
    lu.assertEquals("test", file.name)
    lu.assertEquals("directory", file.type)

    lu.assertEquals(0, file.size)
    lu.assertEquals("0 B", file.size_hr)
    lu.assertFalse(file.is_file)
    lu.assertTrue(file.is_directory)
    lu.assertFalse(file.is_link)

    file = iter()
    lu.assertEquals("test/hello", file.name)
    lu.assertEquals("directory", file.type)

    lu.assertIsNil(iter())
end

function Test_tar:Test_create_tar_and_extract()
    local tar_name = "./test/temp/test_extract.tar"
    local contents = "Hello World!"
    local filename = "tar/hello/world.txt";
    tar.create(tar_name)
        :add_dir("tarfile")
        :add_dir("tar/hello")
        :add_file_bytes(filename, contents)
        :close()

    local output = fs.path("test/temp/tar")
    if output:exists() then
        output:delete_tree()
    end
    tar.extract(tar_name, "test/temp")
    lu.assertEquals(contents, io.read_file("test/temp/" .. filename))
end

if not RUN_ALL then
    os.exit(lu.LuaUnit.run('-v'))
end
