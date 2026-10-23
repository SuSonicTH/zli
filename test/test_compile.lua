local lu = require 'luaunit'
lu.ORDER_ACTUAL_EXPECTED = false

local fs = require "filesystem"
local support = require "test/support"

Test_compile = {}

local function new_dir()
    return support.temp_dir("compile")
end

local function compiled_name(name)
    if os.is_windows and not name:ends_with(".exe") then
        return name .. ".exe"
    end
    return name
end

local function make_runnable(name)
    if os.is_mac then
        -- the compile tool only fixes permissions on Linux
        os.execute("chmod 755 " .. support.quote(name))
    end
end

local function run_compile(source)
    local config = support.temp_file("compile_config", source)
    return support.run({ "@compile", config })
end

function Test_compile.Test_builds_runnable_executable()
    local dir = new_dir()
    local scripts = dir .. "/scripts"
    fs.create_tree(scripts)

    local main = scripts .. "/main.lua"
    io.write_file(main, [[
print("hello from compiled")
print("arg=" .. tostring(arg[1]))
print("value=" .. require("helper").value)
]])

    local helper = scripts .. "/helper.lua"
    io.write_file(helper, [[
return { value = 42 }
]])

    local other = scripts .. "/other.lua"
    io.write_file(other, [[
print("other script")
]])

    local output = compiled_name(dir .. "/app")
    local config = string.format([[
return {
    output_name = %q,
    files = {
        { file = %q, name = "main.lua" },
        %q,
        %q,
    },
}
]], output, main, helper, other)

    local stdout, status = run_compile(config)
    lu.assertEquals(0, status, stdout)
    lu.assertTrue(fs.exists(output))
    make_runnable(output)

    stdout, status = support.run({ "world" }, { exe = output })
    lu.assertEquals(0, status, stdout)
    lu.assertStrContains(stdout, "hello from compiled")
    lu.assertStrContains(stdout, "arg=world")
    lu.assertStrContains(stdout, "value=42")

    -- files are packaged under their base name and can be selected with @name
    stdout, status = support.run({ "@other" }, { exe = output })
    lu.assertEquals(0, status, stdout)
    lu.assertStrContains(stdout, "other script")
    lu.assertNotStrContains(stdout, "hello from compiled")
end

function Test_compile.Test_cli_builds_from_config_file()
    local dir = new_dir()
    local main = dir .. "/main.lua"
    io.write_file(main, 'print("cli compiled")\n')

    local output_path = dir .. "/cli-app"
    local config_path = support.temp_file("compile_config", string.format([[
output_name = %q,
files = { %q },
]], output_path, main))

    local stdout, status = support.run({ "@compile", config_path })
    lu.assertEquals(0, status, stdout)

    output_path = compiled_name(output_path)
    lu.assertTrue(fs.exists(output_path))
    make_runnable(output_path)

    local output, run_status = support.run({}, { exe = output_path })
    lu.assertEquals(0, run_status)
    lu.assertStrContains(output, "cli compiled")
end

function Test_compile.Test_cli_requires_config_argument()
    local stdout, status = support.run({ "@compile" })
    lu.assertEquals(1, status)
    lu.assertStrContains(stdout, "missing config argument")
end

function Test_compile.Test_cli_requires_output_name()
    local config = support.temp_file("compile_config", [[
files = { "test/temp/does-not-exist.lua" },
]])

    local stdout, status = support.run({ "@compile", config })
    lu.assertEquals(1, status)
    lu.assertStrContains(stdout, "mising config 'output_name'")
end

function Test_compile.Test_cli_requires_files()
    local dir = new_dir()
    local config = support.temp_file("compile_config", string.format([[
output_name = %q,
]],
        dir .. "/app"))

    local stdout, status = support.run({ "@compile", config })
    lu.assertEquals(1, status)
    lu.assertStrContains(stdout, "mising or empty config 'files'")
end

function Test_compile.Test_cli_reports_invalid_config_source()
    local config = support.temp_file("compile_config", "this is not lua")

    local stdout, status = support.run({ "@compile", config })
    lu.assertEquals(1, status)
    lu.assertStrContains(stdout, "could not parse compile config")
end

function Test_compile.Test_cli_reports_config_that_is_not_a_table()
    local config = support.temp_file("compile_config", "return 5")

    local stdout, status = support.run({ "@compile", config })
    lu.assertEquals(1, status)
    lu.assertStrContains(stdout, "must return a table")
end

function Test_compile.Test_cli_reports_missing_input_file()
    local dir = new_dir()
    local config = support.temp_file("compile_config", string.format([[
output_name = %q,
files = { "test/temp/compile-missing.lua" },
]],
        dir .. "/app"))

    local stdout, status = support.run({ "@compile", config })
    lu.assertEquals(1, status)
    lu.assertStrContains(stdout, "could not find file 'test/temp/compile-missing.lua'")
end

function Test_compile.Test_cli_reports_file_entry_without_file_field()
    local dir = new_dir()
    local config = support.temp_file("compile_config", string.format([[
output_name = %q,
files = { { name = "main.lua" } },
]],
        dir .. "/app"))

    local stdout, status = support.run({ "@compile", config })
    lu.assertEquals(1, status)
    lu.assertStrContains(stdout, "file entry is missing a 'file' field")
end

function Test_compile.Test_cli_reports_config_execution_error()
    local config = support.temp_file("compile_config", 'error("config exploded")')

    local stdout, status = support.run({ "@compile", config })
    lu.assertEquals(1, status)
    lu.assertStrContains(stdout, "could not execute compile config")
    lu.assertStrContains(stdout, "config exploded")
end

if not RUN_ALL then
    os.exit(lu.LuaUnit.run('-v'))
end
