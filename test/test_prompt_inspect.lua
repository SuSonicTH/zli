local lu = require 'luaunit'
lu.ORDER_ACTUAL_EXPECTED = false

local config = require "prompt.config"
local filesystem = require "filesystem"
local prompt = require "prompt"
local term = require "term"

local support = require "test/prompt_support"
local process = require "test/support"

Test_prompt_inspect = {}

local function frame_text(frame)
    return support.frame_text(frame)
end

local function all_frames(frames)
    return support.frames_text(frames)
end

local function styled(frames, name)
    for _, frame in ipairs(frames or {}) do
        for _, line in ipairs(frame.lines or {}) do
            for _, span in ipairs(line) do
                if span.style == name then return true end
            end
        end
    end
    return false
end

local function with_size(columns, rows, fn)
    local old = term.size
    term.size = function() return { columns = columns, rows = rows } end
    local packed = table.pack(pcall(fn))
    term.size = old
    if not packed[1] then error(packed[2], 0) end
    return table.unpack(packed, 2, packed.n)
end

local function absolute(path, name)
    return filesystem.absolute(path .. "/" .. name)
end

local table_rows = {
    { name = "web-2", region = "us", cpu = 7 },
    { name = "web-1", region = "eu", cpu = 42 },
}

local function make_table(extra)
    local options = {
        message = "Choose a server",
        columns = {
            { name = "name", title = "Name", width = 8 },
            { name = "region", title = "Region" },
            { name = "cpu", title = "CPU", align = "right" },
        },
        rows = table_rows,
    }
    for key, value in pairs(extra or {}) do options[key] = value end
    return options
end

function Test_prompt_inspect.Test_table_picker_returns_rows()
    local result = support.drive({ support.key("enter") }, function()
        return prompt.table(make_table())
    end)
    lu.assertEquals("web-2", result[1].name)

    result = support.drive({ support.key("down"), support.key("enter") }, function()
        return prompt.table(make_table())
    end)
    lu.assertEquals("web-1", result[1].name)

    result = support.drive({ support.key("down"), support.key("enter") }, function()
        return prompt.table(make_table({ return_index = true }))
    end)
    lu.assertEquals(2, result[1])
end

function Test_prompt_inspect.Test_table_sort_cycles_on_focused_column()
    local result = support.drive({ support.key("enter") }, function()
        return prompt.table(make_table({ sort = "name" }))
    end)
    lu.assertEquals("web-1", result[1].name)

    local frames
    result, frames = support.drive({
        support.char("s"), support.key("home"), support.key("enter"),
    }, function()
        config.configure { symbols = "ascii", color = "never" }
        return prompt.table(make_table())
    end)
    lu.assertEquals("web-1", result[1].name)
    lu.assertStrContains(all_frames(frames), "Name ^")

    result = support.drive({
        support.char("s"), support.char("s"), support.key("home"), support.key("enter"),
    }, function()
        return prompt.table(make_table())
    end)
    lu.assertEquals("web-2", result[1].name)

    result = support.drive({
        support.key("right"), support.key("right"), support.char("s"),
        support.key("home"), support.key("enter"),
    }, function()
        return prompt.table(make_table())
    end)
    lu.assertEquals("web-2", result[1].name)
end

function Test_prompt_inspect.Test_table_sort_orders_mixed_types_deterministically()
    local rows = { { value = "abc" }, { value = 10 }, { value = 2 }, { value = 5 } }
    local result = support.drive({ support.key("enter") }, function()
        return prompt.table {
            message = "Sort",
            columns = { { name = "value", title = "Value" } },
            rows = rows,
            sort = "value",
        }
    end)
    lu.assertEquals(2, result[1].value)
end

function Test_prompt_inspect.Test_table_page_size_counts_data_rows()
    local rows = {}
    for index = 1, 20 do rows[index] = { name = "item" .. index } end
    local _, frames = support.drive({ support.key("esc") }, function()
        return prompt.table {
            message = "Rows",
            columns = { { name = "name", title = "Name" } },
            rows = rows,
            page_size = 5,
            select = false,
        }
    end)
    local count = 0
    for line in frame_text(frames[1]):gmatch("[^\n]+") do
        if line:find("item", 1, true) then count = count + 1 end
    end
    lu.assertEquals(5, count)
end

function Test_prompt_inspect.Test_table_viewer_closes_with_q_and_enter()
    local result = support.drive({ support.char("q") }, function()
        return prompt.table(make_table({ select = false }))
    end)
    lu.assertEquals(true, result[1])

    result = support.drive({ support.key("enter") }, function()
        return prompt.table(make_table({ select = false }))
    end)
    lu.assertEquals(true, result[1])

    result = support.drive({ support.key("esc") }, function()
        return prompt.table(make_table({ select = false }))
    end)
    lu.assertEquals(true, result[1])
end

function Test_prompt_inspect.Test_table_formats_and_aligns_cells()
    local _, frames = support.drive({ support.key("esc") }, function()
        return prompt.table(make_table({
            columns = {
                { name = "name", title = "Name", width = 8 },
                { name = "cpu", title = "CPU", align = "right",
                    format = function(value) return value .. "%" end },
            },
        }))
    end)
    local text = all_frames(frames)
    lu.assertStrContains(text, "42%")
    lu.assertStrContains(text, "  7%")
end

function Test_prompt_inspect.Test_table_horizontal_scrolling_follows_the_column()
    local _, frames = with_size(22, 24, function()
        return support.drive({
            support.key("right"), support.key("right"),
        }, function()
            return prompt.table(make_table())
        end)
    end)
    local text = all_frames(frames)
    lu.assertStrContains(text, "CPU")
    lu.assertNotStrContains(frame_text(frames[1]), "Region")
end

function Test_prompt_inspect.Test_table_picker_cancels_and_reports_empty_rows()
    local result = support.drive({ support.key("esc") }, function()
        return prompt.table(make_table())
    end)
    lu.assertEquals(nil, result[1])
    lu.assertEquals("cancelled", result[2])

    local _, frames = support.drive({ support.key("enter"), support.key("esc") }, function()
        return prompt.table(make_table({ rows = {} }))
    end)
    lu.assertStrContains(all_frames(frames), "no rows")
end

function Test_prompt_inspect.Test_table_form_field()
    local result = support.drive({
        support.key("down"), support.key("enter"), support.key("enter", { control = true }),
    }, function()
        return prompt.form {
            fields = {
                { name = "pick", type = "table", message = "Pick", columns = {
                    { name = "name", title = "Name" },
                }, rows = table_rows },
            },
        }
    end)
    lu.assertEquals("web-1", result[1].pick.name)

    result = support.drive({ support.key("enter") }, function()
        return prompt.form {
            values = { pick = table_rows[2] },
            fields = {
                { name = "pick", type = "table", message = "Pick", columns = {
                    { name = "name", title = "Name" },
                }, rows = table_rows },
            },
        }
    end)
    lu.assertEquals("web-1", result[1].pick.name)
end

function Test_prompt_inspect.Test_keyvalue_orders_and_wraps_values()
    local _, frames = with_size(48, 20, function()
        return support.drive({ support.char("q") }, function()
            config.configure { symbols = "ascii", color = "never" }
            return prompt.keyvalue {
                message = "Details",
                data = {
                    second = "a long value that needs wrapping to fit",
                    first = "one",
                },
                order = { "first", "second" },
            }
        end)
    end)
    local text = all_frames(frames)
    lu.assertStrContains(text, "first:")
    lu.assertStrContains(text, "second:")
    lu.assertStrContains(text, "needs wrapping")
    local first_at = text:find("first:", 1, true)
    local second_at = text:find("second:", 1, true)
    lu.assertTrue(first_at < second_at)
end

function Test_prompt_inspect.Test_keyvalue_format_and_close_keys()
    local result, frames = support.drive({ support.key("enter") }, function()
        return prompt.keyvalue {
            message = "Details",
            data = { cpu = 42 },
            format = function(value, key) return key .. "=" .. tostring(value) end,
        }
    end)
    lu.assertEquals(true, result[1])
    lu.assertStrContains(all_frames(frames), "cpu=42")

    result = support.drive({ support.key("esc") }, function()
        return prompt.keyvalue { message = "Details", data = { a = 1 } }
    end)
    lu.assertEquals(true, result[1])
end

function Test_prompt_inspect.Test_diff_unified_and_split_modes()
    local result, frames = support.drive({ support.char("q") }, function()
        config.configure { symbols = "ascii", color = "never" }
        return prompt.diff {
            message = "Changes",
            old = "alpha\nbeta\ngamma",
            new = "alpha\nBETA\ngamma\ndelta",
            labels = { "before", "after" },
        }
    end)
    lu.assertEquals(true, result[1])
    local text = all_frames(frames)
    lu.assertStrContains(text, "@@")
    lu.assertStrContains(text, "before")
    lu.assertStrContains(text, "after")
    lu.assertTrue(styled(frames, "added"))
    lu.assertTrue(styled(frames, "removed"))

    result, frames = support.drive({ support.char("q") }, function()
        config.configure { symbols = "ascii", color = "never" }
        return prompt.diff {
            message = "Changes",
            old = "alpha\nbeta",
            new = "alpha\nBETA",
            mode = "split",
            labels = { "before", "after" },
        }
    end)
    lu.assertEquals(true, result[1])
    text = all_frames(frames)
    lu.assertStrContains(text, "before")
    lu.assertStrContains(text, "after")
    lu.assertTrue(styled(frames, "added"))
    lu.assertTrue(styled(frames, "removed"))
end

function Test_prompt_inspect.Test_diff_scrolls_and_reports_no_changes()
    local old_lines, new_lines = {}, {}
    for index = 1, 40 do
        old_lines[index] = "line " .. index
        new_lines[index] = index == 20 and "changed" or ("line " .. index)
    end
    local result, frames = with_size(60, 12, function()
        return support.drive({
            support.key("page_down"), support.key("end"), support.key("enter"),
        }, function()
            return prompt.diff {
                message = "Changes",
                old = table.concat(old_lines, "\n"),
                new = table.concat(new_lines, "\n"),
            }
        end)
    end)
    lu.assertEquals(true, result[1])
    lu.assertStrContains(all_frames(frames), "changed")

    result, frames = support.drive({ support.key("enter") }, function()
        return prompt.diff { message = "Changes", old = "same", new = "same" }
    end)
    lu.assertEquals(true, result[1])
    lu.assertStrContains(all_frames(frames), "no changes")
end

function Test_prompt_inspect.Test_plain_viewers()
    local script = process.temp_file("prompt_inspect_plain_viewers", [[
local prompt = require "prompt"
local table_result = prompt.table {
    message = "Servers",
    columns = {
        { name = "name", title = "Name" },
        { name = "cpu", title = "CPU", align = "right" },
    },
    rows = { { name = "web-1", cpu = 42 } },
    select = false,
}
print("table=" .. tostring(table_result))
local keyvalue_result = prompt.keyvalue {
    message = "Details",
    data = { name = "web-1", cpu = 42 },
    order = { "name", "cpu" },
}
print("keyvalue=" .. tostring(keyvalue_result))
local diff_result = prompt.diff {
    message = "Changes",
    old = "a\nb",
    new = "a\nc",
    labels = { "before", "after" },
}
print("diff=" .. tostring(diff_result))
]])
    local stdout, status = process.run({ script }, {
        home = process.temp_dir("prompt_inspect_home"),
        stdin = "",
    })
    lu.assertEquals(0, status, stdout)
    lu.assertStrContains(stdout, "web-1")
    lu.assertStrContains(stdout, "name: web-1")
    lu.assertStrContains(stdout, "--- before")
    lu.assertStrContains(stdout, "+++ after")
    lu.assertStrContains(stdout, "-b")
    lu.assertStrContains(stdout, "+c")
    lu.assertStrContains(stdout, "table=true")
    lu.assertStrContains(stdout, "keyvalue=true")
    lu.assertStrContains(stdout, "diff=true")
end

function Test_prompt_inspect.Test_plain_table_picker_aligns_header_and_rows()
    local script = process.temp_file("prompt_table_alignment", [[
local prompt = require "prompt"
local row = prompt.table {
    message = "Servers",
    columns = { { name = "name", title = "Name" } },
    rows = { { name = "alpha" }, { name = "mike" } },
}
print("row=" .. row.name)
]])
    local stdout, status = process.run({ script }, {
        home = process.temp_dir("prompt_inspect_home"),
        stdin = "2\n",
    })
    lu.assertEquals(0, status, stdout)
    lu.assertStrContains(stdout, "\n     Name")
    lu.assertStrContains(stdout, "\n  1) alpha")
    lu.assertStrContains(stdout, "row=mike")
end

function Test_prompt_inspect.Test_plain_table_picker_eof_without_default()
    local script = process.temp_file("prompt_table_eof", [[
local prompt = require "prompt"
local row, message = prompt.table {
    message = "Servers",
    columns = { { name = "name", title = "Name" } },
    rows = { { name = "alpha" } },
}
print("row=" .. tostring(row))
print("message=" .. tostring(message))
]])
    local stdout, status = process.run({ script }, {
        home = process.temp_dir("prompt_inspect_home"),
        stdin = "",
    })
    lu.assertEquals(0, status, stdout)
    lu.assertStrContains(stdout, "row=nil")
    lu.assertStrContains(stdout, "message=eof")
end

function Test_prompt_inspect.Test_plain_table_picker_eof_uses_default()
    local script = process.temp_file("prompt_table_eof_default", [[
local prompt = require "prompt"
local row, message = prompt.table {
    message = "Servers",
    columns = { { name = "name", title = "Name" } },
    rows = { { name = "alpha" }, { name = "beta" } },
    return_index = true,
    default = 2,
}
print("row=" .. tostring(row))
print("message=" .. tostring(message))
]])
    local stdout, status = process.run({ script }, {
        home = process.temp_dir("prompt_inspect_home"),
        stdin = "",
    })
    lu.assertEquals(0, status, stdout)
    lu.assertStrContains(stdout, "row=2")
    lu.assertStrContains(stdout, "message=nil")
end

function Test_prompt_inspect.Test_plain_table_picker_reads_a_row_number()
    local script = process.temp_file("prompt_table_picker", [[
local prompt = require "prompt"
local row = prompt.table {
    message = "Servers",
    columns = { { name = "name", title = "Name" } },
    rows = { { name = "web-2" }, { name = "web-1" } },
    sort = "name",
}
print("row=" .. row.name)
]])
    local stdout, status = process.run({ script }, {
        home = process.temp_dir("prompt_inspect_home"),
        stdin = "1\n",
    })
    lu.assertEquals(0, status, stdout)
    lu.assertStrContains(stdout, "row=web-1")
end

local function file_fixture(name, files)
    local dir = process.temp_dir(name)
    for _, file in ipairs(files) do
        io.write_file(dir .. "/" .. file, file)
    end
    return dir
end

function Test_prompt_inspect.Test_file_picker_selects_a_file()
    local dir = file_fixture("prompt_file_select", { "alpha.txt", "beta.txt" })
    local result = support.drive({ support.key("enter") }, function()
        return prompt.file {
            message = "Pick a file",
            start = dir,
            absolute = true,
        }
    end)
    lu.assertEquals(absolute(dir, "alpha.txt"), result[1])

    result = support.drive({ support.key("down"), support.key("enter") }, function()
        return prompt.file {
            message = "Pick a file",
            start = dir,
            absolute = true,
        }
    end)
    lu.assertEquals(absolute(dir, "beta.txt"), result[1])

    result = support.drive({ support.key("enter") }, function()
        return prompt.file {
            message = "Pick a file",
            start = dir,
        }
    end)
    lu.assertEquals("alpha.txt", result[1])
end

function Test_prompt_inspect.Test_file_picker_ignores_non_selected_files()
    local dir = process.temp_dir("prompt_file_pick")
    local first = dir .. "/a.lua"
    local second = dir .. "/b.lua"
    io.write_file(first, "a")
    io.write_file(second, "b")
    io.write_file(dir .. "/ignored.txt", "x")
    local result = support.drive({ support.key("enter") }, function()
        return prompt.file {
            message = "Pick",
            start = dir,
            filter = { "*.lua" },
            absolute = true,
        }
    end)
    lu.assertEquals(absolute(dir, "a.lua"), result[1])

    result = support.drive({ support.key("down"), support.key("enter") }, function()
        return prompt.file {
            message = "Pick",
            start = dir,
            filter = "*.lua",
            absolute = true,
        }
    end)
    lu.assertEquals(absolute(dir, "b.lua"), result[1])
end

function Test_prompt_inspect.Test_file_directory_mode_and_navigation()
    local dir = process.temp_dir("prompt_file_directory")
    local inner = dir .. "/inner"
    require("filesystem").create_tree(inner)
    local result = support.drive({ support.key("enter") }, function()
        return prompt.file {
            message = "Pick",
            start = dir,
            mode = "directory",
            absolute = true,
        }
    end)
    lu.assertEquals(absolute(dir, "inner"), result[1])

    -- In file mode a directory is entered rather than selected.  With no
    -- nested file, end of input cancels the picker.
    result = support.drive({ support.key("enter") }, function()
        return prompt.file {
            message = "Pick",
            start = dir,
            absolute = true,
        }
    end)
    lu.assertEquals(nil, result[1])
    lu.assertEquals("eof", result[2])

    -- Right enters a directory, then the file inside it can be selected.
    local nested = inner .. "/nested.txt"
    io.write_file(nested, "nested")
    result = support.drive({
        support.key("right"), support.key("enter"),
    }, function()
        return prompt.file {
            message = "Pick",
            start = dir,
            absolute = true,
        }
    end)
    lu.assertEquals(absolute(inner, "nested.txt"), result[1])
end

function Test_prompt_inspect.Test_file_hidden_toggle_and_filter()
    local dir = process.temp_dir("prompt_file_hidden")
    io.write_file(dir .. "/visible.lua", "v")
    io.write_file(dir .. "/.hidden.lua", "h")
    local _, frames = support.drive({ support.char("h") }, function()
        return prompt.file {
            message = "Pick",
            start = dir,
            filter = "*.lua",
            absolute = true,
        }
    end)
    local text = all_frames(frames)
    lu.assertStrContains(text, "visible.lua")
    lu.assertStrContains(text, ".hidden.lua")
    lu.assertNotStrContains(frame_text(frames[1]), ".hidden.lua")
end

function Test_prompt_inspect.Test_file_multi_select_and_preview()
    local dir = process.temp_dir("prompt_file_multi")
    local first = dir .. "/a.txt"
    local second = dir .. "/b.txt"
    io.write_file(first, "hello preview\nsecond line\n")
    io.write_file(second, "world")
    local result, frames = with_size(100, 24, function()
        return support.drive({
            support.char(" "), support.key("down"), support.char(" "), support.key("enter"),
        }, function()
            return prompt.file {
                message = "Pick files",
                start = dir,
                multi = true,
                absolute = true,
                preview = true,
            }
        end)
    end)
    lu.assertEquals(absolute(dir, "a.txt"), result[1][1])
    lu.assertEquals(absolute(dir, "b.txt"), result[1][2])
    lu.assertStrContains(all_frames(frames), "hello preview")
end

function Test_prompt_inspect.Test_file_binary_and_directory_previews()
    local dir = process.temp_dir("prompt_file_preview")
    local binary = dir .. "/blob.bin"
    io.write_file(binary, "abc\0def")
    local sub = dir .. "/sub"
    filesystem.create_tree(sub)
    io.write_file(sub .. "/child.txt", "child")
    local _, frames = with_size(100, 24, function()
        return support.drive({ support.key("down"), support.key("esc") }, function()
            return prompt.file {
                message = "Pick",
                start = dir,
                mode = "any",
                absolute = true,
            }
        end)
    end)
    local text = all_frames(frames)
    lu.assertStrContains(text, "child.txt")
    lu.assertStrContains(text, "binary file")
end

function Test_prompt_inspect.Test_file_path_entry_and_completion()
    local dir = process.temp_dir("prompt_file_path")
    local file = dir .. "/alpha.lua"
    io.write_file(file, "return 1")
    local result, frames = support.drive({
        support.char("/"), support.char("a"), support.key("tab"), support.key("enter"),
    }, function()
        return prompt.file {
            message = "Pick",
            start = dir,
            filter = "*.lua",
            absolute = true,
        }
    end)
    lu.assertEquals(absolute(dir, "alpha.lua"), result[1])
    lu.assertStrContains(all_frames(frames), "esc back")

    result = support.drive({
        support.char("/"), support.char("m"), support.char("i"), support.char("s"),
        support.char("s"), support.key("enter"), support.key("esc"), support.key("esc"),
    }, function()
        return prompt.file {
            message = "Pick",
            start = dir,
            absolute = true,
        }
    end)
    lu.assertEquals(nil, result[1])
    lu.assertEquals("cancelled", result[2])
    result = support.drive({
        support.char("/"), support.char("c", { control = true }),
    }, function()
        return prompt.file {
            message = "Pick",
            start = dir,
            absolute = true,
        }
    end)
    lu.assertEquals(nil, result[1])
    lu.assertEquals("cancelled", result[2])
end

function Test_prompt_inspect.Test_file_form_field()
    local dir = process.temp_dir("prompt_file_form")
    local file = dir .. "/picked.txt"
    io.write_file(file, "value")
    local result = support.drive({
        support.key("enter"),
    }, function()
        return prompt.form {
            fields = {
                { name = "path", type = "file", message = "Path", start = dir, absolute = true },
            },
        }
    end)
    lu.assertEquals(absolute(dir, "picked.txt"), result[1].path)
end

function Test_prompt_inspect.Test_wizard_file_path_entry_accepts_letters()
    local dir = process.temp_dir("prompt_file_wizard")
    local file = dir .. "/beta.txt"
    io.write_file(file, "value")
    local result = support.drive({
        support.char("/"),
        support.char("b"), support.char("e"), support.char("t"), support.char("a"),
        support.char("."), support.char("t"), support.char("x"), support.char("t"),
        support.key("enter"),
    }, function()
        return prompt.wizard {
            steps = {
                {
                    title = "File",
                    fields = {
                        {
                            name = "path", type = "file", message = "Path",
                            start = dir, absolute = true,
                        },
                    },
                },
            },
        }
    end)
    lu.assertEquals(absolute(dir, "beta.txt"), result[1].path)
end

function Test_prompt_inspect.Test_plain_file_fallback()
    local dir = process.temp_dir("prompt_file_fallback")
    local file = dir .. "/answer.lua"
    io.write_file(file, "return true")
    io.write_file(dir .. "/answer.txt", "text")
    local script = process.temp_file("prompt_file_fallback_script", string.format([[
local prompt = require "prompt"
local value = prompt.file {
    message = "Pick",
    start = %q,
    filter = "*.lua",
    absolute = true,
}
print("value=" .. tostring(value))
]], dir))
    local stdout, status = process.run({ script }, {
        home = process.temp_dir("prompt_inspect_home"),
        stdin = "missing\nanswer.lua\n",
    })
    lu.assertEquals(0, status, stdout)
    lu.assertStrContains(stdout, "Path not found: missing")
    lu.assertStrContains(stdout, "value=" .. filesystem.absolute(file))

    stdout, status = process.run({ script }, {
        home = process.temp_dir("prompt_inspect_home"),
        stdin = "answer.txt\n",
    })
    lu.assertEquals(0, status, stdout)
    lu.assertStrContains(stdout, "File does not match the filter: answer.txt")
end

function Test_prompt_inspect.Test_plain_file_fallback_eof_default()
    local dir = process.temp_dir("prompt_file_fallback_eof")
    local file = dir .. "/answer.lua"
    io.write_file(file, "return true")
    local script = process.temp_file("prompt_file_fallback_eof_script", string.format([[
local prompt = require "prompt"
local value, message = prompt.file {
    message = "Pick",
    start = %q,
    default = %q,
    absolute = true,
}
print("value=" .. tostring(value))
print("message=" .. tostring(message))
]], dir, filesystem.absolute(file)))
    local stdout, status = process.run({ script }, {
        home = process.temp_dir("prompt_inspect_home"),
        stdin = "",
    })
    lu.assertEquals(0, status, stdout)
    lu.assertStrContains(stdout, "value=" .. filesystem.absolute(file))
    lu.assertStrContains(stdout, "message=nil")

    stdout, status = process.run({ script }, {
        home = process.temp_dir("prompt_inspect_home"),
        stdin = "missing.txt\n",
    })
    lu.assertEquals(0, status, stdout)
    lu.assertStrContains(stdout, "Path not found: missing.txt")
    lu.assertStrContains(stdout, "value=" .. filesystem.absolute(file))
end

function Test_prompt_inspect.Test_plain_file_fallback_eof_without_default()
    local dir = process.temp_dir("prompt_file_fallback_eof_none")
    local script = process.temp_file("prompt_file_fallback_eof_none_script", string.format([[
local prompt = require "prompt"
local value, message = prompt.file {
    message = "Pick",
    start = %q,
    absolute = true,
}
print("value=" .. tostring(value))
print("message=" .. tostring(message))
]], dir))
    local stdout, status = process.run({ script }, {
        home = process.temp_dir("prompt_inspect_home"),
        stdin = "",
    })
    lu.assertEquals(0, status, stdout)
    lu.assertStrContains(stdout, "value=nil")
    lu.assertStrContains(stdout, "message=eof")
end

function Test_prompt_inspect.Test_plain_file_fallback_blank_uses_relative_start()
    local dir = process.temp_dir("prompt_file_relative_start")
    local script = process.temp_file("prompt_file_relative_start_script", string.format([[
local prompt = require "prompt"
local value, message = prompt.file {
    message = "Pick",
    start = %q,
    mode = "directory",
    absolute = true,
}
print("value=" .. tostring(value))
print("message=" .. tostring(message))
]], dir))
    local stdout, status = process.run({ script }, {
        home = process.temp_dir("prompt_inspect_home"),
        stdin = "\n",
    })
    lu.assertEquals(0, status, stdout)
    lu.assertStrContains(stdout, "value=" .. filesystem.absolute(dir))
    lu.assertStrContains(stdout, "message=nil")
end

function Test_prompt_inspect.Test_plain_file_fallback_requires_a_path_without_a_valid_blank()
    local dir = process.temp_dir("prompt_file_no_blank")
    local file = dir .. "/picked.txt"
    io.write_file(file, "value")
    local script = process.temp_file("prompt_file_no_blank_script", string.format([[
local prompt = require "prompt"
local value, message = prompt.file {
    message = "Pick",
    start = %q,
    mode = "file",
    absolute = true,
}
print("value=" .. tostring(value))
print("message=" .. tostring(message))
]], dir))
    local stdout, status = process.run({ script }, {
        home = process.temp_dir("prompt_inspect_home"),
        stdin = "\npicked.txt\n",
    })
    lu.assertEquals(0, status, stdout)
    lu.assertStrContains(stdout, "Please enter a path.")
    lu.assertStrContains(stdout, "value=" .. filesystem.absolute(file))
    lu.assertStrContains(stdout, "message=nil")
end

function Test_prompt_inspect.Test_plain_form_restores_file_value()
    local dir = process.temp_dir("prompt_file_form_fallback")
    local file = dir .. "/saved.lua"
    io.write_file(file, "return 1")
    local script = process.temp_file("prompt_file_form_fallback_script", string.format([[
local prompt = require "prompt"
local values = assert(prompt.form {
    values = { path = %q },
    fields = {
        { name = "path", type = "file", message = "Path", start = %q, absolute = true },
    },
})
print("path=" .. tostring(values.path))
]], filesystem.absolute(file), dir))
    local stdout, status = process.run({ script }, {
        home = process.temp_dir("prompt_inspect_home"),
        stdin = "\n",
    })
    lu.assertEquals(0, status, stdout)
    lu.assertStrContains(stdout, "path=" .. filesystem.absolute(file))
end

function Test_prompt_inspect.Test_validation_errors()
    lu.assertError(function() prompt.table { message = "x", columns = {}, rows = {} } end)
    lu.assertError(function()
        prompt.table { message = "x", columns = { { name = "a", align = "middle" } }, rows = {} }
    end)
    lu.assertError(function()
        prompt.keyvalue { message = "x", data = {}, order = "a" }
    end)
    lu.assertError(function()
        prompt.diff { message = "x", old = "a", new = "b", mode = "side" }
    end)
    lu.assertError(function()
        prompt.file { message = "x", start = "test", mode = "link" }
    end)
    lu.assertError(function()
        prompt.file { message = "x", start = "test", filter = 42 }
    end)
end

if not RUN_ALL then
    os.exit(lu.LuaUnit.run('-v'))
end
