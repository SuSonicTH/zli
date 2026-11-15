-- Reorder a list with keyboard moves, optional sorting and a plain fallback.

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
        error("prompt.reorder: expecting an options table", 3)
    end
    if type(options.message) ~= "string" or options.message == "" then
        error("prompt.reorder: message must be a non-empty string", 3)
    end
    if type(options.items) ~= "table" or #options.items == 0 then
        error("prompt.reorder: items must be a non-empty table", 3)
    end
    if options.default ~= nil and type(options.default) ~= "table" then
        error("prompt.reorder: default must be an array of values", 3)
    end
    if options.sort ~= nil and options.sort ~= "label" and options.sort ~= false then
        error("prompt.reorder: sort must be 'label' or false", 3)
    end
end

local function initial_order(items, default)
    local order = {}
    local used = {}
    if type(default) == "table" then
        for _, value in ipairs(default) do
            local index = items_mod.find(items, value)
            if index and not used[index] then
                order[#order + 1] = index
                used[index] = true
            end
        end
    end
    for _, item in ipairs(items) do
        if not used[item.index] then order[#order + 1] = item.index end
    end
    return order
end

local function sort_label(items, order, direction)
    table.sort(order, function(left, right)
        local a = items[left].label:lower()
        local b = items[right].label:lower()
        if a == b then return left < right end
        if direction == "desc" then return a > b end
        return a < b
    end)
end

local function make_field(options, field_options)
    field_options = field_options or {}
    validate_options(options)
    local items = items_mod.normalize(options.items)
    local show_help = field_options.show_help ~= false
    local order = initial_order(items, options.default)
    local direction = nil
    if options.sort == "label" then
        direction = "asc"
        sort_label(items, order, direction)
    end
    local baseline = {}
    for index, value in ipairs(order) do baseline[index] = value end

    local state = { cursor = 1, width = nil, max_height = nil, error = nil }

    local function value_order()
        local values = {}
        for position, index in ipairs(order) do values[position] = items[index].value end
        return values
    end

    local function cursor_item()
        local index = order[state.cursor]
        if index == nil then return nil end
        return items[index]
    end

    local function move_cursor(delta)
        local count = #order
        if count == 0 then return end
        state.cursor = state.cursor + delta
        if state.cursor > count then state.cursor = 1 end
        if state.cursor < 1 then state.cursor = count end
    end

    local function move_item(delta)
        local target = state.cursor + delta
        if target < 1 or target > #order then return end
        order[state.cursor], order[target] = order[target], order[state.cursor]
        state.cursor = target
    end

    local function reset()
        for index, value in ipairs(baseline) do order[index] = value end
        state.cursor = math.max(1, math.min(state.cursor, #order))
        direction = options.sort == "label" and "asc" or nil
    end

    local function sort_cycle()
        if direction == "asc" then
            direction = "desc"
        elseif direction == "desc" then
            direction = "asc"
        else
            direction = "asc"
        end
        local current = order[state.cursor]
        sort_label(items, order, direction)
        if current then
            for position, index in ipairs(order) do
                if index == current then state.cursor = position break end
            end
        end
    end

    local function build(theme)
        local size = term.size() or { columns = 80, rows = 24 }
        local width = state.width or size.columns
        local rows = state.max_height or size.rows
        local overhead = 1 + (direction and 1 or 0) + (show_help and 1 or 0) + 1
        local available = math.max(1, rows - overhead)
        local total = #order
        local body_height
        if total > available then
            body_height = math.max(1, available - 2)
        else
            body_height = math.max(1, total)
        end
        local top = state.top or 1
        if state.cursor < top then top = state.cursor end
        if state.cursor > top + body_height - 1 then top = state.cursor - body_height + 1 end
        top = math.max(1, math.min(top, math.max(1, total - body_height + 1)))
        state.top = top

        local reserve_top = top > 1
        local reserve_bottom = top + body_height - 1 < total

        local lines = {
            render.line(render.span("? ", "accent"), render.span(options.message, "message")),
        }
        if direction then
            lines[#lines + 1] = render.line(
                render.span("  sort: label ", "muted"),
                render.span(
                    direction == "asc" and theme.symbol("arrow_up") or theme.symbol("arrow_down"),
                    "accent"
                )
            )
        end
        if reserve_top then
            lines[#lines + 1] = render.line(
                render.span("  " .. theme.symbol("arrow_up") .. " more", "muted")
            )
        end

        for position = top, math.min(#order, top + body_height - 1) do
            local item = items[order[position]]
            local selected = position == state.cursor
            local spans = {
                render.span("  ", nil),
                render.span(
                    selected and theme.symbol("move") or " ",
                    selected and "selected" or "accent"
                ),
                render.span(" ", selected and "selected" or nil),
                render.span(item.label, selected and "selected" or nil),
            }
            if item.description then
                spans[#spans + 1] = render.span(
                    "  " .. item.description,
                    selected and "selected_muted" or "muted"
                )
            end
            lines[#lines + 1] = render.clip(spans, width, theme)
        end

        if reserve_bottom then
            lines[#lines + 1] = render.line(
                render.span("  " .. theme.symbol("arrow_down") .. " more", "muted")
            )
        end
        if show_help then
            lines[#lines + 1] = field_mod.help_line(
                "alt+up/down move  g/G first/last  s sort  r reset  enter accept  esc cancel"
            )
        end
        return render.frame(lines)
    end

    local function on_event(event)
        if event.type ~= "key" then return "continue" end
        if input.cancel(event) then return "cancel" end
        state.error = nil
        local move_up = input.key(event, "up") and (event.alt or event.control)
        local move_down = input.key(event, "down") and (event.alt or event.control)
        if move_up then
            move_item(-1)
            return "continue"
        elseif move_down then
            move_item(1)
            return "continue"
        elseif input.key(event, "up") then
            move_cursor(-1)
            return "continue"
        elseif input.key(event, "down") then
            move_cursor(1)
            return "continue"
        elseif input.key(event, "home") then
            state.cursor = 1
            return "continue"
        elseif input.key(event, "end") then
            state.cursor = #order
            return "continue"
        elseif input.key(event, "page_up") then
            move_cursor(-math.max(1, math.floor((term.size() or { rows = 24 }).rows / 4)))
            return "continue"
        elseif input.key(event, "page_down") then
            move_cursor(math.max(1, math.floor((term.size() or { rows = 24 }).rows / 4)))
            return "continue"
        elseif input.enter(event) then
            return "submit", value_order()
        elseif input.key(event, "char") and event.char == "g" then
            state.cursor = 1
            return "continue"
        elseif input.key(event, "char") and event.char == "G" then
            state.cursor = #order
            return "continue"
        elseif input.key(event, "char") and event.char == "s" then
            sort_cycle()
            return "continue"
        elseif input.key(event, "char") and event.char == "r" then
            reset()
            return "continue"
        end
        return "continue"
    end

    local field
    field = field_mod.new {
        type = "reorder",
        options = options,
        message = options.message,
        draw_active = function(self, width, theme)
            state.width = width
            state.max_height = self.max_height
            return build(theme)
        end,
        draw_compact = function(self, theme)
            local item = cursor_item()
            return render.summary(theme, self.message, item and item.label or "none")
        end,
        handle = function(self, event)
            local action, value = on_event(event)
            self.error = state.error
            return action, value
        end,
        value = function()
            return value_order()
        end,
        set_value = function(_, value)
            state.error = nil
            if type(value) ~= "table" then return end
            local next_order = initial_order(items, value)
            for index, index_value in ipairs(next_order) do order[index] = index_value end
            state.cursor = 1
        end,
        summary = function(self, theme)
            local item = cursor_item()
            return render.summary(theme, self.message, item and item.label or "none")
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

local function fallback_reorder(options)
    local items = items_mod.normalize(options.items)
    local order = initial_order(items, options.default)
    if options.sort == "label" then sort_label(items, order, "asc") end
    local shown = {}
    for index, item_index in ipairs(order) do
        shown[index] = tostring(items[item_index].label)
    end

    io.write("? " .. options.message .. "\n")
    for index, item_index in ipairs(order) do
        io.write(string.format("  %d) %s\n", items[item_index].index, shown[index]))
    end
    local default = table.concat(order, " ")
    io.write("order [" .. default .. "]: ")

    while true do
        local line = io.read("l")
        if line == nil then
            local policy = config.get("eof")
            if policy == "error" then
                error("prompt: end of input while waiting for an answer", 3)
            end
            if policy ~= "nil" and options.default ~= nil then
                local values = {}
                for index, item_index in ipairs(order) do
                    values[index] = items[item_index].value
                end
                return values
            end
            return nil, "eof"
        end
        io.write("\n")
        line = (line:gsub("^%s+", ""):gsub("%s+$", ""))
        local permutation = {}
        local seen = {}
        local valid = true
        if line == "" then
            for index, value in ipairs(order) do permutation[index] = value end
        else
            for token in line:gmatch("[^,%s]+") do
                local number = tonumber(token)
                if number == nil or not items[number] then
                    io.write("Unknown choice '" .. token .. "'.\n")
                    valid = false
                    break
                end
                if seen[number] then
                    io.write("Choice " .. number .. " is repeated.\n")
                    valid = false
                    break
                end
                seen[number] = true
                permutation[#permutation + 1] = number
            end
            if valid and #permutation ~= #order then
                io.write("Enter every item exactly once.\n")
                valid = false
            end
        end
        if valid then
            local values = {}
            for index, item_index in ipairs(permutation) do values[index] = items[item_index].value end
            return values
        end
        io.write("order: ")
    end
end

function M.__call(_, options)
    if not config.is_interactive() then
        validate_options(options)
        return fallback_reorder(options)
    end
    return M.run(options)
end

return setmetatable(M, { __call = function(_, options) return M.__call(M, options) end })
