-- Compact multi-select grid with two-dimensional navigation.

local config = require "prompt.config"
local field_mod = require "prompt.field"
local input = require "prompt.input"
local items_mod = require "prompt.items"
local render = require "prompt.render"
local term = require "term"
local theme_mod = require "prompt.theme"

local M = {}

local function validate_options(options)
    if type(options) ~= "table" then
        error("prompt.grid: expecting an options table", 3)
    end
    if type(options.message) ~= "string" or options.message == "" then
        error("prompt.grid: message must be a non-empty string", 3)
    end
    if type(options.items) ~= "table" or #options.items == 0 then
        error("prompt.grid: items must be a non-empty table", 3)
    end
    if options.columns ~= nil and options.columns ~= "auto"
        and (type(options.columns) ~= "number" or options.columns < 1)
    then
        error("prompt.grid: columns must be 'auto' or a positive number", 3)
    end
    if options.min ~= nil and (type(options.min) ~= "number" or options.min < 0) then
        error("prompt.grid: min must be a non-negative number", 3)
    end
    if options.max ~= nil and (type(options.max) ~= "number" or options.max < 1) then
        error("prompt.grid: max must be a positive number", 3)
    end
    if options.min and options.max and options.min > options.max then
        error("prompt.grid: min must not exceed max", 3)
    end
end

local function make_field(options, field_options)
    field_options = field_options or {}
    validate_options(options)
    local items = items_mod.normalize(options.items)
    local show_help = field_options.show_help ~= false
    local state = {
        checked = items_mod.default_set(items, options.default, options.default_indices),
        selected = items_mod.first_enabled(items),
        width = nil,
        max_height = nil,
        error = nil,
    }

    local function item_at(index)
        return items[index]
    end

    local function layout(width)
        local columns = width or (term.size() and term.size().columns) or 80
        local label_width = 1
        for _, item in ipairs(items) do
            local label = term.width(item.label)
            if label > label_width then label_width = label end
        end
        local cell_width = label_width + 4
        local count
        if options.columns == nil or options.columns == "auto" then
            count = math.max(1, math.floor((columns - 2) / (cell_width + 2)))
        else
            count = math.floor(options.columns)
        end
        count = math.max(1, math.min(count, #items))
        return count, cell_width
    end

    local function move(delta)
        if #items == 0 then return end
        local position = state.selected or 1
        for _ = 1, #items do
            position = position + delta
            if position > #items then position = 1 end
            if position < 1 then position = #items end
            if not items[position].disabled then
                state.selected = position
                return
            end
        end
    end

    local function vertical(delta)
        local columns = layout(state.width)
        move(delta * columns)
    end

    local function toggle()
        local item = item_at(state.selected)
        if item == nil or item.disabled then return end
        if state.checked[item.index] then
            state.checked[item.index] = nil
        else
            state.checked[item.index] = true
        end
    end

    local function checked_count()
        local count = 0
        for _ in pairs(state.checked) do count = count + 1 end
        return count
    end

    local function minimum()
        if options.required then return math.max(1, options.min or 0) end
        return options.min or 0
    end

    local function build(theme)
        local size = term.size() or { columns = 80, rows = 24 }
        local columns = state.width or size.columns
        local rows = state.max_height or size.rows
        local count, cell_width = layout(columns)
        local row_count = math.ceil(#items / count)
        local overhead = 1 + (show_help and 1 or 0) + 1
        local available = math.max(1, rows - overhead)
        local body_height
        if row_count > available then
            body_height = math.max(1, available - 2)
        else
            body_height = math.max(1, row_count)
        end

        local selected_row = math.floor(((state.selected or 1) - 1) / count) + 1
        local top = state.top or 1
        if selected_row < top then top = selected_row end
        if selected_row > top + body_height - 1 then top = selected_row - body_height + 1 end
        top = math.max(1, math.min(top, math.max(1, row_count - body_height + 1)))
        state.top = top

        local reserve_top = top > 1
        local reserve_bottom = top + body_height - 1 < row_count

        local lines = {
            render.line(render.span("? ", "accent"), render.span(options.message, "message")),
        }
        if reserve_top then
            lines[#lines + 1] = render.line(
                render.span("  " .. theme.symbol("arrow_up") .. " more", "muted")
            )
        end

        for row = top, math.min(row_count, top + body_height - 1) do
            local spans = { render.span("  ", nil) }
            for column = 1, count do
                local index = (row - 1) * count + column
                local item = items[index]
                if item then
                    local selected = index == state.selected
                    local checked = state.checked[item.index]
                    local cell = {
                        render.span(
                            selected and theme.symbol("pointer") or " ",
                            selected and "selected" or "accent"
                        ),
                        render.span(" ", selected and "selected" or nil),
                        render.span(
                            checked and theme.symbol("checked") or theme.symbol("unchecked"),
                            selected and "selected" or (checked and "accent" or "muted")
                        ),
                        render.span(" ", selected and "selected" or nil),
                        render.span(
                            item.label,
                            selected and "selected" or (item.disabled and "muted" or nil)
                        ),
                    }
                    cell = render.pad(cell, cell_width)
                    for _, span in ipairs(cell) do spans[#spans + 1] = span end
                    if column < count then spans[#spans + 1] = render.span("  ", nil) end
                end
            end
            lines[#lines + 1] = render.clip(spans, columns, theme)
        end

        if reserve_bottom then
            lines[#lines + 1] = render.line(
                render.span("  " .. theme.symbol("arrow_down") .. " more", "muted")
            )
        end
        if show_help then
            lines[#lines + 1] = field_mod.help_line(
                "arrows move  space toggle  a all  i invert  n none  enter done  esc cancel"
            )
        end
        return render.frame(lines)
    end

    local function on_event(event)
        if event.type ~= "key" then return "continue" end
        if input.cancel(event) then return "cancel" end
        state.error = nil
        if input.key(event, "left") then
            move(-1)
            return "continue"
        elseif input.key(event, "right") then
            move(1)
            return "continue"
        elseif input.key(event, "up") then
            vertical(-1)
            return "continue"
        elseif input.key(event, "down") then
            vertical(1)
            return "continue"
        elseif input.key(event, "home") then
            state.selected = items_mod.first_enabled(items)
            return "continue"
        elseif input.key(event, "end") then
            for index = #items, 1, -1 do
                if not items[index].disabled then state.selected = index break end
            end
            return "continue"
        elseif input.key(event, "page_up") then
            vertical(-math.max(1, math.floor((term.size() or { rows = 24 }).rows / 4)))
            return "continue"
        elseif input.key(event, "page_down") then
            vertical(math.max(1, math.floor((term.size() or { rows = 24 }).rows / 4)))
            return "continue"
        elseif input.enter(event) then
            local count = checked_count()
            if count < minimum() then
                state.error = "Choose at least " .. minimum() .. "."
                return "continue"
            end
            if options.max and count > options.max then
                state.error = "Choose at most " .. options.max .. "."
                return "continue"
            end
            return "submit", items_mod.selected_values(items, state.checked)
        elseif input.key(event, "char") and event.char == " " then
            toggle()
            return "continue"
        elseif input.key(event, "char") and event.char == "a" then
            for _, item in ipairs(items) do
                if not item.disabled then state.checked[item.index] = true end
            end
            return "continue"
        elseif input.key(event, "char") and event.char == "i" then
            for _, item in ipairs(items) do
                if not item.disabled then
                    state.checked[item.index] = not state.checked[item.index] or nil
                end
            end
            return "continue"
        elseif input.key(event, "char") and event.char == "n" then
            state.checked = {}
            return "continue"
        end
        return "continue"
    end

    local field
    field = field_mod.new {
        type = "grid",
        options = options,
        message = options.message,
        draw_active = function(self, width, theme)
            state.width = width
            state.max_height = self.max_height
            return build(theme)
        end,
        draw_compact = function(self, theme)
            local count = checked_count()
            local label = count == 0 and "none" or count .. " selected"
            return render.summary(theme, self.message, label)
        end,
        handle = function(self, event)
            local action, value = on_event(event)
            self.error = state.error
            return action, value
        end,
        value = function()
            return items_mod.selected_values(items, state.checked)
        end,
        set_value = function(_, value)
            state.error = nil
            local checked = {}
            local values = type(value) == "table" and value or { value }
            for _, candidate in ipairs(values) do
                local index = items_mod.find(items, candidate)
                if index and not items[index].disabled then checked[index] = true end
            end
            state.checked = checked
        end,
        summary = function(self, theme)
            local count = checked_count()
            local label = count == 0 and "none" or count .. " selected"
            return render.summary(theme, self.message, label)
        end,
        close = function() end,
    }

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
        return require("prompt.select").multiselect(options)
    end
    return M.run(options)
end

return setmetatable(M, { __call = function(_, options) return M.__call(M, options) end })
