local lu = require 'luaunit'
lu.ORDER_ACTUAL_EXPECTED = false

local tar = require "tar"
Test_tar = {}
--[[
function Test_tar:Test_create_tar_file_add_file_bytes()
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

function Test_tar:Test_create_tar_file_add_file_bytes_gz_compressed()
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
--]]

function Test_tar:Test_create_tar_file_add_file_bytes_gz_compressed2()
    local tar_name = "./test/temp/test_file1.tar"
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

    --    lu.assertEquals(0, file.size)
    --    lu.assertEquals("0 B", file.size_hr)
    --    lu.assertFalse(file.is_file)
    --    lu.assertTrue(file.is_directory)
    --    lu.assertFalse(file.is_link)
    --
    --    file = iter()
    --    lu.assertEquals("test/hello", file.name)
    --    lu.assertEquals("directory", file.type)

    lu.assertIsNil(iter())
end

if not RUN_ALL then
    os.exit(lu.LuaUnit.run('-v'))
end
