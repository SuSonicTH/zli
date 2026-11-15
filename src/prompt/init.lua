-- Prompt: small, procedural terminal UI components.
--
-- Components draw inline by default and redraw only the region they own.  Set
-- `screen = "alternate"` (globally, per call, or with `prompt.screen`) for a
-- full-screen presentation.

local config = require "prompt.config"
local term = require "term"

local M = {}

function M.configure(options)
    config.configure(options)
    return M
end

function M.is_interactive()
    return config.is_interactive()
end

function M.screen(mode, fn)
    if type(mode) ~= "string" then
        error("prompt.screen: expecting a screen mode", 2)
    end
    if mode ~= "inline" and mode ~= "alternate" then
        error("prompt.screen: screen must be 'inline' or 'alternate'", 2)
    end
    if type(fn) ~= "function" then
        error("prompt.screen: expecting a function", 2)
    end

    local state = config.get()
    local previous = state.screen
    local previous_hold = state.screen_hold
    local entered = false

    state.screen = mode
    if mode == "alternate" then
        if not previous_hold then
            if config.is_interactive() then
                term.alternate_screen(true)
                term.hide_cursor()
            end
            entered = true
        end
        state.screen_hold = true
    end

    local packed = table.pack(xpcall(fn, debug.traceback))
    state.screen = previous
    state.screen_hold = previous_hold
    if entered and config.is_interactive() then
        term.alternate_screen(false)
        term.show_cursor()
    end
    if not packed[1] then error(packed[2], 0) end
    return table.unpack(packed, 2, packed.n)
end

local function component(name)
    return function(options)
        return require("prompt." .. name)(options)
    end
end

M.select = function(options)
    return require("prompt.select").select(options)
end
M.multiselect = function(options)
    return require("prompt.select").multiselect(options)
end
M.text = component("text")
M.multiline = component("multiline")
M.password = component("password")
M.confirm = component("confirm")
M.date = component("date")
M.time = component("time")
M.datetime = component("datetime")
M.progress = require("prompt.progress")
M.spinner = component("spinner")

M.width = term.width
M.truncate = term.truncate
M.wrap = term.wrap

M._config = config

return M
