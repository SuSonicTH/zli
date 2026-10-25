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

    local entry_lines = {}
    for line in by_name["version.txt"]:lines() do
        entry_lines[#entry_lines + 1] = line
    end
    lu.assertEquals({ io.read_file("src/version") }, entry_lines)
    lu.assertTrue(by_name["version.txt"].is_file)
    lu.assertFalse(by_name["version.txt"].is_directory)

    by_name["version.txt"]:extract("./test/temp/extracted.txt")
    lu.assertEquals(io.read_file("src/version"), io.read_file("./test/temp/extracted.txt"))

    u:extract("version.txt", "./test/temp/extracted2.txt")
    lu.assertEquals(io.read_file("src/version"), io.read_file("./test/temp/extracted2.txt"))

    u:close()
end

function Test_zip.Test_open_existing_archive_for_append()
    local appended = "./test/temp/test_append.zip"
    remove(appended)

    local z = zip.create(appended)
    z:add_file("src/version", "version.txt")
    z:close_zip()

    z = zip.open(appended)
    z:add_file("src/version", "version-copy.txt")
    z:close_zip()

    local u = unzip.open(appended)
    local files = u:list()
    lu.assertEquals(2, #files)
    lu.assertEquals(
        io.read_file("src/version"),
        u:read_all("version-copy.txt"))
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

local function from_hex(text)
    return (text:gsub("%x%x", function(byte)
        return string.char(tonumber(byte, 16))
    end))
end

-- A zip archive produced by a standard zip implementation.  It contains a
-- stored file, a directory entry and a deflated file.
local external_zip =
    "504b0304140000000000c3a3585dd1ef798e0c0000000c0000000900000073746f72652e74787468656c6c6f2073746f72650a" ..
    "504b0304140000000000c3a3585d000000000000000000000000040000006469722f" ..
    "504b0304140000000800c3a3585da8d3a77807000000650000000f0000006469722f6465666c6174652e7478744b4ca43de00200" ..
    "504b01021403140000000000c3a3585dd1ef798e0c0000000c00000009000000000000000000000080010000000073746f72652e747874" ..
    "504b01021403140000000000c3a3585d000000000000000000000000040000000000000000001000fd41330000006469722f" ..
    "504b01021403140000000800c3a3585da8d3a77807000000650000000f00000000000000000000008001550000006469722f6465666c6174652e747874" ..
    "504b05060000000003000300a600000089000000080065787465726e616c"

function Test_zip.Test_reads_externally_created_archive()
    local path = "./test/temp/external.zip"
    remove(path)
    io.write_file(path, from_hex(external_zip))

    local u = assert(unzip.open(path))
    local info = u:info()
    lu.assertEquals(3, info.entries)
    lu.assertEquals("external", info.comment)
    lu.assertEquals("hello store\n", u:read_all("store.txt"))
    lu.assertEquals(string.rep("a", 100) .. "\n", u:read_all("dir/deflate.txt"))

    local entries = u:dir()
    lu.assertTrue(entries["dir/"].is_directory)
    lu.assertTrue(entries["store.txt"].is_file)
    u:close()
end

function Test_zip.Test_create_after_supports_prefixed_files()
    local path = "./test/temp/prefixed.bin"
    local prefix = "executable prefix data"
    remove(path)
    io.write_file(path, prefix)

    local z = zip.create_after(path)
    z:open("inside.txt"):write("payload data"):close()
    z:close_zip("zli")

    local u = assert(unzip.open(path))
    lu.assertEquals(#prefix, u:payload_start())
    lu.assertEquals("payload data", u:read_all("inside.txt"))
    u:close()
end

function Test_zip.Test_crc_mismatch_is_reported()
    local path = "./test/temp/corrupt.zip"
    remove(path)

    local z = zip.create(path)
    z:add_file("src/version", "version.txt", 0)
    z:close_zip()

    -- flip one digit of the embedded version so the content no longer matches
    -- the stored CRC, without depending on the current version string
    local current = io.read_file("./src/version")
    local corrupted = current:gsub("%d", function(digit)
        return tostring((tonumber(digit) + 1) % 10)
    end, 1)
    lu.assertNotEquals(current, corrupted)

    local data = io.read_file(path)
    local start = data:find(current, 1, true)
    lu.assertNotNil(start)
    data = data:sub(1, start - 1) .. corrupted .. data:sub(start + #current)
    io.write_file(path, data)

    local u = assert(unzip.open(path))
    local value, err = u:read_all("version.txt")
    lu.assertNil(value)
    lu.assertStrContains(tostring(err), "Crc")
    u:close()
end

function Test_zip.Test_prefixed_archive_with_relative_offsets()
    local base = "./test/temp/relative_base.zip"
    local relative = "./test/temp/relative_prefix.zip"
    remove(base)
    remove(relative)

    local z = zip.create(base)
    z:open("a.txt"):write("A"):close()
    z:close_zip()

    local prefix = "PREFIX-DATA"
    io.write_file(relative, prefix .. io.read_file(base))

    local u = assert(unzip.open(relative))
    lu.assertEquals(#prefix, u:payload_start())
    lu.assertEquals("A", u:read_all("a.txt"))
    u:close()

    z = zip.open(relative)
    z:open("b.txt"):write("B"):close()
    z:close_zip()

    u = assert(unzip.open(relative))
    lu.assertEquals(#prefix, u:payload_start())
    lu.assertEquals("A", u:read_all("a.txt"))
    lu.assertEquals("B", u:read_all("b.txt"))
    u:close()
end

function Test_zip.Test_trailing_bytes_after_archive()
    local path = "./test/temp/trailing.zip"
    remove(path)

    local z = zip.create(path)
    z:open("a.txt"):write("A"):close()
    z:close_zip()
    io.write_file(path, io.read_file(path) .. "TRAILING JUNK")

    local u = assert(unzip.open(path))
    lu.assertEquals("A", u:read_all("a.txt"))
    u:close()
end

function Test_zip.Test_long_archive_comment_does_not_destroy_archive()
    local path = "./test/temp/long_comment.zip"
    remove(path)

    local z = zip.create(path)
    z:open("a.txt"):write("A"):close()
    local ok, err = z:close_zip(string.rep("x", 70000))
    lu.assertNil(ok)
    lu.assertStrContains(tostring(err), "CommentTooLong")

    z:close_zip("ok")

    local u = assert(unzip.open(path))
    lu.assertEquals("A", u:read_all("a.txt"))
    lu.assertEquals("ok", u:info().comment)
    u:close()
end

function Test_zip.Test_non_utf8_filename_roundtrip()
    local path = "./test/temp/latin1_name.zip"
    remove(path)

    local name = "caf\233.txt"
    local z = zip.create(path)
    z:open(name):write("content"):close()
    z:close_zip()

    local u = assert(unzip.open(path))
    local entries = u:list()
    lu.assertEquals(1, #entries)
    lu.assertEquals(name, entries[1].full_path)
    lu.assertEquals("content", u:read_all(name))
    u:close()
end

function Test_zip.Test_closed_entry_handle_does_not_read_again()
    local path = "./test/temp/closed_handle.zip"
    remove(path)
    local z = zip.create(path)
    z:add_file("src/version", "version.txt")
    z:close_zip()

    local u = assert(unzip.open(path))
    local entry = u:dir()["version.txt"]
    local file = assert(entry:open())
    lu.assertEquals(1, #file:read(1))
    file:close()
    lu.assertFalse(pcall(function() return file:read(1) end))
    u:close()
end

function Test_zip.Test_append_strips_in_cd_digital_signature()
    local path = "./test/temp/digital_signature.zip"
    remove(path)

    local z = zip.create(path)
    z:open("a.txt"):write("A"):close()
    z:open("b.txt"):write("B"):close()
    z:close_zip()

    local data = io.read_file(path)
    local eocd = assert(data:find("PK\5\6", 1, true))
    local cd_size = string.unpack("<I4", data, eocd + 12)
    local signature = "PK\5\5" .. string.pack("<I2", 4) .. "test"
    local before = data:sub(1, eocd - 1) .. signature
    local end_record = data:sub(eocd)
    end_record = end_record:sub(1, 12) ..
        string.pack("<I4", cd_size + #signature) ..
        end_record:sub(17)
    io.write_file(path, before .. end_record)

    local u = assert(unzip.open(path))
    lu.assertEquals(2, u:info().entries)
    lu.assertEquals("A", u:read_all("a.txt"))
    lu.assertEquals("B", u:read_all("b.txt"))
    u:close()

    z = zip.open(path)
    z:open("c.txt"):write("C"):close()
    z:close_zip()

    u = assert(unzip.open(path))
    lu.assertEquals(3, u:info().entries)
    lu.assertEquals("C", u:read_all("c.txt"))
    u:close()
end

function Test_zip.Test_reading_directory_entry_fails()
    local path = "./test/temp/directory_read.zip"
    remove(path)

    local z = zip.create(path)
    z:create_directory("empty")
    z:close_zip()

    local u = assert(unzip.open(path))
    local value, err = u:read_all("empty/")
    lu.assertNil(value)
    lu.assertStrContains(tostring(err), "Directory")
    u:close()
end

if not RUN_ALL then
    os.exit(lu.LuaUnit.run('-v'))
end
