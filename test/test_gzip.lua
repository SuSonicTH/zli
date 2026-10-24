local lu = require 'luaunit'
lu.ORDER_ACTUAL_EXPECTED = false

local fs = require "filesystem"
local gzip = require "gzip"

Test_gzip = {}

local function remove(path)
    if fs.exists(path) then
        if fs.is_directory(path) then
            fs.delete_tree(path)
        else
            fs.delete(path)
        end
    end
end

local function from_hex(text)
    return (text:gsub("%x%x", function(byte)
        return string.char(tonumber(byte, 16))
    end))
end

-- A gzip stream produced by a standard gzip implementation.
local external_gzip =
    "1f8b08000000000002ff4bad28492dca4bcc5148afca2ce0020068b067a90e000000"

function Test_gzip.Test_write_and_read_roundtrip()
    local path = "./test/temp/gzip_roundtrip.txt.gz"
    remove(path)

    local writer = assert(gzip.open(path, "w", 9))
    writer:write("hello\n", "world\n", 42)
    writer:close()

    local reader = assert(gzip.open(path))
    lu.assertEquals("hello\nworld\n42", reader:read("a"))
    reader:close()
end

function Test_gzip.Test_read_lines_and_byte_counts()
    local path = "./test/temp/gzip_lines.txt.gz"
    remove(path)

    local writer = assert(gzip.open(path, "w"))
    writer:write("one\ntwo\r\nthree")
    writer:close()

    local reader = assert(gzip.open(path))
    local lines = {}
    for line in reader:lines() do
        lines[#lines + 1] = line
    end
    lu.assertEquals({ "one", "two", "three" }, lines)
    reader:close()

    reader = assert(gzip.open(path))
    lu.assertEquals("one\n", reader:read(4))
    lu.assertEquals(4, reader:seek("set", 4))
    lu.assertEquals("two", reader:read("l"))
    lu.assertEquals(9, reader:seek("cur", 0))
    lu.assertEquals("three", reader:read("l"))
    reader:close()
end

function Test_gzip.Test_compress_and_decompress_helpers()
    local text = string.rep("abcdefghij", 100)
    local packed = assert(gzip.compress(text, "best"))
    lu.assertEquals(text, gzip.decompress(packed))

    local stored = assert(gzip.compress(text, "store"))
    lu.assertEquals(text, gzip.decompress(stored))

    lu.assertTrue(#packed < #stored)
end

function Test_gzip.Test_reads_externally_created_gzip()
    local path = "./test/temp/gzip_external.txt.gz"
    remove(path)
    io.write_file(path, from_hex(external_gzip))

    local reader = assert(gzip.open(path))
    lu.assertEquals("external gzip\n", reader:read("a"))
    reader:close()
end

local function flip_byte(text, index)
    local byte = text:byte(index)
    return text:sub(1, index - 1) .. string.char((byte + 1) % 256) .. text:sub(index + 1)
end

function Test_gzip.Test_rejects_corrupt_trailer()
    local path = "./test/temp/gzip_corrupt.gz"
    remove(path)

    local writer = assert(gzip.open(path, "w"))
    writer:write(string.rep("payload ", 100))
    writer:close()

    local data = io.read_file(path)
    for _, index in ipairs({ #data - 7, #data }) do
        local corrupt = flip_byte(data, index)
        local value, err = gzip.decompress(corrupt)
        lu.assertNil(value)
        lu.assertStrContains(tostring(err), "Gzip")

        local corrupt_path = "./test/temp/gzip_corrupt_member.gz"
        io.write_file(corrupt_path, corrupt)
        local reader = assert(gzip.open(corrupt_path))
        local ok, read_err = pcall(function() return reader:read("a") end)
        lu.assertFalse(ok)
        lu.assertStrContains(tostring(read_err), "Gzip")
        reader:close()
    end
end

function Test_gzip.Test_exact_size_read_verifies_trailer()
    local path = "./test/temp/gzip_exact_read.gz"
    remove(path)

    local text = string.rep("exact", 160)
    local writer = assert(gzip.open(path, "w"))
    writer:write(text)
    writer:close()

    local data = flip_byte(io.read_file(path), #io.read_file(path) - 7)
    io.write_file(path, data)

    local reader = assert(gzip.open(path))
    local ok, err = pcall(function() return reader:read(#text) end)
    lu.assertFalse(ok)
    lu.assertStrContains(tostring(err), "Gzip")
    reader:close()
end

function Test_gzip.Test_closed_reader_does_not_serve_buffered_data()
    local path = "./test/temp/gzip_closed.gz"
    remove(path)

    local writer = assert(gzip.open(path, "w"))
    writer:write(string.rep("x", 10000))
    writer:close()

    local reader = assert(gzip.open(path))
    lu.assertEquals(10, #reader:read(10))
    reader:close()
    lu.assertFalse(pcall(function() return reader:read(10) end))
end

function Test_gzip.Test_seek_reports_actual_position()
    local path = "./test/temp/gzip_seek_end.gz"
    remove(path)

    local writer = assert(gzip.open(path, "w"))
    writer:write("short")
    writer:close()

    local reader = assert(gzip.open(path))
    lu.assertEquals(5, reader:seek("set", 1000))
    lu.assertNil(reader:read(1))
    reader:close()
end

if not RUN_ALL then
    os.exit(lu.LuaUnit.run('-v'))
end
