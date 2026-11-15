-- Ranked search over a list with optional preview.
--
-- The query is edited with the shared line editor, so cursor, word and delete
-- keys behave as in `prompt.text`.  Matching is fuzzy by default; matched byte
-- ranges are highlighted with the theme's `match` and `selected_match` tokens.

local config = require "prompt.config"
local fallback = require "prompt.fallback"
local field_mod = require "prompt.field"
local fuzzy = require "prompt.fuzzy"
local input = require "prompt.input"
local items_mod = require "prompt.items"
local render = require "prompt.render"
local theme_mod = require "prompt.theme"

local editor_mod = require "prompt_editor"

local M = {}

local function validate_options(options)
    if type(options) ~= "table" then
        error("prompt.search: expecting an options table", 3)
    end
    if type(options.message) ~= "string" or options.message == "" then
        error("prompt.search: message must be a non-empty string", 3)
    end
    if type(options.items) ~= "table" then
        error("prompt.search: items must be a table", 3)
    end
    if options.filter ~= nil
        and options.filter ~= false
        and options.filter ~= "fuzzy"
        and options.filter ~= "substring"
    then
        error("prompt.search: filter must be 'fuzzy', 'substring' or false", 3)
    end
    if options.limit ~= nil and (type(options.limit) ~= "number" or options.limit < 1) then
        error("prompt.search: limit must be a positive number", 3)
    end
    if options.preview ~= nil
        and options.preview ~= false
        and type(options.preview) ~= "function"
    then
        error("prompt.search: preview must be a function", 3)
    end
end

local function normalize(items)
    local result = items_mod.normalize(items)
    for index, item in ipairs(result) do
        local original = items[index]
        if type(original) == "table" and original.keywords ~= nil then
            local keywords = original.keywords
            if type(keywords) == "table" then keywords = table.concat(keywords, " ") end
            item.search = item.search .. " " .. tostring(keywords):lower()
        end
        item.source = original
    end
    return result
end

local function prepare_preview(value, width, height)
    if value == nil then return {} end
    if type(value) == "string" then
        value = { value }
    elseif type(value) == "table" and value.text ~= nil then
        value = { value }
    end
    if type(value) ~= "table" then return {} end

    local lines = {}
    for _, line in ipairs(value) do
        if type(line) == "string" then
            for _, wrapped in ipairs(render.wrap_spans({ { text = line } }, width)) do
                lines[#lines + 1] = wrapped
            end
        elseif type(line) == "table" and line.text ~= nil then
            for _, wrapped in ipairs(render.wrap_spans({ line }, width)) do
                lines[#lines + 1] = wrapped
            end
        elseif type(line) == "table" then
            lines[#lines + 1] = render.line(line)
        else
            lines[#lines + 1] = render.line(tostring(line))
        end
    end
    while #lines > height do table.remove(lines) end
    return lines
end

local function default_item_index(items, options, return_index)
    if options.default_index ~= nil then
        local index = items_mod.find_index(items, options.default_index)
        if index and not items[index].disabled then return index end
    end
    if return_index and type(options.default) == "number" then
        local index = items[options.default] and options.default or nil
        if index and not items[index].disabled then return index end
        return nil
    end
    if options.default ~= nil then
        local index = items_mod.find(items, options.default)
        if index and not items[index].disabled then return index end
    end
    return nil
end

local function make_field(options, field_options)
    field_options = field_options or {}
    local items = normalize(options.items)
    local limit = math.floor(options.limit or 10)
    local filter = options.filter
    if filter == nil then filter = "fuzzy" end
    local preview = options.preview
    if preview == false then preview = nil end
    local return_index = options.return_index == true
    local show_help = field_options.show_help ~= false

    local editor = editor_mod.new(40, 1, {
        single_line = true,
        submit_on_enter = false,
    })
    local state = { matches = {}, position = 1, error = nil, max_height = nil }
    local width

    local function query()
        return editor:value()
    end

    local function refresh(keep_index)
        local needle = query()
        local matches
        if needle == "" or filter == false then
            matches = {}
            for _, item in ipairs(items) do
                matches[#matches + 1] = {
                    item = item, label = item.label, ranges = {}, index = item.index,
                }
            end
        elseif filter == "substring" then
            matches = {}
            local lowered = needle:lower()
            for _, item in ipairs(items) do
                local found = item.search:find(lowered, 1, true)
                if found then
                    local label_found = item.label:lower():find(lowered, 1, true)
                    local ranges = {}
                    if label_found then
                        ranges[1] = { label_found, label_found + #lowered - 1 }
                    end
                    matches[#matches + 1] = {
                        item = item, label = item.label, ranges = ranges, index = item.index,
                    }
                end
            end
        else
            matches = fuzzy.filter(items, needle)
        end
        local kept = {}
        for index = 1, math.min(#matches, limit) do kept[index] = matches[index] end
        if keep_index ~= nil then
            local present = false
            for _, match in ipairs(kept) do
                if match.item.index == keep_index then present = true break end
            end
            if not present then
                for _, match in ipairs(matches) do
                    if match.item.index == keep_index and not match.item.disabled then
                        kept[#kept + 1] = match
                        break
                    end
                end
            end
        end
        state.matches = kept
        if #kept == 0 then
            state.position = 0
        elseif state.position < 1 or state.position > #kept
            or kept[state.position].item.disabled
        then
            state.position = 0
            for position, match in ipairs(kept) do
                if not match.item.disabled then
                    state.position = position
                    break
                end
            end
        end
        return kept
    end

    local function resolve_value(value)
        if return_index and type(value) == "number" then
            local index = items[value] and value or nil
            if index and not items[index].disabled then return index end
            return nil
        end
        local index = items_mod.find(items, value)
        if index and not items[index].disabled then return index end
        return nil
    end

    local function select_index(index)
        if index == nil then return false end
        for position, match in ipairs(state.matches) do
            if match.item.index == index then
                state.position = position
                return true
            end
        end
        return false
    end

    local function move(delta)
        local count = #state.matches
        if count == 0 then return end
        local position = state.position
        if position == nil or position < 1 then position = 0 end
        for _ = 1, count do
            position = position + delta
            if position > count then position = 1 end
            if position < 1 then position = count end
            if not state.matches[position].item.disabled then
                state.position = position
                return
            end
        end
    end

    local function current()
        local match = state.matches[state.position]
        if match == nil then return nil end
        return match.item
    end

    local function available_page()
        local size = require("term").size() or { rows = 24 }
        return math.max(1, size.rows - 6)
    end

    local function page_move(delta)
        local position = state.position
        if position == nil or position < 1 then
            move(delta > 0 and 1 or -1)
        else
            move(delta * available_page())
        end
    end

    local function build(theme)
        local size = require("term").size() or { columns = 80, rows = 24 }
        local columns = width or size.columns
        local rows = state.max_height or size.rows
        local editor_columns = math.max(1, columns - 5)
        editor:resize(editor_columns, 1)

        local lines = {
            render.line(render.span("? ", "accent"), render.span(options.message, "message")),
        }
        local cursor
        if filter ~= false then
            if editor:len() == 0 then
                lines[#lines + 1] = render.line(
                    render.span("  > ", "accent"),
                    render.span("type to search", "muted")
                )
                cursor = { row = 2, column = 4 }
            else
                local rows, position = editor:render()
                local spans = { render.span("  > ", "accent") }
                for _, span in ipairs(rows[1] or {}) do spans[#spans + 1] = span end
                lines[#lines + 1] = spans
                cursor = { row = 2, column = 4 + (position and position.column or 0) }
            end
        end

        local preview_enabled = type(preview) == "function" and columns >= 72
        local left_width = columns - 2
        local preview_width = 0
        if preview_enabled then
            left_width = math.max(20, math.min(46, math.floor(columns * 0.45)))
            preview_width = math.max(1, columns - left_width - 3)
        end

        local overhead = 1 + (filter ~= false and 1 or 0) + (show_help and 1 or 0) + 1
        local available = math.max(1, rows - overhead)
        local total = #state.matches
        local body_height
        if total > available then
            body_height = math.max(1, available - 2)
        else
            body_height = math.max(1, total)
        end
        local top = 1
        if state.position > body_height then top = state.position - body_height + 1 end
        if top > total - body_height + 1 then top = total - body_height + 1 end
        top = math.max(1, top)
        local reserve_top = top > 1
        local reserve_bottom = top + body_height - 1 < total

        local body = {}
        if #state.matches == 0 then
            body[1] = render.line(render.span("  no matches", "muted"))
        else
            for row = 1, body_height do
                local index = top + row - 1
                local match = state.matches[index]
                if match then
                    local selected = index == state.position
                    local spans = {
                        render.span("  ", nil),
                        render.span(
                            selected and theme.symbol("pointer") or " ",
                            selected and "selected" or "accent"
                        ),
                        render.span(" ", selected and "selected" or nil),
                    }
                    local highlighted = fuzzy.highlight(
                        match.label or match.item.label,
                        match.ranges,
                        selected and "selected_match" or "match"
                    )
                    for _, span in ipairs(highlighted) do
                        if span.style == nil and selected then
                            spans[#spans + 1] = render.span(span.text, "selected")
                        else
                            spans[#spans + 1] = { text = span.text, style = span.style }
                        end
                    end
                    if match.item.description then
                        spans[#spans + 1] = render.span(
                            "  " .. match.item.description,
                            selected and "selected_muted" or "muted"
                        )
                    end
                    body[#body + 1] = spans
                end
            end
        end

        if reserve_top then
            lines[#lines + 1] = render.line(
                render.span("  " .. theme.symbol("arrow_up") .. " more", "muted")
            )
        end

        if preview_enabled then
            local selected = state.matches[state.position]
            local preview_lines = {}
            if selected then
                preview_lines = prepare_preview(
                    preview(selected.item, preview_width, body_height),
                    preview_width,
                    body_height
                )
            end
            for row = 1, #body do
                local left = render.pad(
                    render.clip(body[row] or {}, left_width, theme),
                    left_width
                )
                local spans = {}
                for _, span in ipairs(left) do spans[#spans + 1] = span end
                spans[#spans + 1] = render.span(" | ", "border")
                for _, span in ipairs(preview_lines[row] or {}) do
                    spans[#spans + 1] = span
                end
                lines[#lines + 1] = render.clip(spans, columns, theme)
            end
        else
            for row = 1, #body do
                lines[#lines + 1] = render.clip(body[row] or {}, columns, theme)
            end
        end

        if reserve_bottom then
            lines[#lines + 1] = render.line(
                render.span("  " .. theme.symbol("arrow_down") .. " more", "muted")
            )
        end

        if show_help then
            lines[#lines + 1] = field_mod.help_line(filter == false
                and "up/down move  enter select  esc cancel"
                or "type to search  up/down move  enter select  esc clear/cancel")
        end
        return render.frame(lines, cursor)
    end

    local field
    field = field_mod.new {
        type = "search",
        options = options,
        message = options.message,
        draw_active = function(self, requested, theme)
            state.max_height = self.max_height
            width = requested
            return build(theme)
        end,
        draw_compact = function(self, theme)
            local item = current()
            local label = item and item.label or "none"
            return render.summary(theme, self.message, label)
        end,
        handle = function(self, event)
            local function on_event(current_event)
                if current_event.type == "paste" then
                    if filter ~= false then
                        editor:feed(current_event)
                        refresh()
                    end
                    self.error = nil
                    return "continue"
                end
                if current_event.type ~= "key" then return "continue" end
                if input.cancel(current_event) then
                    if input.key(current_event, "esc") and query() ~= "" then
                        editor:set_text("")
                        refresh()
                        self.error = nil
                        return "continue"
                    end
                    return "cancel"
                end
                if input.key(current_event, "up") then
                    move(-1)
                    self.error = nil
                    return "continue"
                elseif input.key(current_event, "down") then
                    move(1)
                    self.error = nil
                    return "continue"
                elseif input.key(current_event, "page_up") then
                    page_move(-1)
                    self.error = nil
                    return "continue"
                elseif input.key(current_event, "page_down") then
                    page_move(1)
                    self.error = nil
                    return "continue"
                elseif input.enter(current_event) then
                    local item = current()
                    if item == nil then
                        self.error = "No matching item."
                        return "continue"
                    end
                    if item.disabled then
                        self.error = "That item is disabled."
                        return "continue"
                    end
                    return "submit", return_index and item.index or item.value
                end
                if filter == false then return "continue" end
                local action = editor:feed(current_event)
                if action == "abort" then return "cancel" end
                if action == "eof" then return "eof" end
                refresh()
                self.error = nil
                return "continue"
            end
            return on_event(event)
        end,
        value = function()
            local item = current()
            if item == nil then return nil end
            if return_index then return item.index end
            return item.value
        end,
        set_value = function(_, value)
            state.error = nil
            local index = resolve_value(value)
            if index then
                if filter ~= false then editor:set_text(items[index].label) end
                refresh(index)
                select_index(index)
            else
                if filter ~= false then editor:set_text("") end
                refresh()
                state.position = 0
            end
        end,
        summary = function(self, theme)
            local item = current()
            local label = item and item.label or "none"
            return render.summary(theme, self.message, label)
        end,
        close = function()
            editor:close()
        end,
    }

    local explicit_default = options.default ~= nil or options.default_index ~= nil
    local default_index = default_item_index(items, options, return_index)
    refresh(default_index)
    if default_index then
        select_index(default_index)
    elseif explicit_default then
        state.position = 0
    end
    return field
end

function M.new_field(options, field_options)
    return make_field(options, field_options)
end

function M.run(options)
    local theme = theme_mod.build()
    local field = make_field(options)
    local packed = table.pack(input.run {
        screen = options.screen,
        commit = options.commit,
        frame = function() return field:frame(nil, theme) end,
        on_event = function(event) return field:handle(event) end,
        summary = function() return field:summary(theme) end,
        final_frame = function() return field:frame(nil, theme) end,
    })
    field:close()
    return table.unpack(packed, 1, packed.n)
end

function M.__call(_, options)
    validate_options(options)
    if not config.is_interactive() then
        local items = normalize(options.items)
        local selected = default_item_index(items, options, options.return_index == true)
        if selected == nil and options.default == nil and options.default_index == nil then
            selected = items_mod.first_enabled(items)
        end
        return fallback.select(options, items, selected)
    end
    return M.run(options)
end

return setmetatable(M, { __call = function(_, options) return M.__call(M, options) end })
