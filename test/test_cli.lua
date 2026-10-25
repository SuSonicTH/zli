local lu = require 'luaunit'
lu.ORDER_ACTUAL_EXPECTED = false

local fs = require "filesystem"
local unzip = require "unzip"
local support = require "test/support"

Test_cli = {}

local function new_home()
    return support.temp_dir("cli_home")
end

local function write_user_init(home)
    local config = home .. "/.config/zli"
    fs.create_tree(config)
    io.write_file(config .. "/init.lua", "FROM_INIT = 42\n")
end

local function compiled_name(name)
    if os.is_windows and not name:ends_with(".exe") then
        return name .. ".exe"
    end
    return name
end

local function build(output_name, files)
    local entries = {}
    for _, entry in ipairs(files) do
        if entry.name then
            entries[#entries + 1] = string.format(
                '{ file = %q, name = %q }', entry.file, entry.name)
        else
            entries[#entries + 1] = string.format('%q', entry.file)
        end
    end

    local source = string.format(
        'return { output_name = %q, files = { %s } }',
        output_name, table.concat(entries, ", "))
    local config = support.temp_file("cli_compile_config", source)

    local stdout, status = support.run({ "@compile", config })
    lu.assertEquals(0, status, stdout)

    local output = compiled_name(output_name)
    if os.is_mac then
        os.execute("chmod 755 " .. support.quote(output))
    end
    return output
end

function Test_cli.Test_runs_filesystem_script_after_init()
    local home = new_home()
    write_user_init(home)

    local script = support.temp_file("cli_script", [[
        print("arg1=" .. tostring(arg[1]))
        print("init=" .. tostring(FROM_INIT))
    ]])

    local stdout, status = support.run({ script, "hello" }, { home = home })
    lu.assertEquals(0, status, stdout)
    lu.assertStrContains(stdout, "arg1=hello")
    lu.assertStrContains(stdout, "init=42")
end

function Test_cli.Test_runs_program_from_stdin_after_init()
    local home = new_home()
    write_user_init(home)

    local stdout, status = support.run({ "-", "world" }, {
        home = home,
        stdin = 'print("stdin=" .. tostring(arg[1]))\nprint("init=" .. tostring(FROM_INIT))\n',
    })

    lu.assertEquals(0, status, stdout)
    lu.assertStrContains(stdout, "stdin=world")
    lu.assertStrContains(stdout, "init=42")
end

function Test_cli.Test_version_and_help_come_from_payload()
    local version = support.run({ "--version" })
    lu.assertStrContains(version, "zli - Zig Lua Interpreter")

    local help = support.run({ "--help" })
    lu.assertStrContains(help, "Usage: zli")
    lu.assertStrContains(help, "@repl")
    lu.assertStrContains(help, "@sqlite")
    lu.assertStrContains(help, "@compile")
    lu.assertStrContains(help, "@test")
    lu.assertStrContains(help, "@manual")
    lu.assertStrContains(help, "@help")
    lu.assertStrContains(help, "@serve")
end

function Test_cli.Test_at_selector_errors()
    local missing_name, name_status = support.run({ "@" })
    lu.assertNotEquals(0, name_status)
    lu.assertStrContains(missing_name, "missing script name")

    local missing_entry, entry_status = support.run({ "@does-not-exist" })
    lu.assertNotEquals(0, entry_status)
    lu.assertStrContains(missing_entry, "not found in payload")
end

function Test_cli.Test_at_selector_supports_exact_names_and_directories()
    local dir = support.temp_dir("cli_at")
    local exact = support.temp_file("cli_at_exact", 'print("exact=" .. tostring(arg[1]))\n')
    local nested = support.temp_file("cli_at_nested", 'print("nested=" .. tostring(arg[1]))\n')

    local output = build(dir .. "/at-app", {
        { file = exact, name = "tool" },
        { file = nested, name = "dir/nested.lua" },
    })

    local stdout, status = support.run({ "@tool", "one" }, { exe = output })
    lu.assertEquals(0, status, stdout)
    lu.assertStrContains(stdout, "exact=one")

    stdout, status = support.run({ "@dir/nested", "two" }, { exe = output })
    lu.assertEquals(0, status, stdout)
    lu.assertStrContains(stdout, "nested=two")
end

function Test_cli.Test_executable_name_selects_script_through_symlink()
    if os.is_windows then
        return
    end

    local dir = support.temp_dir("cli_exe_name")
    local script = support.temp_file("cli_exe_name_script", 'print("tool=" .. tostring(arg[1]))\n')
    local output = build(dir .. "/app", {
        { file = script, name = "tool.lua" },
    })

    local link = dir .. "/tool"
    local target = fs.cwd() .. "/" .. output
    local ok = os.execute("ln -s " .. support.quote(target) .. " " .. support.quote(link))
    lu.assertNotEquals(nil, ok)

    local stdout, status = support.run({ "hello" }, { exe = link })
    lu.assertEquals(0, status, stdout)
    lu.assertStrContains(stdout, "tool=hello")
end

function Test_cli.Test_payload_falls_back_to_main_then_init()
    local dir = support.temp_dir("cli_fallback")
    local main = support.temp_file("cli_fallback_main", 'print("from main")\n')
    local init = support.temp_file("cli_fallback_init", 'print("from init")\n')

    local both = build(dir .. "/both", {
        { file = main, name = "main.lua" },
        { file = init, name = "init.lua" },
    })
    local stdout, status = support.run({}, { exe = both })
    lu.assertEquals(0, status, stdout)
    lu.assertStrContains(stdout, "from main")
    lu.assertNotStrContains(stdout, "from init")

    local init_only = build(dir .. "/init-only", {
        { file = init, name = "init.lua" },
    })
    stdout, status = support.run({}, { exe = init_only })
    lu.assertEquals(0, status, stdout)
    lu.assertStrContains(stdout, "from init")
end

function Test_cli.Test_no_matching_script_prints_usage()
    local dir = support.temp_dir("cli_none")
    local helper = support.temp_file("cli_none_helper", 'return {}\n')
    local output = build(dir .. "/none", {
        { file = helper, name = "helper.lua" },
    })

    local stdout, status = support.run({}, { exe = output })
    lu.assertEquals(1, status, stdout)
    lu.assertStrContains(stdout, "no script found")
    lu.assertStrContains(stdout, "Usage:")
end

function Test_cli.Test_compile_replaces_existing_payload()
    local dir = support.temp_dir("cli_replace")
    local home = new_home()
    write_user_init(home)
    local main = support.temp_file("cli_replace_main", 'print("replacement " .. tostring(FROM_INIT))\n')
    local output = build(dir .. "/replacement", {
        { file = main, name = "main.lua" },
    })

    local payload = assert(unzip.open(output))
    local files = payload:dir()
    payload:close()

    lu.assertNotIsNil(files["main.lua"])
    lu.assertIsNil(files["repl.lua"])
    lu.assertIsNil(files["compile.lua"])
    lu.assertIsNil(files["sqlite.lua"])
    lu.assertIsNil(files["test.lua"])
    lu.assertIsNil(files["serve.lua"])

    local stdout, status = support.run({}, { exe = output, home = home })
    lu.assertEquals(0, status, stdout)
    lu.assertStrContains(stdout, "replacement 42")
end

function Test_cli.Test_local_module_wins_over_payload()
    local dir = support.temp_dir("cli_local")
    local local_dir = support.temp_dir("cli_local_modules")
    io.write_file(local_dir .. "/shadow.lua", 'return "local"\n')

    local payload_module = support.temp_file("cli_payload_module", 'return "payload"\n')
    local main = support.temp_file("cli_local_main", [[
        package.path = arg[1] .. "/?.lua;" .. package.path
        print("shadow=" .. require("shadow"))
    ]])

    local output = build(dir .. "/local", {
        { file = main, name = "main.lua" },
        { file = payload_module, name = "shadow.lua" },
    })

    local stdout, status = support.run({ local_dir }, { exe = output })
    lu.assertEquals(0, status, stdout)
    lu.assertStrContains(stdout, "shadow=local")
end

function Test_cli.Test_io_reads_files_from_payload()
    local dir = support.temp_dir("cli_payload_io")
    local data = support.temp_file("cli_payload_io_data", "payload-data\n")
    local lines = support.temp_file("cli_payload_io_lines", "one\ntwo\n")
    local main = support.temp_file("cli_payload_io_main", [[
        local opened = assert(io.open("./data.txt", "rb"))
        print("open=" .. opened:read("a"))
        opened:close()

        print("read_file=" .. io.read_file("data.txt"))
        print("lines=" .. table.concat(io.read_lines("lines.txt"), "|"))

        local iterated = {}
        for line in io.lines("lines.txt") do
            iterated[#iterated + 1] = line
        end
        print("io_lines=" .. table.concat(iterated, "|"))

        local chunks = {}
        for chunk in io.lines("data.txt", 4) do
            chunks[#chunks + 1] = chunk
        end
        print("io_lines_chunks=" .. table.concat(chunks, "|"))

        local missing, err = io.open("zli-payload-missing.txt")
        print("missing=" .. tostring(missing == nil and err ~= nil))
    ]])
    local output = build(dir .. "/payload-io", {
        { file = main, name = "main.lua" },
        { file = data, name = "data.txt" },
        { file = lines, name = "lines.txt" },
    })

    local stdout, status = support.run({}, { exe = output, home = new_home() })
    lu.assertEquals(0, status, stdout)
    lu.assertStrContains(stdout, "open=payload-data")
    lu.assertStrContains(stdout, "read_file=payload-data")
    lu.assertStrContains(stdout, "lines=one|two")
    lu.assertStrContains(stdout, "io_lines=one|two")
    lu.assertStrContains(stdout, "io_lines_chunks=payl|oad-|data|")
    lu.assertStrContains(stdout, "missing=true")
end

function Test_cli.Test_local_files_shadow_payload_files()
    local dir = support.temp_dir("cli_payload_shadow")
    local payload_data = support.temp_file("cli_payload_shadow_data", "from-payload\n")
    local name = support.temp_path("cli_payload_shadow_target")
    local main = support.temp_file("cli_payload_shadow_main", [[
        print("content=" .. io.read_file(arg[2]))
    ]])
    io.write_file(name, "from-local\n")

    local output = build(dir .. "/payload-shadow", {
        { file = main, name = "main.lua" },
        { file = payload_data, name = name },
    })

    local stdout, status = support.run({ "read", name }, { exe = output, home = new_home() })
    lu.assertEquals(0, status, stdout)
    lu.assertStrContains(stdout, "content=from-local")
end

function Test_cli.Test_help_without_docs_reports_clear_error()
    local dir = support.temp_dir("cli_help_no_docs")
    local output = build(dir .. "/help-only", {
        { file = "src/tools/help.lua", name = "help.lua" },
    })

    local stdout, status = support.run({ "@help" }, {
        exe = output,
        home = new_home(),
    })
    lu.assertNotEquals(0, status, stdout)
    lu.assertStrContains(stdout, "documentation is not available in this payload")
end

function Test_cli.Test_help_without_docs_manual_reports_clear_error()
    local dir = support.temp_dir("cli_help_no_manual")
    local output = build(dir .. "/help-no-manual", {
        { file = "src/tools/help.lua", name = "help.lua" },
        { file = "src/docs.lua", name = "docs.lua" },
        { file = "src/docs_markdown.lua", name = "docs_markdown.lua" },
        { file = "doc/libraries.lua", name = "docs_libraries.lua" },
    })

    local stdout, status = support.run({ "@help" }, {
        exe = output,
        home = new_home(),
    })
    lu.assertNotEquals(0, status, stdout)
    lu.assertStrContains(stdout, "ZLI documentation is not available in this payload")
    lu.assertStrContains(stdout, "missing docs_manual")
end

function Test_cli.Test_manual_output_writes_self_contained_page()
    local output = support.temp_path("cli_manual_output")
    local stdout, status = support.run({ "@manual", "--output", output }, {
        home = new_home(),
    })
    lu.assertEquals(0, status, stdout)
    lu.assertStrContains(stdout, "wrote " .. output)

    local html = fs.read_all(output)
    lu.assertStrContains(html, 'id="zli-search-index"')
    lu.assertStrContains(html, 'id="zli-search-form"')
    lu.assertStrContains(html, "URLSearchParams")
    lu.assertNotStrContains(html, 'action="/search"')
    lu.assertNotStrContains(html, 'href="/#')
end

function Test_cli.Test_manual_rejects_invalid_port()
    for _, value in ipairs({ "0", "-1", "1.5", "65536", "not-a-port" }) do
        local stdout, status = support.run({ "@manual", "--port", value }, {
            home = new_home(),
        })
        lu.assertEquals(2, status, value .. ": " .. stdout)
        lu.assertStrContains(stdout, "--port requires an integer between 1 and 65535")
    end
end

function Test_cli.Test_test_tool_runs_luaunit()
    local test_file = support.temp_file("cli_luaunit", [[
Test_cli_tool = {}

function Test_cli_tool.Test_ok()
    assert(true)
end
]])

    local stdout, status = support.run({ "@test", test_file })
    lu.assertEquals(0, status, stdout)
    lu.assertStrContains(stdout, "1 success")
end

function Test_cli.Test_test_tool_requires_file()
    local stdout, status = support.run({ "@test" })
    lu.assertEquals(1, status, stdout)
    lu.assertStrContains(stdout, "missing script argument to test")
end

if not RUN_ALL then
    os.exit(lu.LuaUnit.run('-v'))
end
