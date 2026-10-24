local lu = require 'luaunit'
lu.ORDER_ACTUAL_EXPECTED = false

local fs = require "filesystem"
local markdown = require "markdown"
local support = require "test/support"

Test_markdown = {}

local callback_names = {
    "enter_block",
    "leave_block",
    "enter_span",
    "leave_span",
    "text",
    "debug_log",
}

local function event_text(name, a, b)
    if name == "text" then
        return name .. ":" .. a .. ":" .. b
    elseif name == "debug_log" then
        return name .. ":" .. tostring(a)
    end

    local detail = ""
    if type(b) == "table" then
        if b.level ~= nil then
            detail = "level=" .. b.level
        elseif b.align ~= nil then
            detail = "align=" .. b.align
        elseif b.start ~= nil then
            detail = "start=" .. b.start
        elseif b.href ~= nil then
            detail = "href=" .. b.href
        else
            detail = "table"
        end
    end
    return name .. ":" .. a .. ":" .. detail
end

local function collect_table(text)
    local events = {}
    local callbacks = {}
    for _, name in ipairs(callback_names) do
        callbacks[name] = function(a, b)
            events[#events + 1] = event_text(name, a, b)
        end
    end
    lu.assertTrue(markdown.parse(text, callbacks))
    return events
end

local function collect_single(text)
    local events = {}
    lu.assertTrue(markdown.parse(text, function(name, a, b)
        events[#events + 1] = event_text(name, a, b)
    end))
    return events
end

function Test_markdown.Test_parse_table_and_single_callback_match()
    local text = "# Title\n\nHello **world** and *again*."
    local table_events = collect_table(text)
    local single_events = collect_single(text)

    lu.assertEquals(single_events, table_events)
    lu.assertStrContains(table.concat(table_events, "\n"), "enter_block:h:level=1")
    lu.assertStrContains(table.concat(table_events, "\n"), "enter_span:strong:")
    lu.assertStrContains(table.concat(table_events, "\n"), "text:normal:world")
end

function Test_markdown.Test_single_callback_gets_callback_type()
    local seen = {}
    lu.assertTrue(markdown.parse("# Hi", function(name, ...)
        seen[name] = true
        if name == "enter_block" then
            local kind, detail = ...
            if kind == "h" then
                lu.assertEquals(1, detail.level)
                seen.heading = true
            end
        elseif name == "text" then
            local kind, text = ...
            lu.assertEquals("normal", kind)
            lu.assertEquals("Hi", text)
        end
    end))

    lu.assertTrue(seen.enter_block)
    lu.assertTrue(seen.heading)
    lu.assertTrue(seen.leave_block)
    lu.assertTrue(seen.text)
end

function Test_markdown.Test_table_callback_can_omit_events()
    lu.assertTrue(markdown.parse("# Hi", {}))
    lu.assertTrue(markdown.parse("# Hi", {
        text = function() end,
    }))
end

function Test_markdown.Test_callback_abort_and_errors()
    lu.assertFalse(markdown.parse("# Hi", function()
        return false
    end))

    local ok, err = pcall(function()
        markdown.parse("# Hi", {
            text = function()
                error("callback boom")
            end,
        })
    end)
    lu.assertFalse(ok)
    lu.assertStrContains(tostring(err), "callback boom")

    ok, err = pcall(function()
        markdown.parse("# Hi", function()
            error("single callback boom")
        end)
    end)
    lu.assertFalse(ok)
    lu.assertStrContains(tostring(err), "single callback boom")
end

function Test_markdown.Test_dialect_and_flags()
    local commonmark = markdown.html("~~x~~")
    lu.assertNotStrContains(commonmark, "<del>")

    local github = markdown.html("~~x~~", { dialect = "github" })
    lu.assertStrContains(github, "<del>x</del>")

    local table_html = markdown.html("| a | b |\n| --- | --- |\n| 1 | 2 |", {
        dialect = "github",
    })
    lu.assertStrContains(table_html, "<table>")
    lu.assertStrContains(table_html, "<th>a</th>")

    table_html = markdown.html("| a | b |\n| --- | --- |\n| 1 | 2 |")
    lu.assertNotStrContains(table_html, "<table>")

    local flagged = markdown.html("~~x~~", { flags = { "strikethrough" } })
    lu.assertStrContains(flagged, "<del>x</del>")

    flagged = markdown.html("~~x~~", { flags = { markdown.flags.strikethrough } })
    lu.assertStrContains(flagged, "<del>x</del>")

    local xhtml = markdown.html("a  \nb", { renderer_flags = { markdown.html_flags.xhtml } })
    lu.assertStrContains(xhtml, "<br />")
end

function Test_markdown.Test_html_string_and_callback_match()
    local text = "# Hi\n\nHello **world**.\n"
    local expected = markdown.html(text)

    local chunks = {}
    lu.assertTrue(markdown.html(text, function(chunk)
        chunks[#chunks + 1] = chunk
    end))
    lu.assertEquals(expected, table.concat(chunks))

    local primary = markdown.html("~~x~~", { dialect = "github" })
    chunks = {}
    lu.assertTrue(markdown.html("~~x~~", function(chunk)
        chunks[#chunks + 1] = chunk
    end, { dialect = "github" }))
    lu.assertEquals(primary, table.concat(chunks))
end

function Test_markdown.Test_html_callback_abort_and_errors()
    local chunks = {}
    lu.assertFalse(markdown.html("# Hi", function(chunk)
        chunks[#chunks + 1] = chunk
        return false
    end))

    local ok, err = pcall(function()
        markdown.html("# Hi", function()
            error("output boom")
        end)
    end)
    lu.assertFalse(ok)
    lu.assertStrContains(tostring(err), "output boom")
end

function Test_markdown.Test_parse_file_and_html_file()
    local path = support.temp_file("markdown", "# File Title\n\nBody.\n")

    local seen = {}
    lu.assertTrue(markdown.parse_file(path, {
        enter_block = function(kind, detail)
            if kind == "h" then seen.heading = detail.level end
        end,
        text = function(_, text)
            seen.text = (seen.text or "") .. text
        end,
    }))
    lu.assertEquals(1, seen.heading)
    lu.assertStrContains(seen.text, "File Title")

    local html = markdown.html_file(path)
    lu.assertStrContains(html, "<h1>File Title</h1>")
    lu.assertStrContains(html, "<p>Body.</p>")

    local missing, err = markdown.parse_file(support.temp_path("does_not_exist"), function() end)
    lu.assertNil(missing)
    lu.assertStrContains(tostring(err), "could not read")
end

function Test_markdown.Test_reads_payload_files()
    -- main.lua is a payload entry and does not exist in the repository root.
    lu.assertFalse(fs.exists("main.lua"))
    lu.assertTrue(markdown.parse_file("main.lua", function() end))
    lu.assertNotEquals("", markdown.html_file("main.lua"))
end

function Test_markdown.Test_local_file_has_priority_over_payload()
    if fs.exists("main.lua") then
        return
    end

    io.write_file("main.lua", "# LOCAL\n")
    local ok, html = pcall(function()
        return markdown.html_file("main.lua")
    end)
    fs.delete("main.lua")

    lu.assertTrue(ok, html)
    lu.assertStrContains(html, "LOCAL")
    lu.assertNotStrContains(html, "Usage:")
end

function Test_markdown.Test_invalid_options()
    lu.assertErrorMsgContains("unknown dialect", function()
        markdown.html("x", { dialect = "unknown" })
    end)

    lu.assertErrorMsgContains("unknown flags", function()
        markdown.html("x", { flags = { "unknown" } })
    end)

    lu.assertErrorMsgContains("callback table or function", function()
        markdown.parse("x", 42)
    end)

    lu.assertErrorMsgContains("must be a function", function()
        markdown.parse("x", { text = 42 })
    end)
end

if not RUN_ALL then
    os.exit(lu.LuaUnit.run('-v'))
end
