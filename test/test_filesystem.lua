local lu = require 'luaunit'
lu.ORDER_ACTUAL_EXPECTED = false

local fs = require "filesystem"

Test_filesystem = {}

function Test_filesystem.Test_path_keeps_relative_paths_relative()
    lu.assertEquals("a", fs.path("a").full_path)
    lu.assertEquals("a/b", fs.path("a/b").full_path)
end

function Test_filesystem.Test_path_keeps_absolute_root()
    lu.assertEquals("/a", fs.path("/a").full_path)
    lu.assertEquals("/a/b", fs.path("/a/b").full_path)
end

function Test_filesystem.Test_path_resolves_dot_and_dotdot()
    local cwd = fs.cwd()
    lu.assertEquals(cwd, fs.path(".").full_path)
    lu.assertEquals(cwd .. "/a", fs.path("./a").full_path)
    lu.assertEquals(cwd .. "/b", fs.path("./a/../b").full_path)
    lu.assertEquals(fs.path(cwd):parent().full_path, fs.path("..").full_path)
end

function Test_filesystem.Test_absolute_round_trip()
    local absolute = fs.absolute("src/version")
    lu.assertEquals(absolute, fs.path(absolute).full_path)
    lu.assertTrue(fs.path(absolute):exists())
end

function Test_filesystem.Test_millisecond_times()
    local path = fs.path("src/version")
    local seconds = path:access_time()
    local milliseconds = path:access_time_ms()
    lu.assertNotIsNil(seconds)
    lu.assertNotIsNil(milliseconds)
    lu.assertEquals(seconds, math.floor(milliseconds / 1000))
end

function Test_filesystem.Test_lines()
    local lines = {}
    for _, line in fs.lines("src/version") do
        lines[#lines + 1] = line
    end
    lu.assertEquals(1, #lines)
    lu.assertEquals("0.2.1", lines[1])
end

function Test_filesystem.Test_create_tree_and_delete_tree()
    local path = fs.path("test/temp/a/b/c")
    lu.assertFalse(path:exists())
    fs.create_tree(path)
    lu.assertTrue(path:exists())
    fs.delete_tree(path:parent())
    lu.assertFalse(path:exists())
end

function Test_filesystem.Test_walk_and_tree()
    local count = 0
    fs.walk("src", function() count = count + 1 end)
    lu.assertIsTrue(count > 0)
    lu.assertEquals(count, #fs.tree("src"))
end

function Test_filesystem.Test_parent_and_sibling()
    lu.assertEquals("test/temp", fs.path("test/temp/file"):parent().full_path)
    lu.assertEquals("src/main.zig", fs.path("src/version"):sibling("main.zig").full_path)
end

function Test_filesystem.Test_to_relative()
    lu.assertEquals("temp/", fs.to_relative(fs.path("test/temp"), fs.path("test")))
end

if not RUN_ALL then
    os.exit(lu.LuaUnit.run('-v'))
end
