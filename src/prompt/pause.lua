-- Wait for a key before continuing.

local config = require "prompt.config"
local input = require "prompt.input"
local render = require "prompt.render"
local theme_mod = require "prompt.theme"

local M = {}

local function validate(options)
    if type(options) ~= "table" then
        error("prompt.pause: expecting an options table", 3)
    end
    if options.message ~= nil and (type(options.message) ~= "string" or options.message == "") then
        error("prompt.pause: message must be a non-empty string", 3)
    end
    if options.any ~= nil and type(options.any) ~= "boolean" then
        error("prompt.pause: any must be a boolean", 3)
    end
end

function M.__call(_, options)
    options = options or {}
    validate(options)
    local message = options.message or "Press any key to continue"

    if not config.is_interactive() then
        io.write(message .. "\n")
        io.flush()
        return true
    end

    local theme = theme_mod.build()
    local function draw()
        return render.frame { render.line(render.span(message, "message")) }
    end
    return input.run {
        screen = options.screen,
        commit = options.commit,
        frame = draw,
        on_event = function(event)
            if event.type ~= "key" then return "continue" end
            if input.cancel(event) then return "cancel" end
            if options.any or input.enter(event) then return "submit", true end
            return "continue"
        end,
        summary = function()
            return render.line(render.span(message, "message"))
        end,
        final_frame = draw,
    }
end

return setmetatable(M, { __call = function(_, options) return M.__call(M, options) end })
