-- Multi-line text input built on the embeddable line editor.

local config = require "prompt.config"
local fallback = require "prompt.fallback"
local field_mod = require "prompt.field"
local input = require "prompt.input"
local render = require "prompt.render"
local theme_mod = require "prompt.theme"

local editor_mod = require "prompt_editor"

local M = {}

local function validate_options(options)
    if type(options) ~= "table" then
        error("prompt.multiline: expecting an options table", 3)
    end
    if type(options.message) ~= "string" or options.message == "" then
        error("prompt.multiline: message must be a non-empty string", 3)
    end
    if options.default ~= nil and type(options.default) ~= "string" then
        error("prompt.multiline: default must be a string", 3)
    end
    if options.rows ~= nil and (type(options.rows) ~= "number" or options.rows < 1) then
        error("prompt.multiline: rows must be a positive number", 3)
    end
    if options.max_length ~= nil and (type(options.max_length) ~= "number" or options.max_length < 1) then
        error("prompt.multiline: max_length must be a positive number", 3)
    end
    if options.validate ~= nil and type(options.validate) ~= "function" then
        error("prompt.multiline: validate must be a function", 3)
    end
end

local function summary_text(value)
    local first = value:match("^[^\n]*")
    local _, lines = value:gsub("\n", "")
    if lines == 0 then return first end
    return first .. " … +" .. lines .. " lines"
end

local function codepoint_count(text)
    local count = utf8.len(text)
    if count then return count end
    -- Invalid UTF-8 is kept by the editor; count non-continuation bytes so
    -- validation and masked summaries cannot raise.
    count = 0
    for index = 1, #text do
        local byte = text:byte(index)
        if byte < 0x80 or byte >= 0xC0 then count = count + 1 end
    end
    return count
end

local function check_value(options, value)
    if options.trim then value = value:gsub("^%s+", ""):gsub("%s+$", "") end
    if options.required and value == "" then
        return nil, "An answer is required."
    end
    if options.max_length and codepoint_count(value) > options.max_length then
        return nil, "Use at most " .. options.max_length .. " characters."
    end
    if options.validate then
        local ok, message = options.validate(value)
        if ok == false or (ok == nil and message ~= nil) then
            return nil, tostring(message or "Invalid value.")
        end
    end
    return value
end

--- Build a reusable field.
-- `field_options.show_help` suppresses the key hint line inside a form.
function M.new_field(options, field_options)
    field_options = field_options or {}
    validate_options(options)
    local height = options.rows or 5
    local show_help = field_options.show_help ~= false
    local message = field_options.message or options.message
    local state = { error = nil, width = 0, rows = 0, accepted = nil }

    local editor = editor_mod.new(40, height, {
        initial = options.default or "",
        single_line = false,
        submit_on_enter = field_options.submit_on_enter ~= false,
        alt_enter_newline = field_options.alt_enter_newline ~= false,
        max_length = options.max_length,
    })

    local field
    field = field_mod.new {
        type = field_options.type or "multiline",
        options = options,
        message = message,
        draw_active = function(self, width, theme)
            local columns = field_mod.active_width(width)
            local rows_to_show = height
            if self.max_height then
                local chrome = 1 + (show_help and 1 or 0)
                rows_to_show = math.max(1, math.min(height, self.max_height - chrome))
            end
            if columns ~= state.width or rows_to_show ~= state.rows then
                state.width = columns
                state.rows = rows_to_show
                editor:resize(columns, rows_to_show)
            end
            local lines = { field_mod.label(self.message) }
            local rows, position = editor:render()
            local placeholder = editor:len() == 0 and options.placeholder
            for index = 1, rows_to_show do
                local spans = { render.span("  ", nil) }
                if placeholder and index == 1 then
                    spans[#spans + 1] = render.span(options.placeholder, "muted")
                else
                    for _, span in ipairs(rows[index] or {}) do spans[#spans + 1] = span end
                end
                lines[#lines + 1] = spans
            end
            if show_help then
                lines[#lines + 1] = field_mod.help_line(
                    "Alt+Enter newline  Enter submit  Esc cancel"
                )
            end
            local cursor = {
                row = 2 + ((position and position.row) or 0),
                column = ((position and position.column) or 0) + 2,
            }
            if placeholder then cursor = { row = 2, column = 2 } end
            return render.frame(lines, cursor)
        end,
        draw_compact = function(self, theme)
            local value = state.accepted
            if value == nil then value = editor:value() end
            return render.summary(theme, self.message, summary_text(value))
        end,
        handle = function(self, event)
            if input.key(event, "esc") or input.ctrl(event, "c") then return "cancel" end
            if event.type == "key" or event.type == "paste" then
                self.error = nil
                state.accepted = nil
                local action = editor:feed(event)
                if action == "submit" then
                    local value, message_text = check_value(options, editor:value())
                    if value == nil then
                        self.error = message_text
                        state.accepted = nil
                        return "continue"
                    end
                    state.accepted = value
                    return "submit", value
                elseif action == "abort" then
                    return "cancel"
                elseif action == "eof" then
                    return "eof"
                end
            end
            return "continue"
        end,
        commit = function(self)
            local value, message_text = check_value(options, editor:value())
            if value == nil then
                self.error = message_text
                state.accepted = nil
                return false, message_text
            end
            self.error = nil
            state.accepted = value
            return true
        end,
        value = function()
            if state.accepted ~= nil then return state.accepted end
            return editor:value()
        end,
        set_value = function(_, value)
            state.accepted = nil
            state.error = nil
            editor:set_text(tostring(value or ""))
        end,
        summary = function(self, theme)
            local value = state.accepted
            if value == nil then value = editor:value() end
            return render.summary(theme, self.message, summary_text(value))
        end,
        close = function()
            editor:close()
        end,
    }
    return field
end

function M.run(options, field_options)
    local theme = theme_mod.build()
    local field = M.new_field(options, field_options)
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

function M.__call(_, options)
    validate_options(options)
    if not config.is_interactive() then
        while true do
            local value, message = fallback.multiline(options, options.default)
            if value == nil then return nil, message end
            local checked, problem = check_value(options, value)
            if checked ~= nil then return checked end
            io.write(problem .. "\n")
        end
    end
    return M.run(options)
end

return setmetatable(M, { __call = function(_, options) return M.__call(M, options) end })
