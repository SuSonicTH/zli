-- Yes/no confirmation.

local config = require "prompt.config"
local fallback = require "prompt.fallback"
local input = require "prompt.input"
local render = require "prompt.render"
local theme_mod = require "prompt.theme"

local M = {}

local function validate(options)
    if type(options) ~= "table" then
        error("prompt.confirm: expecting an options table", 3)
    end
    if type(options.message) ~= "string" or options.message == "" then
        error("prompt.confirm: message must be a non-empty string", 3)
    end
    if options.default ~= nil and type(options.default) ~= "boolean" then
        error("prompt.confirm: default must be a boolean", 3)
    end
end

function M.run(options)
    validate(options)
    local theme = theme_mod.build()
    local state = { error = nil, choice = options.default }
    local choices = {
        { label = "yes", value = true },
        { label = "no", value = false },
    }

    local function frame()
        local lines = {
            render.line(
                render.span("? ", "accent"),
                render.span(options.message, "message")
            ),
        }
        local spans = { render.span("  ", nil) }
        for index, choice in ipairs(choices) do
            local chosen = state.choice == choice.value
            if index > 1 then spans[#spans + 1] = render.span("  ", nil) end
            spans[#spans + 1] = render.span(
                (chosen and "[" or " ") .. choice.label .. (chosen and "]" or " "),
                chosen and "selected" or "muted"
            )
        end
        lines[#lines + 1] = spans
        if state.error then lines[#lines + 1] = render.line(render.span(state.error, "error")) end
        lines[#lines + 1] = render.line(render.span("y/n  enter accept  esc cancel", "muted"))
        return render.frame(lines)
    end

    local function on_event(event)
        if input.cancel(event) then return "cancel" end
        local char = input.printable(event)
        if char then
            char = char:lower()
            if char == "y" then return "submit", true end
            if char == "n" then return "submit", false end
        end
        if input.key(event, "left") then
            state.choice = true
            return "continue"
        end
        if input.key(event, "right") then
            state.choice = false
            return "continue"
        end
        if input.enter(event) then
            if state.choice == nil then
                state.error = "Press y or n."
                return "continue"
            end
            return "submit", state.choice
        end
        return "continue"
    end

    return input.run {
        screen = options.screen,
        commit = options.commit,
        frame = frame,
        on_event = on_event,
        summary = function(value)
            return render.summary(theme, options.message, value and "yes" or "no")
        end,
        final_frame = frame,
    }
end

return function(options)
    options = options or {}
    validate(options)
    if not config.is_interactive() then return fallback.confirm(options) end
    return M.run(options)
end
