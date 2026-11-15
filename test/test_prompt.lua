local lu = require 'luaunit'
lu.ORDER_ACTUAL_EXPECTED = false

local prompt = require "prompt"
local config = require "prompt.config"
local render = require "prompt.render"
local theme_mod = require "prompt.theme"

Test_prompt = {}

function Test_prompt.Test_width_helpers()
    lu.assertEquals(3, prompt.width("abc"))
    lu.assertEquals(4, prompt.width("a界b"))
    lu.assertEquals(3, prompt.width("\27[31mabc\27[0m"))

    lu.assertEquals("a...", prompt.truncate("abcdef", 4))
    lu.assertEquals("abc…", prompt.truncate("abcdef", 4, "…"))
    lu.assertEquals("abc\ndef", prompt.wrap("abcdef", 3))
end

function Test_prompt.Test_config_validation()
    config.reset()
    prompt.configure { commit = "frame", page_size = 5 }
    lu.assertEquals("frame", config.get("commit"))
    lu.assertEquals(5, config.get("page_size"))
    lu.assertError(function() prompt.configure { color = "sometimes" } end)
    lu.assertError(function() prompt.configure { unknown = true } end)
    config.reset()
end

function Test_prompt.Test_theme_ascii_and_colour_modes()
    config.reset()
    prompt.configure { symbols = "ascii", color = "never" }
    local theme = theme_mod.build()
    lu.assertEquals(">", theme.symbol("pointer"))
    lu.assertEquals("[x]", theme.symbol("checked"))
    lu.assertEquals(nil, theme.style("accent"))

    prompt.configure { symbols = "unicode", color = "always" }
    theme = theme_mod.build()
    lu.assertEquals("❯", theme.symbol("pointer"))
    lu.assertNotNil(theme.style("accent"))
    config.reset()
end

function Test_prompt.Test_frame_clip_and_summary()
    local theme = theme_mod.build()
    local line = render.line("hello world")
    lu.assertEquals("hel…", render.plain(render.clip(line, 4, theme)))
    lu.assertEquals("hello world", render.plain(render.clip(line, 40, theme)))
    lu.assertEquals("? Pick › value", render.plain(render.summary(theme, "Pick", "value")))
end

function Test_prompt.Test_screen_scope_restores_mode()
    config.reset()
    prompt.screen("alternate", function()
        lu.assertEquals("alternate", config.get("screen"))
    end)
    lu.assertEquals("inline", config.get("screen"))

    lu.assertError(function()
        prompt.screen("alternate", function() error("boom") end)
    end)
    lu.assertEquals("inline", config.get("screen"))
end

local input = require "prompt.input"

local function drive(events, fn)
    config.reset()
    config.configure { force_interactive = true }
    render.capture = {}
    input.events = events or {}
    local result = table.pack(fn())
    local frames = render.capture
    input.events = nil
    render.capture = nil
    config.reset()
    return result, frames
end

local function key(code, extra)
    local event = { type = "key", code = code }
    for name, value in pairs(extra or {}) do event[name] = value end
    return event
end

local function char(value, extra)
    return key("char", { char = value, [1] = extra })
end

function Test_prompt.Test_select_navigation_and_default()
    local result = drive({ key("down"), key("enter") }, function()
        return prompt.select { message = "Pick", items = { "a", "b", "c" } }
    end)
    lu.assertEquals("b", result[1])

    result = drive({ key("enter") }, function()
        return prompt.select { message = "Pick", items = { "a", "b" }, default = "b" }
    end)
    lu.assertEquals("b", result[1])

    result = drive({ key("enter") }, function()
        return prompt.select {
            message = "Pick",
            items = { { label = "a", disabled = true }, "b" },
            default = "a",
        }
    end)
    lu.assertEquals("b", result[1])
end

function Test_prompt.Test_select_filter_and_return_index()
    local result = drive({ char("g"), key("enter") }, function()
        return prompt.select {
            message = "Pick",
            items = { "alpha", "beta", "gamma" },
            filter = true,
            return_index = true,
        }
    end)
    lu.assertEquals(3, result[1])

    result = drive({ char("z"), key("enter"), key("esc"), key("esc") }, function()
        return prompt.select { message = "Pick", items = { "alpha" }, filter = true }
    end)
    lu.assertEquals(nil, result[1])
    lu.assertEquals("cancelled", result[2])
end

function Test_prompt.Test_multiselect_toggle_and_constraints()
    local result = drive({
        char(" "), key("down"), char(" "), key("enter"),
    }, function()
        return prompt.multiselect { message = "Pick", items = { "a", "b", "c" } }
    end)
    lu.assertEquals({ "a", "b" }, result[1])

    result = drive({ key("enter"), key("esc") }, function()
        return prompt.multiselect { message = "Pick", items = { "a", "b" }, required = true }
    end)
    lu.assertEquals(nil, result[1])
    lu.assertEquals("cancelled", result[2])
end

function Test_prompt.Test_text_validation_and_summary()
    local result, frames = drive({
        char("x"), key("enter"), key("backspace"), char("y"), key("enter"),
    }, function()
        return prompt.text {
            message = "Name",
            validate = function(value) return value ~= "x" or nil, "no x" end,
        }
    end)
    lu.assertEquals("y", result[1])
    lu.assertTrue(#frames.commits >= 1)
    lu.assertEquals("Name", frames.commits[1].summary[2].text)
end

function Test_prompt.Test_text_default_and_password_mask()
    local result = drive({ key("enter") }, function()
        return prompt.text { message = "Name", default = "Ada" }
    end)
    lu.assertEquals("Ada", result[1])

    result = drive({ char("x"), char("y"), key("enter") }, function()
        return prompt.password { message = "Token" }
    end)
    lu.assertEquals("xy", result[1])
end

function Test_prompt.Test_multiline_alt_enter()
    local result = drive({
        char("a"), key("enter", { alt = true }), char("b"), key("enter"),
    }, function()
        return prompt.multiline { message = "Text", rows = 3 }
    end)
    lu.assertEquals("a\nb", result[1])
end

function Test_prompt.Test_confirm_defaults_and_keys()
    local result = drive({ key("enter") }, function()
        return prompt.confirm { message = "Sure?", default = false }
    end)
    lu.assertEquals(false, result[1])

    result = drive({ char("y") }, function()
        return prompt.confirm { message = "Sure?" }
    end)
    lu.assertEquals(true, result[1])
end

function Test_prompt.Test_cancel_returns_nil_cancelled()
    local result = drive({ key("esc") }, function()
        return prompt.select { message = "Pick", items = { "a" } }
    end)
    lu.assertEquals(nil, result[1])
    lu.assertEquals("cancelled", result[2])
end

function Test_prompt.Test_plain_fallback()
    local support = require "test/support"
    local script = support.temp_file("prompt_fallback", [[
local prompt = require "prompt"
print("select=" .. prompt.select { message = "Pick", items = { "a", "b" }, default = "b" })
print("multi=" .. table.concat(prompt.multiselect { message = "Pick", items = { "a", "b" }, default = { "a" } }, ","))
print("text=" .. prompt.text { message = "Name", default = "Ada" })
print("confirm=" .. tostring(prompt.confirm { message = "Sure?", default = true }))
]])
    local stdout, status = support.run({ script }, {
        home = support.temp_dir("prompt_home"),
        stdin = "",
    })
    lu.assertEquals(0, status, stdout)
    lu.assertStrContains(stdout, "select=b")
    lu.assertStrContains(stdout, "multi=a")
    lu.assertStrContains(stdout, "text=Ada")
    lu.assertStrContains(stdout, "confirm=true")
end


local dates = require "prompt.dates"

function Test_prompt.Test_date_arithmetic()
    for _, value in ipairs {
        { 1970, 1, 1 }, { 2000, 2, 29 }, { 2026, 11, 15 }, { 1999, 12, 31 },
    } do
        local days = dates.days_from_civil(value[1], value[2], value[3])
        local year, month, day = dates.civil_from_days(days)
        lu.assertEquals(value[1], year)
        lu.assertEquals(value[2], month)
        lu.assertEquals(value[3], day)
    end
    lu.assertEquals(4, dates.weekday(1970, 1, 1))
    lu.assertEquals(7, dates.weekday(2026, 11, 15))
    lu.assertEquals(29, dates.days_in_month(2000, 2))
    lu.assertEquals(28, dates.days_in_month(2026, 2))
    lu.assertNil(dates.parse_date("2026-02-30"))
    lu.assertEquals("2026-11-15", dates.format_date(dates.parse_date("2026-11-15")))
end

function Test_prompt.Test_date_picker_navigation_and_typing()
    local result = drive({ key("right"), key("enter") }, function()
        return prompt.date { message = "Date", default = "2026-11-15", as = "string" }
    end)
    lu.assertEquals("2026-11-16", result[1])

    local events = {}
    for _, value in ipairs { "2", "0", "2", "7", "-", "0", "1", "-", "0", "2" } do
        events[#events + 1] = char(value)
    end
    events[#events + 1] = key("enter")
    events[#events + 1] = key("enter")
    result = drive(events, function()
        return prompt.date { message = "Date", default = "2026-11-15", as = "string" }
    end)
    lu.assertEquals("2027-01-02", result[1])
end

function Test_prompt.Test_date_picker_bounds()
    local result = drive({ key("right"), key("enter") }, function()
        return prompt.date {
            message = "Date",
            default = "2026-11-30",
            min = "2026-11-01",
            max = "2026-11-30",
            as = "string",
        }
    end)
    lu.assertEquals("2026-11-30", result[1])
end

function Test_prompt.Test_time_picker_segments_and_typing()
    local result = drive({ key("right"), key("up"), key("enter") }, function()
        return prompt.time { message = "Time", default = { hour = 10, min = 30 } }
    end)
    lu.assertEquals(31, result[1].min)

    result = drive({ char("1"), char("5"), char("4"), char("5"), key("enter") }, function()
        return prompt.time { message = "Time", default = { hour = 10, min = 30 } }
    end)
    lu.assertEquals(15, result[1].hour)
    lu.assertEquals(45, result[1].min)
end

function Test_prompt.Test_datetime_tab_and_time_adjust()
    local result = drive({ key("tab"), key("right"), key("up"), key("enter") }, function()
        return prompt.datetime { message = "When", default = "2026-11-15 10:30", as = "table" }
    end)
    lu.assertEquals(2026, result[1].year)
    lu.assertEquals(11, result[1].month)
    lu.assertEquals(15, result[1].day)
    lu.assertEquals(10, result[1].hour)
    lu.assertEquals(31, result[1].min)
end

if not RUN_ALL then
    os.exit(lu.LuaUnit.run('-v'))
end
