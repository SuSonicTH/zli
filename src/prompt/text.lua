-- Single-line text input built on the embeddable line editor.

local config = require "prompt.config"
local fallback = require "prompt.fallback"
local field_mod = require "prompt.field"
local fuzzy = require "prompt.fuzzy"
local input = require "prompt.input"
local render = require "prompt.render"
local suggest = require "prompt.suggest"
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
    if options.suggestions ~= nil
        and type(options.suggestions) ~= "table"
        and type(options.suggestions) ~= "function"
    then
        error("prompt.text: suggestions must be a table or a function", 3)
    end
    if options.complete ~= nil
        and options.complete ~= "tab"
        and options.complete ~= "auto"
        and options.complete ~= false
    then
        error("prompt.text: complete must be 'tab', 'auto' or false", 3)
    end
    if options.max_suggestions ~= nil
        and (type(options.max_suggestions) ~= "number" or options.max_suggestions < 1)
    then
        error("prompt.text: max_suggestions must be a positive number", 3)
    end
    if options.suggestion_filter ~= nil
        and options.suggestion_filter ~= "prefix"
        and options.suggestion_filter ~= "substring"
        and options.suggestion_filter ~= "fuzzy"
    then
        error("prompt.text: suggestion_filter must be 'prefix', 'substring' or 'fuzzy'", 3)
    end
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

--- Build a reusable field.
-- `field_options.mask` replaces every displayed character and
-- `field_options.message` overrides the label (used by password confirmation).
function M.new_field(options, field_options)
    field_options = field_options or {}
    validate_options(options)
    local mask = field_options.mask
    local message = field_options.message or options.message

    local editor = editor_mod.new(40, 1, {
        initial = options.default or "",
        single_line = true,
        submit_on_enter = true,
        max_length = options.max_length,
        mask = mask,
    })
    local state = { error = nil, width = 0, accepted = nil }

    local suggestions = options.suggestions
    local complete = options.complete
    if complete == nil then complete = suggestions and "tab" or false end
    local max_suggestions = math.floor(options.max_suggestions or 6)
    local filter_mode = options.suggestion_filter or "prefix"
    local menu = {
        open = false,
        matches = {},
        selected = nil,
        closed = false,
        closed_query = nil,
    }

    local function suggestion_items(query)
        if type(suggestions) == "function" then
            local items = suggestions(query)
            if type(items) ~= "table" then
                error("prompt.text: suggestions function must return a table", 0)
            end
            return items
        end
        return suggestions or {}
    end

    local function refresh_menu()
        if suggestions == nil or complete == false then
            menu.open = false
            menu.matches = {}
            menu.selected = nil
            return
        end
        local query = editor:value()
        if menu.closed and menu.closed_query == query then
            menu.open = false
            return
        end
        menu.closed = false
        local items = suggest.normalize(suggestion_items(query))
        local matches = suggest.filter(items, query, filter_mode)
        while #matches > max_suggestions do table.remove(matches) end
        menu.matches = matches
        menu.open = #matches > 0
        menu.selected = nil
        if menu.open and complete == "auto" then menu.selected = 1 end
    end

    local function close_menu()
        menu.open = false
        menu.selected = nil
        menu.closed = true
        menu.closed_query = editor:value()
    end

    local function match_value(match)
        local value = match.item.value
        if value == nil then value = match.item.label end
        return tostring(value)
    end

    local function accept_match(position)
        local match = menu.matches[position or menu.selected]
        if match == nil then return false end
        editor:set_text(match_value(match))
        close_menu()
        return true
    end

    local function move_menu(delta)
        local count = #menu.matches
        if count == 0 then return end
        local position = menu.selected
        if position == nil then
            position = delta > 0 and 0 or count + 1
        end
        position = position + delta
        if position > count then position = 1 end
        if position < 1 then position = count end
        menu.selected = position
    end

    refresh_menu()

    local field
    field = field_mod.new {
        type = field_options.type or "text",
        options = options,
        message = message,
        draw_active = function(self, width, theme)
            local columns = field_mod.active_width(width)
            if columns ~= state.width then
                state.width = columns
                editor:resize(columns, 1)
            end

            local lines = { field_mod.label(self.message) }
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
            if menu.open and #menu.matches > 0 then
                for position, match in ipairs(menu.matches) do
                    local current = position == menu.selected
                    local spans = {
                        render.span("  ", nil),
                        render.span(current and theme.symbol("pointer") or " ", current and "accent" or nil),
                        render.span(" ", nil),
                    }
                    local highlighted = fuzzy.highlight(
                        match.item.label,
                        match.ranges,
                        current and "selected_match" or "match"
                    )
                    for _, span in ipairs(highlighted) do
                        if span.style == nil and current then
                            spans[#spans + 1] = render.span(span.text, "selected")
                        else
                            spans[#spans + 1] = { text = span.text, style = span.style }
                        end
                    end
                    if match.item.description then
                        spans[#spans + 1] = render.span(
                            "  " .. match.item.description,
                            current and "selected_muted" or "muted"
                        )
                    end
                    lines[#lines + 1] = spans
                end
            end
            return render.frame(lines, cursor)
        end,
        draw_compact = function(self, theme)
            local value = state.accepted
            if value == nil then value = editor:value() end
            return render.summary(theme, self.message, M.summary_value(theme, value, mask))
        end,
        handle = function(self, event)
            if input.key(event, "esc") or input.ctrl(event, "c") then
                if input.key(event, "esc") and menu.open then
                    close_menu()
                    return "continue"
                end
                return "cancel"
            end
            if input.key(event, "tab") and suggestions ~= nil then
                if complete ~= false and menu.open then
                    if menu.selected then
                        accept_match(menu.selected)
                    else
                        local completion = suggest.complete(menu.matches, editor:value())
                        if completion ~= nil then
                            editor:set_text(tostring(completion))
                            close_menu()
                        end
                    end
                end
                return "continue"
            end
            if event.type == "key" and menu.open then
                if input.key(event, "up") then
                    move_menu(-1)
                    return "continue"
                elseif input.key(event, "down") then
                    move_menu(1)
                    return "continue"
                elseif input.enter(event) and menu.selected then
                    accept_match(menu.selected)
                end
            end
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
                refresh_menu()
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
            menu.closed = false
            refresh_menu()
        end,
        summary = function(self, theme)
            local value = state.accepted
            if value == nil then value = editor:value() end
            return render.summary(theme, self.message, M.summary_value(theme, value, mask))
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
