-- Single-line text input built on the embeddable line editor.

local config = require "prompt.config"
local fallback = require "prompt.fallback"
local input = require "prompt.input"
local render = require "prompt.render"
local theme_mod = require "prompt.theme"

local editor_mod = require "prompt_editor"

local M = {}

local function validate_options(options)
    if type(options) ~= "table" then
        error("prompt.text: expecting an options table", 3)
    end
    if type(options.message) ~= "string" or options.message == "" then
        error("prompt.text: message must be a non-empty string", 3)
    end
    if options.default ~= nil and type(options.default) ~= "string" then
        error("prompt.text: default must be a string", 3)
    end
    if options.placeholder ~= nil and type(options.placeholder) ~= "string" then
        error("prompt.text: placeholder must be a string", 3)
    end
    if options.max_length ~= nil and (type(options.max_length) ~= "number" or options.max_length < 1) then
        error("prompt.text: max_length must be a positive number", 3)
    end
    if options.validate ~= nil and type(options.validate) ~= "function" then
        error("prompt.text: validate must be a function", 3)
    end
end

local function codepoint_count(text)
    local count = 0
    for _ in utf8.codes(text) do count = count + 1 end
    return count
end

function M.summary_value(theme, value, mask)
    if mask then
        return string.rep(mask, math.min(codepoint_count(value), 12))
    end
    if value == "" then return '""' end
    return value
end

local function clean_value(options, value)
    if options.trim then return (value:gsub("^%s+", ""):gsub("%s+$", "")) end
    return value
end

local function check_value(options, value)
    value = clean_value(options, value)
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

function M.run(options, field)
    field = field or {}
    validate_options(options)
    local mask = field.mask

    local editor = editor_mod.new(40, 1, {
        initial = options.default or "",
        single_line = true,
        submit_on_enter = true,
        max_length = options.max_length,
        mask = mask,
    })
    local state = { error = nil, width = 0 }
    local theme = theme_mod.build()

    local function width()
        local term = require "term"
        local size = term.size()
        return math.max(1, (size and size.columns or 80) - 3)
    end

    local function current_frame()
        local columns = width()
        if columns ~= state.width then
            state.width = columns
            editor:resize(columns, 1)
        end

        local lines = {
            render.line(
                render.span("? ", "accent"),
                render.span(field.message or options.message, "message")
            ),
        }
        local cursor
        if editor:len() == 0 and options.placeholder then
            lines[#lines + 1] = render.line(
                render.span("  ", nil),
                render.span(options.placeholder, "muted")
            )
            cursor = { row = 2, column = 2 }
        else
            local rows, position = editor:render()
            local spans = { render.span("  ", nil) }
            for _, span in ipairs(rows[1] or {}) do spans[#spans + 1] = span end
            lines[#lines + 1] = spans
            cursor = { row = 2, column = (position and position.column or 0) + 2 }
        end
        if state.error then
            lines[#lines + 1] = render.line(render.span(state.error, "error"))
        end
        return render.frame(lines, cursor)
    end

    local function accept(value)
        local checked, message = check_value(options, value)
        if checked == nil then
            state.error = message
            return nil
        end
        return checked
    end

    local function on_event(event)
        if input.key(event, "esc") or input.ctrl(event, "c") then return "cancel" end
        if event.type == "key" or event.type == "paste" then
            state.error = nil
            local action = editor:feed(event)
            if action == "submit" then
                local value = accept(editor:value())
                if value ~= nil then return "submit", value end
                return "continue"
            elseif action == "abort" then
                return "cancel"
            elseif action == "eof" then
                return "eof"
            end
        end
        return "continue"
    end

    local packed = table.pack(input.run {
        screen = options.screen,
        commit = options.commit,
        frame = current_frame,
        on_event = on_event,
        summary = function(value)
            return render.summary(theme, field.message or options.message, M.summary_value(theme, value, mask))
        end,
        final_frame = current_frame,
    })
    editor:close()
    if packed[1] ~= nil then
        if field.on_value then field.on_value(packed[1]) end
    end
    return table.unpack(packed, 1, packed.n)
end

M.__call = function(_, options)
    validate_options(options)
    if not config.is_interactive() then
        while true do
            local value, message = fallback.text(options, options.default)
            if value == nil then return nil, message end
            local checked, problem = check_value(options, value)
            if checked ~= nil then return checked end
            io.write(problem .. "\n")
        end
    end
    return M.run(options)
end

return setmetatable(M, { __call = function(_, options) return M.__call(M, options) end })
