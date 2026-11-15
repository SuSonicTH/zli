local lu = require 'luaunit'
lu.ORDER_ACTUAL_EXPECTED = false

local fs = require "filesystem"
local support = require "test/support"

Test_repl = {}

local function new_home()
    return support.temp_dir("repl_home")
end

local function run_repl(input, home)
    return support.run({ "@repl" }, {
        home = home,
        stdin = input,
    })
end

local function has_line(output, expected)
    for line in output:gmatch("[^\n]+") do
        if line:trim() == expected then
            return true
        end
    end
    return false
end

function Test_repl.Test_evaluates_expressions_and_pretty_prints()
    local home = new_home()
    local stdout, status = run_repl([[
print("hello repl")
1 + 2
value = 41
?value
quit
]], home)

    lu.assertEquals(0, status, stdout)
    lu.assertStrContains(stdout, "ZIL - REPL")
    lu.assertStrContains(stdout, "hello repl")
    lu.assertTrue(has_line(stdout, "3"), stdout)
    lu.assertStrContains(stdout, "value = 41")

    -- the repl creates its init file and saves history on exit
    lu.assertTrue(fs.exists(home .. "/.config/zli/repl_init.lua"))
    lu.assertTrue(fs.exists(home .. "/.config/zli/repl_history.json"))
end

function Test_repl.Test_default_init_preloads_all_libraries()
    local home = new_home()
    local stdout, status = run_repl([[
names = {
    "argparse", "benchmark", "collection", "csv", "F", "fs", "grid",
    "gzip", "httpclient", "httpserver", "json", "log", "lpeg", "lu",
    "luastrip", "markdown", "memoize", "pager", "re", "readline", "serpent",
    "sqlite3", "stream", "term",
    "tar", "timer", "unzip", "uuid", "xlsxmlwriter", "xml2lua", "zip",
}
missing = {}
for _, name in ipairs(names) do
    if _G[name] == nil then
        missing[#missing + 1] = name
    end
end
print(#missing == 0 and "all libraries loaded" or table.concat(missing, ","))
quit
]], home)

    lu.assertEquals(0, status, stdout)
    lu.assertStrContains(stdout, "all libraries loaded")
end

function Test_repl.Test_multiline_expressions_and_errors()
    local home = new_home()
    local stdout, status = run_repl([[
function add(a, b)
    return a + b
end
print("add=" .. add(20, 22))
error("boom")
print("still here")
exit
]], home)

    lu.assertEquals(0, status, stdout)
    lu.assertStrContains(stdout, "add=42")
    lu.assertStrContains(stdout, "eval error:")
    lu.assertStrContains(stdout, "boom")
    lu.assertStrContains(stdout, "still here")
end

function Test_repl.Test_compile_error_does_not_end_session()
    local home = new_home()
    local stdout, status = run_repl([[
this is not valid lua
print("recovered")
quit
]], home)

    lu.assertEquals(0, status, stdout)
    lu.assertStrContains(stdout, "compile error:")
    lu.assertStrContains(stdout, "recovered")
end

function Test_repl.Test_end_of_input_exits_cleanly()
    local home = new_home()
    local stdout, status = run_repl('print("before eof")\n', home)

    lu.assertEquals(0, status, stdout)
    lu.assertStrContains(stdout, "before eof")
    lu.assertTrue(fs.exists(home .. "/.config/zli/repl_history.json"))
end

function Test_repl.Test_no_arguments_starts_repl()
    local home = new_home()
    local stdout, status = support.run({}, {
        home = home,
        stdin = "print(\"auto repl\")\nquit\n",
    })

    lu.assertEquals(0, status, stdout)
    lu.assertStrContains(stdout, "ZIL - REPL")
    lu.assertStrContains(stdout, "auto repl")
end

function Test_repl.Test_runs_user_init_file()
    local home = new_home()
    local config = home .. "/.config/zli"
    fs.create_tree(config)
    io.write_file(config .. "/repl_init.lua", "initialized = 42\n")

    local stdout, status = run_repl("?initialized\nquit\n", home)

    lu.assertEquals(0, status, stdout)
    lu.assertStrContains(stdout, "initialized = 42")
end

function Test_repl.Test_help_command()
    local home = new_home()
    local stdout, status = run_repl([[
:help string.byte
:help --search trim
quit
]], home)

    lu.assertEquals(0, status, stdout)
    lu.assertStrContains(stdout, "string.byte")
    lu.assertStrContains(stdout, "string.trim")
end

function Test_repl.Test_help_search_accepts_whitespace()
    local home = new_home()
    local stdout, status = run_repl(":help    --search    trim\nquit\n", home)

    lu.assertEquals(0, status, stdout)
    lu.assertStrContains(stdout, "string.trim")

    stdout, status = run_repl(":help\t--search\ttrim\nquit\n", home)
    lu.assertEquals(0, status, stdout)
    lu.assertStrContains(stdout, "string.trim")
end

function Test_repl.Test_help_search_requires_term()
    local home = new_home()
    local stdout, status = run_repl(":help --search\nquit\n", home)

    lu.assertEquals(0, status, stdout)
    lu.assertStrContains(stdout, "usage: :help --search <term>")
end

function Test_repl.Test_help_output_is_plain_text()
    local home = new_home()
    local stdout, status = run_repl([[
:help --search call func
:help --search trim
quit
]], home)

    lu.assertEquals(0, status, stdout)
    lu.assertStrContains(stdout, "collection.list:for_each")
    lu.assertStrContains(stdout, "Call func for every item.")
    lu.assertStrContains(stdout, "string.trim")
    lu.assertNotStrContains(stdout, "`")
    lu.assertNotStrContains(stdout, "**")
end

function Test_repl.Test_labels_are_not_treated_as_commands()
    local home = new_home()
    local stdout, status = run_repl([[
::again::
print("label ok")
quit
]], home)

    lu.assertEquals(0, status, stdout)
    lu.assertStrContains(stdout, "label ok")
end

function Test_repl.Test_history_is_saved_as_json()
    local home = new_home()
    local stdout, status = run_repl("history_value = 42\nquit\n", home)

    lu.assertEquals(0, status, stdout)
    local text = io.read_file(home .. "/.config/zli/repl_history.json")
    local entries = require("cjson").decode(text)
    lu.assertIsTable(entries)
    local found = false
    for _, entry in ipairs(entries) do
        if entry == "history_value = 42" then
            found = true
        end
    end
    lu.assertTrue(found, text)
end

function Test_repl.Test_legacy_history_is_renamed()
    local home = new_home()
    local config = home .. "/.config/zli"
    fs.create_tree(config)
    io.write_file(config .. "/repl_history", '["old entry"]')

    local stdout, status = run_repl("quit\n", home)

    lu.assertEquals(0, status, stdout)
    lu.assertFalse(fs.exists(config .. "/repl_history"))
    local entries = require("cjson").decode(io.read_file(config .. "/repl_history.json"))
    lu.assertIsTable(entries)
    lu.assertEquals("old entry", entries[1])
end

function Test_repl.Test_corrupt_history_is_backed_up()
    local home = new_home()
    local config = home .. "/.config/zli"
    fs.create_tree(config)
    io.write_file(config .. "/repl_history.json", "not json")

    local stdout, status = run_repl("quit\n", home)

    lu.assertEquals(0, status, stdout)
    lu.assertEquals("not json", io.read_file(config .. "/repl_history.json.bak"))
    local entries = require("cjson").decode(io.read_file(config .. "/repl_history.json"))
    lu.assertIsTable(entries)
end
if not RUN_ALL then
    os.exit(lu.LuaUnit.run('-v'))
end
