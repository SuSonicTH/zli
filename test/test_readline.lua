local lu = require 'luaunit'
lu.ORDER_ACTUAL_EXPECTED = false

local fs = require "filesystem"
local support = require "test/support"
local readline = require "readline"

Test_readline = {}

local function temp_history(name)
    local path = support.temp_path(name) .. ".json"
    if fs.exists(path) then
        fs.path(path):delete()
    end
    return path
end

function Test_readline.Test_history_add_deduplicates_and_limits()
    local history = readline.history.new({ max = 3 })
    history:add("one")
    history:add("one")
    history:add("two")
    history:add("")
    history:add("three")
    history:add("four")

    lu.assertEquals(3, history:size())
    local entries = history:entries()
    lu.assertEquals({ "two", "three", "four" }, entries)
end

function Test_readline.Test_history_json_roundtrip()
    local path = temp_history("readline_history")
    local history = readline.history.new()
    history:add("plain")
    history:add("multi\nline")
    lu.assertTrue(history:save(path))

    local loaded = readline.history.new()
    lu.assertTrue(loaded:load(path))
    lu.assertEquals(2, loaded:size())
    lu.assertEquals("multi\nline", loaded:entries()[2])

    -- the file is a JSON array
    local text = io.read_file(path)
    lu.assertStrContains(text, "[")
    lu.assertStrContains(text, "multi\\nline")
end

function Test_readline.Test_history_corrupt_file_is_not_replaced()
    local path = temp_history("readline_corrupt")
    io.write_file(path, "not json")

    local history = readline.history.new()
    history:add("keep")
    local ok, message = history:load(path)
    lu.assertNil(ok)
    lu.assertIsString(message)
    lu.assertEquals(1, history:size())
    lu.assertEquals("not json", io.read_file(path))
end

function Test_readline.Test_history_missing_file_is_ignored()
    local history = readline.history.new()
    history:add("keep")
    lu.assertTrue(history:load(temp_history("readline_missing")))
    lu.assertEquals(1, history:size())
end

function Test_readline.Test_read_falls_back_to_piped_lines()
    local script = support.temp_file("readline_pipe", [[
local readline = require "readline"
local line = readline.read("> ")
print("got:" .. line)
local second = readline.read("> ")
print("second:" .. second)
]])
    local stdout, status = support.run({ script }, {
        home = support.temp_dir("readline_home"),
        stdin = "first line\nsecond line\n",
    })

    lu.assertEquals(0, status, stdout)
    lu.assertStrContains(stdout, "got:first line")
    lu.assertStrContains(stdout, "second:second line")
    lu.assertNotStrContains(stdout, "> ")
end

function Test_readline.Test_piped_multiline_callback()
    local script = support.temp_file("readline_multiline", [[
local readline = require "readline"
local line = readline.read {
    prompt = "> ",
    continuation = ">> ",
    multiline = function(buffer)
        return buffer:find(";", 1, true) ~= nil
    end,
}
print("[" .. line .. "]")
]])
    local stdout, status = support.run({ script }, {
        home = support.temp_dir("readline_home"),
        stdin = "select 1\nfrom t;\n",
    })

    lu.assertEquals(0, status, stdout)
    lu.assertStrContains(stdout, "[select 1\nfrom t;]")
end

function Test_readline.Test_piped_eof_returns_eof()
    local script = support.temp_file("readline_eof", [[
local readline = require "readline"
local line, reason = readline.read("> ")
print(line == nil, reason)
]])
    local stdout, status = support.run({ script }, {
        home = support.temp_dir("readline_home"),
        stdin = "",
    })

    lu.assertEquals(0, status, stdout)
    lu.assertStrContains(stdout, "true\teof")
end

function Test_readline.Test_initial_text_is_prefilled()
    local script = support.temp_file("readline_initial", [[
local readline = require "readline"
print(readline.read { initial = "abc" })
]])
    local stdout, status = support.run({ script }, {
        home = support.temp_dir("readline_home"),
        stdin = "\n",
    })

    lu.assertEquals(0, status, stdout)
    lu.assertStrContains(stdout, "abc")
end

function Test_readline.Test_invalid_options_are_rejected_on_pipes()
    local script = support.temp_file("readline_bad_options", [[
local readline = require "readline"
print(pcall(readline.read, { prompt = 42 }))
print(pcall(readline.read, { multiline = 1 }))
print(pcall(readline.read, { history = { add = function() end } }))
]])
    local stdout, status = support.run({ script }, {
        home = support.temp_dir("readline_home"),
        stdin = "ignored\n",
    })

    lu.assertEquals(0, status, stdout)
    lu.assertStrContains(stdout, "false\t")
end

if not RUN_ALL then
    os.exit(lu.LuaUnit.run('-v'))
end
