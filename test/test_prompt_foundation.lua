local lu = require 'luaunit'
lu.ORDER_ACTUAL_EXPECTED = false

local config = require "prompt.config"
local diffengine = require "prompt.diffengine"
local fuzzy = require "prompt.fuzzy"
local items_mod = require "prompt.items"
local list_mod = require "prompt.list"
local live = require "prompt.live"
local render = require "prompt.render"
local scroll = require "prompt.scroll"
local suggest = require "prompt.suggest"
local theme_mod = require "prompt.theme"

local support = require "test/prompt_support"

Test_prompt_foundation = {}

local function plain_lines(lines)
    local result = {}
    for index, line in ipairs(lines) do result[index] = render.plain(line) end
    return result
end

function Test_prompt_foundation.Test_scroll_clamps_and_follows()
    local view = scroll.new { rows = 20, height = 5 }
    lu.assertEquals(1, view.top)
    lu.assertEquals(16, view:max_top())
    local first, last = view:visible()
    lu.assertEquals(1, first)
    lu.assertEquals(5, last)

    view:move(100)
    lu.assertEquals(16, view.top)
    first, last = view:visible()
    lu.assertEquals(16, first)
    lu.assertEquals(20, last)
    lu.assertTrue(view:has_above())
    lu.assertFalse(view:has_below())

    view:home()
    lu.assertEquals(1, view.top)
    view:page(2)
    lu.assertEquals(11, view.top)
    view:last()
    lu.assertEquals(16, view.top)

    view:follow(3)
    lu.assertEquals(3, view.top)
    view:follow(19)
    lu.assertEquals(15, view.top)

    view:set_rows(0)
    lu.assertEquals(1, view.top)
    first, last = view:visible()
    lu.assertEquals(1, first)
    lu.assertEquals(0, last)
end

function Test_prompt_foundation.Test_render_viewport_and_pad()
    local lines = { "a", "b", "c", "d", "e" }
    local visible, top, last = render.viewport(lines, 2, 2)
    lu.assertEquals({ "b", "c" }, visible)
    lu.assertEquals(2, top)
    lu.assertEquals(3, last)

    visible, top, last = render.viewport(lines, 99, 2)
    lu.assertEquals({ "e" }, visible)
    lu.assertEquals(5, top)
    lu.assertEquals(5, last)

    lu.assertEquals("   ab", render.plain(render.pad({ { text = "ab" } }, 5, "right")))
    lu.assertEquals(" ab  ", render.plain(render.pad({ { text = "ab" } }, 5, "center")))
    lu.assertEquals("ab   ", render.plain(render.pad({ { text = "ab" } }, 5)))
end

function Test_prompt_foundation.Test_wrap_spans()
    local lines = render.wrap_spans({ { text = "abcdef" } }, 3)
    lu.assertEquals({ "abc", "def" }, plain_lines(lines))

    lines = render.wrap_spans({ { text = "ab\ncd" } }, 10)
    lu.assertEquals({ "ab", "cd" }, plain_lines(lines))

    lines = render.wrap_spans({ { text = "ab\tc" } }, 9)
    lu.assertEquals({ "ab\tc" }, plain_lines(lines))

    lines = render.wrap_spans({ { text = "a界b" } }, 3)
    lu.assertEquals({ "a界", "b" }, plain_lines(lines))

    lines = render.wrap_spans({ { text = "\27[31mabc\27[0m" } }, 2)
    lu.assertEquals(2, #lines)
    lu.assertEquals(2, require("term").width(render.plain(lines[1])))
    lu.assertEquals(1, require("term").width(render.plain(lines[2])))

    lines = render.wrap_spans({}, 4)
    lu.assertEquals(1, #lines)
    lu.assertEquals({}, lines[1])

    lines = render.wrap_spans({ { text = "ab\tc" } }, 4)
    for _, line in ipairs(lines) do
        lu.assertTrue(require("term").width(render.plain(line)) <= 4)
    end
end

function Test_prompt_foundation.Test_fuzzy_scoring_and_filtering()
    local score, ranges = fuzzy.score("Open File", "of")
    lu.assertNotNil(score)
    lu.assertEquals({ { 1, 1 }, { 6, 6 } }, ranges)
    lu.assertNil(fuzzy.score("abc", "d"))

    local exact = fuzzy.score("src", "src")
    local subsequence = fuzzy.score("src/main.zig", "src")
    lu.assertTrue(exact > subsequence)

    local ranked = fuzzy.filter({ "alphabet", "alpha", "beta" }, "alp")
    lu.assertEquals(2, #ranked)
    lu.assertEquals("alpha", ranked[1].item)
    lu.assertEquals("alphabet", ranked[2].item)

    local spans = fuzzy.highlight("Open", { { 1, 1 } }, "match")
    lu.assertEquals("O", spans[1].text)
    lu.assertEquals("match", spans[1].style)
    lu.assertEquals("pen", spans[2].text)

    local search = fuzzy.filter({ { label = "save", search = "write file" } }, "file")
    lu.assertEquals(1, #search)
    lu.assertEquals({}, search[1].ranges)

    local prefix = suggest.common_prefix(fuzzy.filter({ "alpha" }, "alp"))
    lu.assertEquals("alpha", prefix)
end

function Test_prompt_foundation.Test_suggest_filtering_and_completion()
    local items = suggest.normalize {
        "src/",
        { label = "test/", value = "tests/" },
    }
    lu.assertEquals(2, #items)
    lu.assertEquals("tests/", items[2].value)

    local prefix = suggest.filter(items, "sr", "prefix")
    lu.assertEquals(1, #prefix)
    lu.assertEquals("src/", prefix[1].item.label)
    lu.assertEquals({ { 1, 2 } }, prefix[1].ranges)

    local substring = suggest.filter(items, "es", "substring")
    lu.assertEquals(1, #substring)
    lu.assertEquals("test/", substring[1].item.label)

    local fuz = suggest.filter(items, "tst", "fuzzy")
    lu.assertEquals(1, #fuz)
    lu.assertEquals("test/", fuz[1].item.label)

    lu.assertEquals("src/", suggest.complete(prefix, "sr"))
    lu.assertNil(suggest.complete({}, "sr"))

    local utf8 = {
        { item = { label = "éa" } },
        { item = { label = "éb" } },
    }
    lu.assertEquals("é", suggest.common_prefix(utf8))
    utf8 = {
        { item = { label = "éa" } },
        { item = { label = "èa" } },
    }
    lu.assertEquals("", suggest.common_prefix(utf8))

    local false_items = suggest.normalize { { label = "off", value = false } }
    local false_match = suggest.filter(false_items, "of", "prefix")
    lu.assertEquals(false, suggest.complete(false_match, "of"))
end

function Test_prompt_foundation.Test_diff_engine()
    lu.assertEquals({ "a", "b" }, diffengine.split_lines("a\nb\n"))
    lu.assertEquals({ "a", "b" }, diffengine.split_lines("a\nb"))
    lu.assertEquals({ "" }, diffengine.split_lines("\n"))
    lu.assertEquals({}, diffengine.split_lines(""))

    local ops = diffengine.diff("a\nb\nc\n", "a\nx\nc\n")
    local tags = {}
    for _, op in ipairs(ops) do tags[#tags + 1] = op.tag end
    lu.assertEquals({ "equal", "delete", "insert", "equal" }, tags)
    lu.assertEquals(1, diffengine.stats(ops))

    local hunks = diffengine.hunks(ops, 1)
    lu.assertEquals(1, #hunks)
    lu.assertEquals(1, hunks[1].old_start)
    lu.assertEquals(1, hunks[1].new_start)

    local text = diffengine.unified("a\nb\nc\n", "a\nx\nc\n")
    lu.assertStrContains(text, "--- old")
    lu.assertStrContains(text, "+++ new")
    lu.assertStrContains(text, "@@ -1,3 +1,3 @@")
    lu.assertStrContains(text, "-b")
    lu.assertStrContains(text, "+x")
    lu.assertEquals("", diffengine.unified("same\n", "same\n"))

    local insertion = diffengine.hunks(diffengine.diff("b\n", "a\nb\n"), 0)
    lu.assertEquals(1, #insertion)
    lu.assertEquals(0, insertion[1].old_start)
    lu.assertEquals(1, insertion[1].new_start)
    lu.assertStrContains(diffengine.unified("b\n", "a\nb\n", { context = 0 }), "@@ -0,0 +1,1 @@")

    local deletion = diffengine.hunks(diffengine.diff("a\nb\n", "b\n"), 0)
    lu.assertEquals(1, #deletion)
    lu.assertEquals(1, deletion[1].old_start)
    lu.assertEquals(0, deletion[1].new_start)
end

function Test_prompt_foundation.Test_fuzzy_empty_query_and_no_match()
    local score, ranges = fuzzy.score("abc", "")
    lu.assertEquals(0, score)
    lu.assertEquals({}, ranges)
    lu.assertNil(fuzzy.score("abc", "abcd"))
end

function Test_prompt_foundation.Test_list_selection_and_checks()
    local items = items_mod.normalize {
        "a",
        { label = "b", disabled = true },
        "c",
        "d",
    }
    local list = list_mod.new { items = items }
    lu.assertEquals(1, list.selected)

    list:move(1)
    lu.assertEquals(3, list.selected)
    list:move(1)
    lu.assertEquals(4, list.selected)
    list:move(1)
    lu.assertEquals(1, list.selected)
    list:move(-1)
    lu.assertEquals(4, list.selected)

    list:last()
    lu.assertEquals(4, list.selected)
    list:first()
    lu.assertEquals(1, list.selected)

    list:set_query("c")
    lu.assertEquals(1, #list.visible)
    lu.assertEquals(3, list.selected)
    list:set_query("")
    list:set_selected(3)
    list:toggle()
    lu.assertEquals(1, list:checked_count())
    list:toggle()
    lu.assertEquals(0, list:checked_count())

    list:check_all(true)
    lu.assertEquals(3, list:checked_count())
    list:invert_all(true)
    lu.assertEquals(0, list:checked_count())
    lu.assertEquals({}, list:selected_values())

    list:first()
    list:page(1, 2)
    lu.assertEquals(3, list.selected)
    list:page(1, 2)
    lu.assertEquals(4, list.selected)
    list:page(-1, 2)
    lu.assertEquals(1, list.selected)
end

function Test_prompt_foundation.Test_theme_and_live_block()
    config.reset()
    config.configure { symbols = "ascii", color = "always" }
    local theme = theme_mod.build()
    lu.assertEquals("v", theme.symbol("expanded"))
    lu.assertEquals(">", theme.symbol("collapsed"))
    lu.assertEquals("[-]", theme.symbol("partial"))
    lu.assertNotNil(theme.style("match"))
    config.reset()

    live.capture = {}
    local region = live.new("inline", "Working...")
    region:update_block({ { { text = "one" } }, { { text = "two" } } })
    region:finish("success", "done")
    lu.assertEquals("one\ntwo", live.capture[1].text)
    lu.assertEquals({ "one", "two" }, live.capture[1].lines)
    lu.assertEquals("finish", live.capture[2].kind)
    live.capture = nil
end

function Test_prompt_foundation.Test_field_constructors()
    config.reset()
    local theme = theme_mod.build()

    local text = require("prompt.text").new_field { message = "Name", default = "a" }
    local lines, cursor = text:draw(20, true, theme)
    lu.assertTrue(#lines >= 2)
    lu.assertNotNil(cursor)
    lu.assertEquals("a", text:value())
    local action, value = text:handle(support.char("b"))
    lu.assertEquals("continue", action)
    action, value = text:handle(support.key("enter"))
    lu.assertEquals("submit", action)
    lu.assertEquals("ab", value)
    lu.assertEquals("ab", text:value())
    text:handle(support.char("c"))
    lu.assertEquals("abc", text:value())
    text:set_value("z")
    lu.assertEquals("z", text:value())
    lu.assertEquals(1, #text:draw(20, false, theme))
    text:close()

    local multiline = require("prompt.multiline").new_field { message = "Body", rows = 2 }
    multiline:handle(support.char("a"))
    multiline:handle(support.key("enter", { alt = true }))
    multiline:handle(support.char("b"))
    action, value = multiline:handle(support.key("enter"))
    lu.assertEquals("a\nb", value)
    multiline:close()

    local confirm = require("prompt.confirm").new_field { message = "Sure?" }
    action, value = confirm:handle(support.char("y"))
    lu.assertEquals("submit", action)
    lu.assertEquals(true, value)
    lu.assertEquals(true, confirm:value())
    confirm:set_value(true)
    action, value = confirm:handle(support.char("n"))
    lu.assertEquals("submit", action)
    lu.assertEquals(false, value)
    lu.assertEquals(false, confirm:value())
    lu.assertStrContains(require("prompt.render").plain(confirm:summary(theme)), "no")
    confirm:set_value(false)
    lu.assertEquals(false, confirm:value())
    confirm:close()

    local select = require("prompt.select").new_field({
        message = "Pick",
        items = { "a", "b" },
    }, { multi = false })
    select:handle(support.key("down"))
    action, value = select:handle(support.key("enter"))
    lu.assertEquals("b", value)
    select:set_value("a")
    lu.assertEquals("a", select:value())
    select:close()

    local indexed = require("prompt.select").new_field({
        message = "Pick",
        items = { "a", "b" },
        return_index = true,
    }, { multi = false })
    indexed:set_value(2)
    lu.assertEquals(2, indexed:value())
    indexed:close()

    local multi = require("prompt.select").new_field({
        message = "Pick",
        items = { "a", "b" },
    }, { multi = true })
    multi:handle(support.char(" "))
    multi:handle(support.key("down"))
    multi:handle(support.char(" "))
    action, value = multi:handle(support.key("enter"))
    lu.assertEquals({ "a", "b" }, value)
    multi:set_value({ "b" })
    lu.assertEquals({ "b" }, multi:value())
    multi:set_value({})
    lu.assertEquals({}, multi:value())
    multi:close()

    local date = require("prompt.date").new_field {
        message = "Date", default = "2026-11-15", as = "string",
    }
    date:handle(support.key("right"))
    action, value = date:handle(support.key("enter"))
    lu.assertEquals("2026-11-16", value)
    date:set_value("2027-01-02")
    lu.assertEquals("2027-01-02", date:value())
    date:close()

    local time = require("prompt.time").new_field {
        message = "Time", default = { hour = 10, min = 30 },
    }
    time:handle(support.key("right"))
    time:handle(support.key("up"))
    action, value = time:handle(support.key("enter"))
    lu.assertEquals(31, value.min)
    time:set_value({ hour = 1, min = 2 })
    lu.assertEquals(2, time:value().min)
    time:close()

    local datetime = require("prompt.datetime").new_field {
        message = "When", default = "2026-11-15 10:30", as = "table",
    }
    datetime:handle(support.key("tab"))
    datetime:handle(support.key("right"))
    datetime:handle(support.key("up"))
    action, value = datetime:handle(support.key("enter"))
    lu.assertEquals(31, value.min)
    datetime:set_value("2027-02-03 04:05")
    lu.assertEquals(2027, datetime:value().year)
    datetime:close()

    local password = require("prompt.password").new_field {
        message = "P", confirm = true,
    }
    password:handle(support.char("x"))
    password:handle(support.char("y"))
    action = password:handle(support.key("enter"))
    lu.assertEquals("continue", action)
    password:handle(support.char("x"))
    password:handle(support.char("y"))
    action, value = password:handle(support.key("enter"))
    lu.assertEquals("xy", value)
    password:set_value("secret")
    lu.assertEquals("secret", password:value())
    password:close()
end

function Test_prompt_foundation.Test_field_validation_stays_open()
    config.reset()
    local theme = theme_mod.build()
    local field = require("prompt.text").new_field { message = "Name", required = true }
    local action = field:handle(support.key("enter"))
    lu.assertEquals("continue", action)
    lu.assertNotNil(field.error)
    local lines = field:draw(40, true, theme)
    lu.assertStrContains(support.frame_text({ lines = lines }), "required")
    field:close()
end

function Test_prompt_foundation.Test_external_field_error_is_visible()
    config.reset()
    local theme = theme_mod.build()
    local field = require("prompt.select").new_field {
        message = "Pick",
        items = { "a" },
    }
    field.error = "Choose something else."
    local lines = field:draw(40, true, theme)
    lu.assertStrContains(support.frame_text({ lines = lines }), "Choose something else.")
    field:close()
end

function Test_prompt_foundation.Test_error_is_drawn_before_help()
    config.reset()
    local theme = theme_mod.build()
    local function assert_order(field)
        local lines = field:draw(70, true, theme)
        local error_row, help_row
        for index, line in ipairs(lines) do
            local text = render.plain(line)
            if text:find("Required value", 1, true) then error_row = index end
            if text:find("Esc cancel", 1, true) or text:find("esc cancel", 1, true) then help_row = index end
        end
        lu.assertNotNil(error_row)
        lu.assertNotNil(help_row)
        lu.assertTrue(error_row < help_row)
        field:close()
    end

    local field = require("prompt.multiline").new_field { message = "Body" }
    field.error = "Required value."
    assert_order(field)

    field = require("prompt.select").new_field { message = "Pick", items = { "a" } }
    field.error = "Required value."
    assert_order(field)
end

function Test_prompt_foundation.Test_compact_rows_are_clipped()
    config.reset()
    local theme = theme_mod.build()
    local text = require("prompt.text").new_field { message = "A long label", default = "abcdefghijklmnop" }
    local lines = text:draw(10, false, theme)
    lu.assertTrue(require("term").width(render.plain(lines[1])) <= 10)
    text:close()

    local select = require("prompt.select").new_field {
        message = "Pick", items = { "a very long option label" },
    }
    lines = select:draw(10, false, theme)
    lu.assertTrue(require("term").width(render.plain(lines[1])) <= 10)
    select:close()
end

function Test_prompt_foundation.Test_confirm_recovers_from_missing_default()
    config.reset()
    local field = require("prompt.confirm").new_field { message = "Sure?" }
    local action = field:handle(support.key("enter"))
    lu.assertEquals("continue", action)
    lu.assertNotNil(field.error)
    field:handle(support.key("left"))
    lu.assertNil(field.error)
    action, value = field:handle(support.key("enter"))
    lu.assertEquals("submit", action)
    lu.assertEquals(true, value)
    lu.assertNil(field.error)
    field:close()
end

function Test_prompt_foundation.Test_list_all_disabled_home_end()
    local items = items_mod.normalize {
        { label = "a", disabled = true },
        { label = "b", disabled = true },
    }
    local list = list_mod.new { items = items }
    list:first()
    lu.assertEquals(1, list.selected)
    list:last()
    lu.assertEquals(1, list.selected)
end

function Test_prompt_foundation.Test_fuzzy_result_completion()
    local matches = fuzzy.filter({ "alpha" }, "alp")
    lu.assertEquals("alpha", suggest.complete(matches, "alp"))
end

function Test_prompt_foundation.Test_drive_restores_globals_on_error()
    local input = require "prompt.input"
    local ok = pcall(function()
        support.drive({}, function() error("boom") end)
    end)
    lu.assertFalse(ok)
    lu.assertNil(input.events)
    lu.assertNil(render.capture)
    lu.assertNil(config.get("force_interactive"))
end

function Test_prompt_foundation.Test_field_custom_format_round_trip()
    config.reset()
    local theme = theme_mod.build()
    local date = require("prompt.date").new_field {
        message = "Date", default = "2026-11-15", as = "string", format = "%d/%m/%Y",
    }
    local value = date:value()
    lu.assertEquals("15/11/2026", value)
    date:set_value(value)
    lu.assertEquals(value, date:value())
    local lines = date:draw(40, true, theme)
    lu.assertStrContains(support.frame_text({ lines = lines }), "November 2026")
    date:set_value("01/02/2027")
    lu.assertEquals("01/02/2027", date:value())
    lines = date:draw(40, true, theme)
    lu.assertStrContains(support.frame_text({ lines = lines }), "February 2027")
    date:close()

    local named = require("prompt.date").new_field {
        message = "Date", default = "2026-11-15", as = "string", format = "%b%d",
    }
    value = named:value()
    named:set_value(value)
    lu.assertEquals(value, named:value())
    named:close()

    local time = require("prompt.time").new_field {
        message = "Time", default = { hour = 10, min = 30 }, as = "string", format = "%H.%M",
    }
    value = time:value()
    lu.assertEquals("10.30", value)
    time:set_value(value)
    lu.assertEquals(value, time:value())
    lines = time:draw(40, true, theme)
    lu.assertStrContains(support.frame_text({ lines = lines }), "10 : 30")
    time:close()

    local datetime = require("prompt.datetime").new_field {
        message = "When", default = "2026-11-15 10:30", as = "string", format = "%d/%m/%Y %H:%M",
    }
    value = datetime:value()
    lu.assertEquals("15/11/2026 10:30", value)
    datetime:set_value(value)
    lu.assertEquals(value, datetime:value())
    lines = datetime:draw(40, true, theme)
    lu.assertStrContains(support.frame_text({ lines = lines }), "November 2026")
    lu.assertStrContains(support.frame_text({ lines = lines }), "10 : 30")
    datetime:close()

    local named = require("prompt.datetime").new_field {
        message = "When", default = "2026-11-15 10:30", as = "string", format = "%b%d %H:%M",
    }
    value = named:value()
    named:set_value(value)
    lu.assertEquals(value, named:value())
    named:close()
end

function Test_prompt_foundation.Test_dates_parse_format()
    local dates = require "prompt.dates"

    local parsed = dates.parse_format("100% 2027-02-01", "100%% %F")
    lu.assertNotNil(parsed)
    lu.assertEquals(2027, parsed.year)
    lu.assertEquals(2, parsed.month)
    lu.assertEquals(1, parsed.day)

    parsed = dates.parse_format("100%F", "100%%F")
    lu.assertNotNil(parsed)
    lu.assertEquals(nil, parsed.year)

    lu.assertNil(dates.parse_format("13:30 PM", "%I:%M %p"))
    lu.assertNil(dates.parse_format("00:30 PM", "%I:%M %p"))
    lu.assertNil(dates.parse_format("12:00 XX", "%I:%M %p"))
    parsed = dates.parse_format("12:00 AM", "%I:%M %p")
    lu.assertEquals(0, parsed.hour)
    parsed = dates.parse_format("12:00 PM", "%I:%M %p")
    lu.assertEquals(12, parsed.hour)
    parsed = dates.parse_format("03:30 PM", "%I:%M %p")
    lu.assertEquals(15, parsed.hour)

    local stamp = os.time { year = 2026, month = 11, day = 15, hour = 12 }
    local long_name = os.date("%B", stamp)
    parsed = dates.parse_format("15 " .. long_name .. " 2026", "%d %B %Y")
    lu.assertNotNil(parsed)
    lu.assertEquals(11, parsed.month)
    local short_name = os.date("%b", stamp)
    parsed = dates.parse_format("15 " .. short_name .. " 2026", "%d %b %Y")
    lu.assertNotNil(parsed)
    lu.assertEquals(11, parsed.month)
    lu.assertNil(dates.parse_format("15 Foo 2026", "%d %b %Y"))

    parsed = dates.parse_format("Jan15", "%b%d")
    lu.assertNotNil(parsed)
    lu.assertEquals(1, parsed.month)
    lu.assertEquals(15, parsed.day)
    parsed = dates.parse_format("January15", "%B%d")
    lu.assertNotNil(parsed)
    lu.assertEquals(1, parsed.month)
    lu.assertEquals(15, parsed.day)
    parsed = dates.parse_format("Jan0215", "%b%m%d")
    lu.assertNotNil(parsed)
    lu.assertEquals(2, parsed.month)
    lu.assertEquals(15, parsed.day)
    parsed = dates.parse_format("Jan03PM", "%b%I%p")
    lu.assertNotNil(parsed)
    lu.assertEquals(1, parsed.month)
    lu.assertEquals(15, parsed.hour)

    local spaced = { ["qunxa garablu"] = 2 }
    parsed = dates.parse_format("15 Qunxa Garablu 2026", "%d %B %Y", nil, spaced)
    lu.assertNotNil(parsed)
    lu.assertEquals(2, parsed.month)
    lu.assertEquals(15, parsed.day)
    parsed = dates.parse_format("Qunxa Garablu15", "%B%d", nil, spaced)
    lu.assertNotNil(parsed)
    lu.assertEquals(2, parsed.month)
    lu.assertEquals(15, parsed.day)

    local stamp1 = os.time { year = 2027, month = 2, day = 1, hour = 13 }
    parsed = dates.parse_format(os.date("%e%m", stamp1), "%e%m")
    lu.assertNotNil(parsed)
    lu.assertEquals(1, parsed.day)
    lu.assertEquals(2, parsed.month)
    parsed = dates.parse_format(os.date("%e%H", stamp1), "%e%H")
    lu.assertNotNil(parsed)
    lu.assertEquals(1, parsed.day)
    lu.assertEquals(13, parsed.hour)
    parsed = dates.parse_format(os.date("%e%Y", stamp1), "%e%Y")
    lu.assertNotNil(parsed)
    lu.assertEquals(1, parsed.day)
    lu.assertEquals(2027, parsed.year)

    local stamp15 = os.time { year = 2027, month = 2, day = 15, hour = 13 }
    parsed = dates.parse_format(os.date("%e%m", stamp15), "%e%m")
    lu.assertNotNil(parsed)
    lu.assertEquals(15, parsed.day)
    lu.assertEquals(2, parsed.month)

    local ampm = { ["a. m."] = "am", ["p. m."] = "pm" }
    parsed = dates.parse_format("03:30 p. m.", "%I:%M %p", nil, nil, ampm)
    lu.assertNotNil(parsed)
    lu.assertEquals(15, parsed.hour)
    parsed = dates.parse_format("03p. m.", "%I%p", nil, nil, ampm)
    lu.assertNotNil(parsed)
    lu.assertEquals(15, parsed.hour)
    parsed = dates.parse_format(os.date("%I:%M %p", os.time {
        year = 2026, month = 1, day = 1, hour = 15, min = 30,
    }), "%I:%M %p")
    lu.assertNotNil(parsed)
    lu.assertEquals(15, parsed.hour)

    lu.assertFalse(dates.valid(0, 1, 1))
    lu.assertFalse(dates.valid(10000, 1, 1))
    lu.assertNil(dates.parse_format("0000-01-01", "%F"))
    lu.assertNil(dates.parse_format("0000-02-29", "%F"))

    lu.assertNil(dates.parse_format("31/02/2027", "%d/%m/%Y"))
    lu.assertNil(dates.parse_format("2027-02-01", "%Q"))
end

function Test_prompt_foundation.Test_custom_format_with_literal_percent()
    config.reset()
    local date = require("prompt.date").new_field {
        message = "Date",
        default = "2026-11-15",
        as = "string",
        format = "100%% %d/%m/%Y",
    }
    local value = date:value()
    lu.assertEquals("100% 15/11/2026", value)
    date:set_value(value)
    lu.assertEquals(value, date:value())
    date:close()
end

function Test_prompt_foundation.Test_year_less_custom_format_validation()
    config.reset()
    local date = require("prompt.date").new_field {
        message = "Date", default = "2027-01-01", as = "string", format = "%b%d",
    }
    lu.assertError(function() date:set_value("Feb31") end)
    lu.assertError(function() date:set_value("Apr31") end)
    lu.assertError(function() date:set_value("Feb29") end)
    date:set_value("Feb28")
    lu.assertEquals("Feb28", date:value())
    date:close()

    local leap = require("prompt.date").new_field {
        message = "Date", default = "2028-01-01", as = "string", format = "%b%d",
    }
    leap:set_value("Feb29")
    lu.assertEquals("Feb29", leap:value())
    leap:close()

    local datetime = require("prompt.datetime").new_field {
        message = "When", default = "2027-01-01 10:00", as = "string", format = "%b%d %H:%M",
    }
    lu.assertError(function() datetime:set_value("Feb31 10:30") end)
    datetime:close()

    local padded = require("prompt.date").new_field {
        message = "Date", default = "2027-02-01", as = "string", format = "%e%m",
    }
    local value = padded:value()
    padded:set_value(value)
    lu.assertEquals(value, padded:value())
    padded:close()

    local padded_datetime = require("prompt.datetime").new_field {
        message = "When", default = "2027-02-01 10:30", as = "string", format = "%e%m %H:%M",
    }
    value = padded_datetime:value()
    padded_datetime:set_value(value)
    lu.assertEquals(value, padded_datetime:value())
    padded_datetime:close()

    local zero = require("prompt.date").new_field {
        message = "Date", default = "2027-01-01", as = "string", format = "%F",
    }
    lu.assertError(function() zero:set_value("0000-01-01") end)
    zero:close()
end

if not RUN_ALL then
    os.exit(lu.LuaUnit.run('-v'))
end
