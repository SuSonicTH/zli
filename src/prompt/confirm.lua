-- Yes/no confirmation.

local config = require "prompt.config"
local fallback = require "prompt.fallback"
local field_mod = require "prompt.field"
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

local choices = {
    { label = "yes", value = true },
    { label = "no", value = false },
}

function M.new_field(options, field_options)
    field_options = field_options or {}
    validate(options)
    local show_help = field_options.show_help ~= false
    local message = field_options.message or options.message
    local state = { choice = options.default }

    local field
    field = field_mod.new {
        type = field_options.type or "confirm",
        options = options,
        message = message,
        draw_active = function(self, width, theme)
            local lines = { field_mod.label(self.message) }
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
            if show_help then
                lines[#lines + 1] = field_mod.help_line("y/n  enter accept  esc cancel")
            end
            return render.frame(lines)
        end,
        draw_compact = function(self, theme)
            local value = state.choice
            local text = value == nil and "choose" or (value and "yes" or "no")
            return render.summary(theme, self.message, text)
        end,
        handle = function(self, event)
            if input.cancel(event) then return "cancel" end
            local char = input.printable(event)
            if char then
                char = char:lower()
                if char == "y" then
                    state.choice = true
                    self.error = nil
                    return "submit", true
                end
                if char == "n" then
                    state.choice = false
                    self.error = nil
                    return "submit", false
                end
            end
            if input.key(event, "left") then
                state.choice = true
                self.error = nil
                return "continue"
            end
            if input.key(event, "right") then
                state.choice = false
                self.error = nil
                return "continue"
            end
            if input.enter(event) then
                if state.choice == nil then
                    self.error = "Press y or n."
                    return "continue"
                end
                self.error = nil
                return "submit", state.choice
            end
            return "continue"
        end,
        value = function()
            return state.choice
        end,
        set_value = function(_, value)
            if value == true or value == false or value == nil then state.choice = value end
        end,
        summary = function(self, theme)
            local text = state.choice == nil and "choose" or (state.choice and "yes" or "no")
            return render.summary(theme, self.message, text)
        end,
        close = function() end,
    }
    return field
end

function M.run(options)
    local theme = theme_mod.build()
    local field = M.new_field(options)
    local function draw()
        return field:frame(nil, theme)
    end

    local packed = table.pack(input.run {
        screen = options.screen,
        commit = options.commit,
        frame = draw,
        on_event = function(event) return field:handle(event) end,
        summary = function() return field:summary(theme) end,
        final_frame = draw,
    })
    field:close()
    return table.unpack(packed, 1, packed.n)
end

M.__call = function(_, options)
    options = options or {}
    validate(options)
    if not config.is_interactive() then return fallback.confirm(options) end
    return M.run(options)
end

return setmetatable(M, { __call = function(_, options) return M.__call(M, options) end })
