-- Semantic theme, glyphs and automatic colour/symbol detection.

local term = require "term"
local config = require "prompt.config"

local M = {}

local default_styles = {
    message = { bold = true },
    title = { fg = "bright_cyan", bold = true },
    muted = { fg = "bright_black" },
    accent = { fg = "cyan", bold = true },
    selected = { fg = "black", bg = "cyan", bold = true },
    selected_muted = { fg = "bright_black", bg = "cyan" },
    success = { fg = "green", bold = true },
    danger = { fg = "red", bold = true },
    warning = { fg = "yellow" },
    border = { fg = "bright_black" },
    error = { fg = "red" },
}

local unicode = {
    pointer = "❯",
    checked = "◉",
    unchecked = "◯",
    radio_on = "●",
    radio_off = "○",
    arrow_up = "↑",
    arrow_down = "↓",
    tick = "✔",
    cross = "✖",
    ellipsis = "…",
    bar_full = "█",
    bar_empty = "░",
    separator = "›",
    bullet = "•",
    mask = "•",
}

local ascii = {
    pointer = ">",
    checked = "[x]",
    unchecked = "[ ]",
    radio_on = "(*)",
    radio_off = "( )",
    arrow_up = "^",
    arrow_down = "v",
    tick = "ok",
    cross = "x",
    ellipsis = "...",
    bar_full = "#",
    bar_empty = "-",
    separator = ">",
    bullet = "*",
    mask = "*",
}

local function env(name)
    local value = os.getenv(name)
    if value == nil or value == "" then return nil end
    return value
end

local function unicode_locale()
    local mode = env("ZLI_TUI_SYMBOLS")
    if mode == "ascii" then return false end
    if mode == "unicode" then return true end
    if os.is_windows then return true end
    local locale = env("LC_ALL") or env("LC_CTYPE") or env("LANG") or ""
    return locale:lower():find("utf%-?8") ~= nil
end

local function color_enabled()
    local mode = config.get("color")
    if mode == "always" then return true end
    if mode == "never" then return false end
    if not term.is_tty() then return false end
    local no_color = env("NO_COLOR")
    if no_color ~= nil then return false end
    if env("TERM") == "dumb" then return false end
    return true
end

function M.build()
    local user = config.get("theme") or {}
    local styles = {}
    for name, style in pairs(default_styles) do styles[name] = style end
    for name, style in pairs(user) do
        if style == false then
            styles[name] = nil
        else
            styles[name] = style
        end
    end

    local mode = config.get("symbols")
    local use_unicode = mode == "unicode" or (mode == "auto" and unicode_locale())
    local symbols = use_unicode and unicode or ascii

    local theme = {
        styles = styles,
        symbols = symbols,
        unicode = use_unicode,
        color = color_enabled(),
    }

    function theme.symbol(name)
        return symbols[name] or unicode[name] or ""
    end

    function theme.style(name)
        if not theme.color then return nil end
        return styles[name]
    end

    function theme.apply(name)
        if not theme.color then return end
        local style = styles[name]
        if style then term.style(style) end
    end

    function theme.reset()
        if theme.color then term.reset_style() end
    end

    return theme
end

return M
