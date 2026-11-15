-- Masked text input.

local config = require "prompt.config"
local fallback = require "prompt.fallback"
local field_mod = require "prompt.field"
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
            default = options.default,
            max_length = options.max_length,
            screen = options.screen,
            commit = options.commit,
        }, { mask = mask })
        if second == nil then return second, second_err end
        if first == second then return first end

        term.batch(function()
            render.write_spans(render.status(theme, "danger", "Passwords do not match"), theme)
            term.write("\n")
        end)
    end
end

--- Build a reusable password field.
-- Confirmation is handled inside the field so a form can keep editing in
-- place instead of leaving the form.
function M.new_field(options, field_options)
    field_options = field_options or {}
    validate(options)
    local theme = theme_mod.build()
    local mask = options.mask or theme.symbol("mask")
    local message = field_options.message or options.message
    local confirmation = options.confirm_message or (message .. " (confirm)")
    local stage = "first"
    local first_value = nil
    local accepted = nil
    local current

    local function first_field()
        return text.new_field(options, {
            mask = mask,
            type = "password",
            message = message,
            show_help = field_options.show_help,
        })
    end

    local function second_field()
        return text.new_field({
            message = confirmation,
            default = options.default,
            max_length = options.max_length,
        }, {
            mask = mask,
            type = "password",
            show_help = field_options.show_help,
        })
    end

    current = first_field()

    local field
    field = field_mod.new {
        type = field_options.type or "password",
        options = options,
        message = message,
        draw_active = function(_, width, active_theme)
            return current:draw(width, true, active_theme)
        end,
        draw_compact = function(self, compact_theme)
            local value = accepted or first_value or current:value()
            return render.summary(compact_theme, message, text.summary_value(compact_theme, value or "", mask))
        end,
        handle = function(self, event)
            accepted = nil
            self.error = nil
            local action, value = current:handle(event)
            if action == "submit" then
                self.error = nil
                if stage == "first" and options.confirm then
                    first_value = value
                    stage = "second"
                    current:close()
                    current = second_field()
                    return "continue"
                elseif stage == "second" then
                    if value ~= first_value then
                        self.error = "Passwords do not match"
                        stage = "first"
                        accepted = nil
                        first_value = nil
                        current:close()
                        current = first_field()
                        return "continue"
                    end
                    accepted = first_value
                    return "submit", first_value
                end
                accepted = value
                return "submit", value
            elseif action == "cancel" then
                return "cancel"
            elseif action == "eof" then
                return "eof"
            end
            return "continue"
        end,
        commit = function(self)
            if stage == "first" and options.confirm then
                first_value = current:value()
                stage = "second"
                accepted = nil
                current:close()
                current = second_field()
                self.error = nil
                return false, "Confirm the password."
            elseif stage == "second" then
                if current:value() ~= first_value then
                    self.error = "Passwords do not match"
                    stage = "first"
                    accepted = nil
                    first_value = nil
                    current:close()
                    current = first_field()
                    return false, self.error
                end
                accepted = first_value
                self.error = nil
            end
            return true
        end,
        value = function()
            if accepted ~= nil then return accepted end
            if stage == "second" then return first_value or "" end
            return current:value()
        end,
        set_value = function(_, value)
            accepted = nil
            first_value = nil
            stage = "first"
            current:close()
            current = first_field()
            current:set_value(value)
        end,
        summary = function(_, summary_theme)
            local value = accepted or first_value or current:value()
            return render.summary(summary_theme, message, text.summary_value(summary_theme, value or "", mask))
        end,
        close = function()
            current:close()
        end,
    }
    return field
end

function M.__call(_, options)
    options = options or {}
    validate(options)
    if not config.is_interactive() then
        while true do
            local first, err = fallback.password(options)
            if first == nil then return first, err end
            if not options.confirm then return first end
            local second = fallback.password {
                message = options.message .. " (confirm)",
                default = options.default,
            }
            if second == nil then return nil, "eof" end
            if first == second then return first end
            io.write("Passwords do not match.\n")
        end
    end
    return M.run(options)
end

return setmetatable(M, { __call = function(_, options) return M.__call(M, options) end })
