-- Sortable data table viewer and row picker.

local config = require "prompt.config"
local field_mod = require "prompt.field"
local input = require "prompt.input"
local render = require "prompt.render"
local scroll = require "prompt.scroll"
local term = require "term"
local theme_mod = require "prompt.theme"

local M = {}

local max_column_width = 32

local function check_column(column, index)
    if type(column) ~= "table" then
        error("prompt.table: column " .. index .. " must be a table", 3)
    end
    if type(column.name) ~= "string" or column.name == "" then
        error("prompt.table: column " .. index .. " needs a name", 3)
    end
    if column.title ~= nil and type(column.title) ~= "string" then
        error("prompt.table: column '" .. column.name .. "' title must be a string", 3)
    end
    if column.width ~= nil and (type(column.width) ~= "number" or column.width < 1) then
        error("prompt.table: column '" .. column.name .. "' width must be a positive number", 3)
    end
    if column.align ~= nil
        and column.align ~= "left"
        and column.align ~= "right"
        and column.align ~= "center"
    then
        error("prompt.table: column '" .. column.name .. "' align must be 'left', 'right' or 'center'", 3)
    end
    if column.format ~= nil and type(column.format) ~= "function" then
        error("prompt.table: column '" .. column.name .. "' format must be a function", 3)
    end
end

local function validate_options(options)
    if type(options) ~= "table" then
        error("prompt.table: expecting an options table", 3)
    end
    if type(options.message) ~= "string" or options.message == "" then
        error("prompt.table: message must be a non-empty string", 3)
    end
    if type(options.columns) ~= "table" or #options.columns == 0 then
        error("prompt.table: columns must be a non-empty table", 3)
    end
    for index, column in ipairs(options.columns) do check_column(column, index) end
    if type(options.rows) ~= "table" then
        error("prompt.table: rows must be a table", 3)
    end
    for index, row in ipairs(options.rows) do
        if type(row) ~= "table" then
            error("prompt.table: row " .. index .. " must be a table", 3)
        end
    end
    if options.page_size ~= nil
        and (type(options.page_size) ~= "number" or options.page_size < 1)
    then
        error("prompt.table: page_size must be a positive number", 3)
    end
    if options.sort ~= nil
        and type(options.sort) ~= "boolean"
        and type(options.sort) ~= "string"
        and type(options.sort) ~= "number"
    then
        error("prompt.table: sort must be a boolean, column name or column index", 3)
    end
    for _, name in ipairs { "select", "return_index" } do
        if options[name] ~= nil and type(options[name]) ~= "boolean" then
            error("prompt.table: " .. name .. " must be a boolean", 3)
        end
    end
end

local function cell_text(row, column)
    local value = row[column.name]
    if column.format then value = column.format(value, row, column) end
    if value == nil then return "" end
    return (tostring(value):gsub("[\r\n]+", " "))
end

local function fit_text(text, width, align, theme)
    local used = term.width(text)
    if used > width then
        text = term.truncate(text, width, theme and theme.symbol("ellipsis") or "...")
        used = term.width(text)
    end
    local gap = width - used
    if gap <= 0 then return text end
    if align == "right" then
        return string.rep(" ", gap) .. text
    elseif align == "center" then
        local left = math.floor(gap / 2)
        return string.rep(" ", left) .. text .. string.rep(" ", gap - left)
    end
    return text .. string.rep(" ", gap)
end

local function column_widths(columns, rows)
    local widths = {}
    for index, column in ipairs(columns) do
        local width = column.width
        if width == nil then
            width = term.width(column.title or column.name) + 2
            for _, row in ipairs(rows) do
                local used = term.width(cell_text(row, column))
                if used > width then width = used end
            end
            width = math.max(3, math.min(width, max_column_width))
        else
            width = math.floor(width)
        end
        widths[index] = width
    end
    return widths
end

local compare_type_order = { number = 1, string = 2, boolean = 3 }

local function compare_values(left, right)
    if left == nil and right == nil then return false end
    if left == nil then return false end
    if right == nil then return true end
    local left_type, right_type = type(left), type(right)
    if left_type ~= right_type then
        local left_rank = compare_type_order[left_type] or 4
        local right_rank = compare_type_order[right_type] or 4
        if left_rank ~= right_rank then return left_rank < right_rank end
    end
    if left_type == "number" or left_type == "string" then return left < right end
    if left_type == "boolean" then return not left and right end
    return tostring(left):lower() < tostring(right):lower()
end

local function sort_column_index(options, value)
    if value == nil or value == false or value == true then return nil end
    if type(value) == "number" then
        if value < 1 or value > #options.columns then
            error("prompt.table: sort column index is out of range", 3)
        end
        return math.floor(value)
    end
    for index, column in ipairs(options.columns) do
        if column.name == value then return index end
    end
    error("prompt.table: unknown sort column '" .. tostring(value) .. "'", 3)
end

local function make_field(options, field_options)
    field_options = field_options or {}
    validate_options(options)
    local columns = options.columns
    local rows = options.rows
    local show_help = field_options.show_help ~= false
    local is_picker = options.select ~= false
    local return_index = options.return_index == true
    local sort_enabled = options.sort ~= false
    local page_size = math.floor(options.page_size or config.get("page_size"))
    local widths = column_widths(columns, rows)

    local state = {
        order = {},
        selected = #rows > 0 and 1 or nil,
        focus_column = 1,
        left_column = 1,
        sort_column = sort_column_index(options, options.sort),
        sort_direction = sort_column_index(options, options.sort) and "asc" or nil,
        top = 1,
        width = nil,
        max_height = nil,
        height = 1,
        error = nil,
    }
    local initial_sort = state.sort_column

    local function rebuild_order()
        local order = {}
        for index = 1, #rows do order[index] = index end
        if state.sort_column then
            local column = columns[state.sort_column]
            local direction = state.sort_direction
            table.sort(order, function(left, right)
                local a, b = rows[left][column.name], rows[right][column.name]
                local less = compare_values(a, b)
                local greater = compare_values(b, a)
                if not less and not greater then return left < right end
                if direction == "desc" then return greater end
                return less
            end)
        end
        state.order = order
    end

    local function position_of(index)
        for position, row_index in ipairs(state.order) do
            if row_index == index then return position end
        end
        return nil
    end

    local function ensure_selected()
        if state.selected == nil then
            state.selected = state.order[1]
        elseif position_of(state.selected) == nil then
            state.selected = state.order[1]
        end
    end

    local function current_row()
        if state.selected == nil then return nil end
        return rows[state.selected]
    end

    local function move(delta)
        local count = #state.order
        if count == 0 then return end
        local position = position_of(state.selected) or (delta > 0 and 0 or count + 1)
        position = position + delta
        if position > count then position = 1 end
        if position < 1 then position = count end
        state.selected = state.order[position]
    end

    local function move_column(delta)
        local count = #columns
        local column = state.focus_column + delta
        if column > count then column = count end
        if column < 1 then column = 1 end
        state.focus_column = column
    end

    local function cycle_sort()
        if state.sort_column ~= state.focus_column then
            state.sort_column = state.focus_column
            state.sort_direction = "asc"
        elseif state.sort_direction == "asc" then
            state.sort_direction = "desc"
        elseif state.sort_direction == "desc" then
            state.sort_column = nil
            state.sort_direction = nil
        else
            state.sort_direction = "asc"
        end
        local selected = state.selected
        rebuild_order()
        if selected and position_of(selected) then state.selected = selected end
        ensure_selected()
    end

    local function window(widths, available, theme)
        local count = #columns
        local function columns_width(first, last)
            local used = 0
            for index = first, last do
                used = used + widths[index]
                if index > first then used = used + 2 end
            end
            return used
        end
        local function last_for(first)
            local last = first - 1
            local used = 0
            for index = first, count do
                local addition = widths[index] + (index > first and 2 or 0)
                local reserve = (first > 1 and 2 or 0) + (index < count and 2 or 0)
                if used + addition > math.max(1, available - reserve) then break end
                used = used + addition
                last = index
            end
            return math.max(first, last)
        end

        local focus = state.focus_column
        local first = math.max(1, math.min(state.left_column or 1, count))
        if focus < first then first = focus end
        local last = last_for(first)
        while first < focus and last < focus do
            first = first + 1
            last = last_for(first)
        end
        if last < focus then
            first = focus
            last = last_for(first)
        end
        state.left_column = first
        return first, last, columns_width(first, last)
    end

    local function visible_rows(height)
        local total = #state.order
        local top = state.top or 1
        local position = position_of(state.selected) or 1
        if position < top then top = position end
        if position > top + height - 1 then top = position - height + 1 end
        top = math.max(1, math.min(top, math.max(1, total - height + 1)))
        state.top = top
        return top, math.min(total, top + height - 1)
    end

    local function build(theme)
        local size = term.size() or { columns = 80, rows = 24 }
        local width = state.width or size.columns
        local rows_available = state.max_height or size.rows

        local overhead = 1 + (show_help and 1 or 0) + 1
        local available = math.max(1, rows_available - overhead)
        local total = #state.order
        local limit = math.min(page_size, available)
        local body_height
        if total > limit then
            body_height = math.max(1, math.min(page_size, available - 2))
        else
            body_height = math.max(1, math.min(total, available))
        end
        state.height = body_height

        local left, right = window(widths, math.max(1, width - 4), theme)
        local top, bottom = visible_rows(body_height)
        local reserve_top = top > 1
        local reserve_bottom = bottom < total

        local lines = {
            render.line(render.span("? ", "accent"), render.span(options.message, "message")),
        }
        if reserve_top then
            lines[#lines + 1] = render.line(
                render.span("  " .. theme.symbol("arrow_up") .. " more", "muted")
            )
        end

        local header = {
            render.span("  ", nil),
            render.span(left > 1 and theme.symbol("scroll_left") or " ", "muted"),
            render.span(" ", nil),
        }
        for index = left, right do
            if index > left then header[#header + 1] = render.span("  ", nil) end
            local column = columns[index]
            local marker = ""
            if state.sort_column == index then
                marker = state.sort_direction == "asc"
                    and theme.symbol("arrow_up") or theme.symbol("arrow_down")
            end
            local title = (column.title or column.name) .. (marker ~= "" and (" " .. marker) or "")
            local style = state.focus_column == index and "accent" or "muted"
            header[#header + 1] = render.span(fit_text(title, widths[index], column.align), style)
        end
        if right < #columns then
            header[#header + 1] = render.span(" " .. theme.symbol("scroll_right"), "muted")
        end
        lines[#lines + 1] = header

        for position = top, bottom do
            local row = rows[state.order[position]]
            local selected = state.order[position] == state.selected
            local style = selected and "selected" or nil
            local spans = {
                render.span("  ", nil),
                render.span(
                    selected and theme.symbol("pointer") or " ",
                    selected and "selected" or "accent"
                ),
                render.span(" ", selected and "selected" or nil),
            }
            for index = left, right do
                if index > left then spans[#spans + 1] = render.span("  ", style) end
                local column = columns[index]
                spans[#spans + 1] = render.span(
                    fit_text(cell_text(row, column), widths[index], column.align, theme),
                    style
                )
            end
            lines[#lines + 1] = render.clip(spans, width, theme)
        end

        if total == 0 then
            lines[#lines + 1] = render.line(render.span("  no rows", "muted"))
        end
        if reserve_bottom then
            lines[#lines + 1] = render.line(
                render.span("  " .. theme.symbol("arrow_down") .. " more", "muted")
            )
        end
        if show_help then
            local help = is_picker
                and "arrows move  left/right column  enter select  esc cancel"
                or "arrows move  left/right column  enter/q/esc close"
            if sort_enabled then help = help .. "  s sort" end
            lines[#lines + 1] = field_mod.help_line(help)
        end
        return render.frame(lines)
    end

    local function current_label(theme)
        local row = current_row()
        if row == nil then return "none" end
        local column = columns[1]
        local text = cell_text(row, column)
        if text == "" then text = tostring(row[column.name] or "none") end
        return text
    end

    local function selected_result()
        local row = current_row()
        if row == nil then return nil end
        if return_index then return state.selected end
        return row
    end

    local function set_selected(value)
        if value == nil then return end
        if return_index and type(value) == "number" then
            if rows[value] then
                state.selected = value
                ensure_selected()
            end
            return
        end
        for index, row in ipairs(rows) do
            if row == value then
                state.selected = index
                ensure_selected()
                return
            end
        end
        if type(value) == "number" and rows[value] then
            state.selected = value
            ensure_selected()
        end
    end

    local function on_event(event)
        if event.type ~= "key" then return "continue" end
        local quit = input.key(event, "q")
            or (input.key(event, "char") and event.char == "q")
        if not is_picker and (quit or input.cancel(event)) then
            return "submit", true
        end
        if input.cancel(event) then return "cancel" end
        if is_picker and quit then return "cancel" end

        state.error = nil
        if input.key(event, "up") then
            move(-1)
            return "continue"
        elseif input.key(event, "down") then
            move(1)
            return "continue"
        elseif input.key(event, "left") then
            move_column(-1)
            return "continue"
        elseif input.key(event, "right") then
            move_column(1)
            return "continue"
        elseif input.key(event, "home") then
            state.selected = state.order[1]
            return "continue"
        elseif input.key(event, "end") then
            state.selected = state.order[#state.order]
            return "continue"
        elseif input.key(event, "page_up") then
            move(-math.max(1, state.height))
            return "continue"
        elseif input.key(event, "page_down") then
            move(math.max(1, state.height))
            return "continue"
        elseif input.enter(event) then
            if not is_picker then return "submit", true end
            if current_row() == nil then
                state.error = "Choose a row."
                return "continue"
            end
            return "submit", selected_result()
        elseif sort_enabled and input.key(event, "char") and event.char == "s" then
            cycle_sort()
            return "continue"
        end
        return "continue"
    end

    rebuild_order()
    ensure_selected()

    local field
    field = field_mod.new {
        type = "table",
        options = options,
        message = options.message,
        draw_active = function(self, width, theme)
            state.width = width
            state.max_height = self.max_height
            return build(theme)
        end,
        draw_compact = function(self, theme)
            return render.summary(theme, self.message, current_label(theme))
        end,
        handle = function(self, event)
            local action, value = on_event(event)
            self.error = state.error
            return action, value
        end,
        value = function()
            if not is_picker then return true end
            return selected_result()
        end,
        set_value = function(_, value)
            state.error = nil
            set_selected(value)
        end,
        summary = function(self, theme)
            if not is_picker then
                return render.status(theme, "success", "closed")
            end
            return render.summary(theme, self.message, current_label(theme))
        end,
        close = function() end,
    }

    if initial_sort then
        state.sort_column = initial_sort
        state.sort_direction = "asc"
        state.selected = nil
        rebuild_order()
        ensure_selected()
    end
    if options.default ~= nil then set_selected(options.default) end

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
        eof_summary = options.select == false
            and render.status(theme, "success", "closed") or nil,
    })
    field:close()
    if options.select == false and packed[1] == nil then return true end
    return table.unpack(packed, 1, packed.n)
end

local function eof_result(default)
    local policy = config.get("eof")
    if policy == "error" then
        error("prompt: end of input while waiting for an answer", 3)
    end
    if policy == "nil" then return nil, "eof" end
    if default ~= nil then return default end
    return nil, "eof"
end

local function fallback_table(options)
    local theme = theme_mod.build()
    local columns = options.columns
    local rows = options.rows
    local picker = options.select ~= false
    local return_index = options.return_index == true
    local order = {}
    for index = 1, #rows do order[index] = index end
    local sort_column = sort_column_index(options, options.sort)
    if sort_column then
        local column = columns[sort_column]
        table.sort(order, function(left, right)
            local a, b = rows[left][column.name], rows[right][column.name]
            local less = compare_values(a, b)
            local greater = compare_values(b, a)
            if not less and not greater then return left < right end
            return less
        end)
    end

    local widths = column_widths(columns, rows)

    local default_index
    if options.default ~= nil then
        if return_index and type(options.default) == "number" and rows[options.default] then
            default_index = options.default
        else
            for index, row in ipairs(rows) do
                if row == options.default then
                    default_index = index
                    break
                end
            end
        end
    end
    local default_position
    if default_index then
        for position, row_index in ipairs(order) do
            if row_index == default_index then
                default_position = position
                break
            end
        end
    end

    io.write("? " .. options.message .. "\n")
    if #rows == 0 then
        io.write("  no rows\n")
        if not picker then return true end
        return nil, "No rows."
    end

    local function write_row(prefix, row)
        local parts = { prefix }
        for index, column in ipairs(columns) do
            if index > 1 then parts[#parts + 1] = "  " end
            parts[#parts + 1] = fit_text(cell_text(row, column), widths[index], column.align, theme)
        end
        io.write(table.concat(parts), "\n")
    end

    local number_width = #tostring(#rows)
    local header_prefix = picker and (string.rep(" ", number_width + 4)) or "  "
    local parts = { header_prefix }
    for index, column in ipairs(columns) do
        if index > 1 then parts[#parts + 1] = "  " end
        parts[#parts + 1] = fit_text(column.title or column.name, widths[index], column.align, theme)
    end
    io.write(table.concat(parts), "\n")

    for position, row_index in ipairs(order) do
        local prefix = picker
            and string.format("  %" .. number_width .. "d) ", position)
            or "  "
        write_row(prefix, rows[row_index])
    end

    if not picker then return true end

    io.write("row: ")
    while true do
        local line = io.read("l")
        if line == nil then
            local position = default_position
            local row_index = position and order[position]
            return eof_result(row_index and (return_index and row_index or rows[row_index]) or nil)
        end
        io.write("\n")
        line = (line:gsub("^%s+", ""):gsub("%s+$", ""))
        if line == "" then
            local position = default_position or 1
            local row_index = order[position]
            if row_index == nil then return nil, "No rows." end
            if return_index then return row_index end
            return rows[row_index]
        end
        local number = tonumber(line)
        if not number then
            io.write("Please choose one of the listed numbers.\n")
        else
            local position = math.floor(number)
            local row_index = order[position]
            if row_index == nil then
                io.write("Please choose one of the listed numbers.\n")
            else
                if return_index then return row_index end
                return rows[row_index]
            end
        end
        io.write("row: ")
    end
end

function M.__call(_, options)
    validate_options(options)
    if not config.is_interactive() then
        return fallback_table(options)
    end
    return M.run(options)
end

return setmetatable(M, { __call = function(_, options) return M.__call(M, options) end })
