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

if not RUN_ALL then
    os.exit(lu.LuaUnit.run('-v'))
end
