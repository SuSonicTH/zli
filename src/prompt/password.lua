-- Masked text input.

local config = require "prompt.config"
local fallback = require "prompt.fallback"
local render = require "prompt.render"
local text = require "prompt.text"
local theme_mod = require "prompt.theme"
local term = require "term"

local M = {}

local function validate(options)
    if type(options) ~= "table" then
        error("prompt.password: expecting an options table", 3)
    end
    if type(options.message) ~= "string" or options.message == "" then
        error("prompt.password: message must be a non-empty string", 3)
    end
    if options.confirm ~= nil and type(options.confirm) ~= "boolean" then
        error("prompt.password: confirm must be a boolean", 3)
    end
end

function M.run(options)
    validate(options)
    local theme = theme_mod.build()
    local mask = options.mask or theme.symbol("mask")

    while true do
        local first, err = text.run(options, { mask = mask })
        if first == nil then return first, err end
        if not options.confirm then return first end

        local confirmation = options.confirm_message or (options.message .. " (confirm)")
        local second, second_err = text.run({
            message = confirmation,
            max_length = options.max_length,
            screen = options.screen,
            commit = options.commit,
        }, { mask = mask })
        if second == nil then return second, second_err end
        if first == second then return first end

        render.write_spans(render.status(theme, "danger", "Passwords do not match"), theme)
        term.write("\n")
        term.flush()
    end
end

return function(options)
    options = options or {}
    validate(options)
    if not config.is_interactive() then
        while true do
            local first, err = fallback.password(options)
            if first == nil then return first, err end
            if not options.confirm then return first end
            local second = fallback.password { message = options.message .. " (confirm)" }
            if second == nil then return nil, "eof" end
            if first == second then return first end
            io.write("Passwords do not match.\n")
        end
    end
    return M.run(options)
end
