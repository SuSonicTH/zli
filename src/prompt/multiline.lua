-- Multi-line text input built on the embeddable line editor.

local config = require "prompt.config"
local fallback = require "prompt.fallback"
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

function M.run(options)
    validate_options(options)
    local height = options.rows or 5
    local state = { error = nil, width = 0, height = height }
    local theme = theme_mod.build()

    local editor = editor_mod.new(40, height, {
        initial = options.default or "",
        single_line = false,
        submit_on_enter = true,
        alt_enter_newline = true,
        max_length = options.max_length,
    })

    local function width()
        local term = require "term"
        local size = term.size()
        return math.max(1, (size and size.columns or 80) - 3)
    end

    local function current_frame()
        local columns = width()
        if columns ~= state.width then
            state.width = columns
            editor:resize(columns, height)
        end
        local lines = {
            render.line(
                render.span("? ", "accent"),
                render.span(options.message, "message")
            ),
        }
        local rows, position = editor:render()
        local placeholder = editor:len() == 0 and options.placeholder
        for index = 1, height do
            local spans = { render.span("  ", nil) }
            if placeholder and index == 1 then
                spans[#spans + 1] = render.span(options.placeholder, "muted")
            else
                for _, span in ipairs(rows[index] or {}) do spans[#spans + 1] = span end
            end
            lines[#lines + 1] = spans
        end
        if state.error then
            lines[#lines + 1] = render.line(render.span(state.error, "error"))
        end
        lines[#lines + 1] = render.line(
            render.span("Alt+Enter newline  Enter submit  Esc cancel", "muted")
        )
        local cursor = {
            row = 2 + ((position and position.row) or 0),
            column = ((position and position.column) or 0) + 2,
        }
        if placeholder then cursor = { row = 2, column = 2 } end
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
            return render.summary(theme, options.message, summary_text(value))
        end,
        final_frame = current_frame,
    })
    editor:close()
    return table.unpack(packed, 1, packed.n)
end

return function(options)
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
