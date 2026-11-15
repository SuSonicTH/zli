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


if not RUN_ALL then
    os.exit(lu.LuaUnit.run('-v'))
end
