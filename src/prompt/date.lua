-- Calendar date picker with typed entry.

local config = require "prompt.config"
local dates = require "prompt.dates"
local field_mod = require "prompt.field"
local input = require "prompt.input"
local render = require "prompt.render"
local theme_mod = require "prompt.theme"

local editor_mod = require "prompt_editor"

local M = {}

local function validate(options)
    if type(options) ~= "table" then
        error("prompt.date: expecting an options table", 3)
    end
    if type(options.message) ~= "string" or options.message == "" then
        error("prompt.date: message must be a non-empty string", 3)
    end
    if options.as ~= nil and options.as ~= "table" and options.as ~= "string" and options.as ~= "time" then
        error("prompt.date: as must be 'table', 'string' or 'time'", 3)
    end
    if options.week_start ~= nil and options.week_start ~= "monday" and options.week_start ~= "sunday" then
        error("prompt.date: week_start must be 'monday' or 'sunday'", 3)
    end
    if options.format ~= nil and type(options.format) ~= "string" then
        error("prompt.date: format must be a string", 3)
    end
end

local function term_size()
    local term = require "term"
    local size = term.size()
    if not size then return { columns = 80, rows = 24 } end
    return size
end

local function fallback_run(options, default, min_day, max_day)
    local shown = default and dates.format_date(default) or ""
    io.write("? " .. options.message .. (shown ~= "" and (" [" .. shown .. "]") or "") .. " (YYYY-MM-DD): ")
    io.flush()
    while true do
        local line = io.read("l")
        io.write("\n")
        io.flush()
        if line == nil then
            local policy = config.get("eof")
            if policy == "error" then error("prompt.date: end of input", 3) end
            if policy == "nil" then return nil, "eof" end
            return dates.to_result(default, options, false)
        end
        line = line:gsub("^%s+", ""):gsub("%s+$", "")
        local value = line == "" and default or dates.parse_date(line)
        if value == nil then
            io.write("Use YYYY-MM-DD.\n? ")
        else
            local day = dates.days_from_civil(value.year, value.month, value.day)
            if (min_day and day < min_day) or (max_day and day > max_day) then
                io.write("Date is outside the allowed range.\n? ")
            else
                return dates.to_result(value, options, false)
            end
        end
        io.flush()
    end
end

--- Build a reusable date field.
function M.new_field(options, field_options)
    field_options = field_options or {}
    validate(options)
    local show_help = field_options.show_help ~= false
    local message = field_options.message or options.message
    local min_day = dates.bounds(options.min, false)
    local max_day = dates.bounds(options.max, false)

    local parsed_default
    if options.default == nil then
        parsed_default = dates.today()
    else
        parsed_default = dates.from_value(options.default)
        if not parsed_default or not parsed_default.year then error("prompt.date: default must be a date", 3) end
    end
    local selected = dates.clamp(parsed_default, min_day, max_day)
    local state = { error = nil, width = 0, focus = false }
    local entry = editor_mod.new(20, 1, {
        initial = dates.format_date(selected),
        single_line = true,
        submit_on_enter = true,
    })

    local function current_day()
        return dates.days_from_civil(selected.year, selected.month, selected.day)
    end

    local function sync_entry()
        if not state.focus then entry:set_text(dates.format_date(selected)) end
    end

    local function set_days(days)
        if (min_day and days < min_day) or (max_day and days > max_day) then
            state.error = "Outside the allowed range."
            return false
        end
        local year, month, day = dates.civil_from_days(days)
        selected.year, selected.month, selected.day = year, month, day
        state.error = nil
        sync_entry()
        return true
    end

    local function month_grid()
        local first = dates.weekday(selected.year, selected.month, 1)
        local offset = first - 1
        if options.week_start == "sunday" then
            offset = (first % 7)
        end
        return offset, dates.days_in_month(selected.year, selected.month)
    end

    local function frame(width, max_height)
        local columns = width and math.max(1, math.floor(width)) or term_size().columns
        local entry_width = math.max(1, columns - 8)
        if entry_width ~= state.width then
            state.width = entry_width
            entry:resize(entry_width, 1)
        end

        local lines = {
            field_mod.label(message),
        }
        local title = dates.month_name(selected.month) .. " " .. selected.year
        local padding = math.max(0, math.floor((21 - #title) / 2))
        lines[#lines + 1] = render.line(render.span(string.rep(" ", padding) .. title, "title"))

        local names = dates.weekday_names()
        if options.week_start == "sunday" then
            names = { "Su", "Mo", "Tu", "We", "Th", "Fr", "Sa" }
        end
        local header = {}
        for _, name in ipairs(names) do header[#header + 1] = render.span(" " .. name, "muted") end
        lines[#lines + 1] = header

        local offset, count = month_grid()
        local week_count = math.ceil((offset + count) / 7)
        local first_week, last_week = 0, week_count - 1
        if max_height then
            local chrome = 4 + (show_help and 1 or 0)
            local budget = math.max(1, max_height - chrome)
            if week_count > budget then
                local selected_week = math.floor((offset + selected.day - 1) / 7)
                first_week = math.max(0, selected_week - math.floor((budget - 1) / 2))
                last_week = math.min(week_count - 1, first_week + budget - 1)
                first_week = math.max(0, last_week - budget + 1)
            end
        end
        local today = dates.today()
        local today_day = dates.days_from_civil(today.year, today.month, today.day)
        for week = first_week, last_week do
            local spans = {}
            for column = 1, 7 do
                local cell = week * 7 + column
                local day = cell - offset
                if day >= 1 and day <= count then
                    local value_day = dates.days_from_civil(selected.year, selected.month, day)
                    local style
                    if day == selected.day then
                        style = "selected"
                    elseif value_day == today_day then
                        style = "accent"
                    elseif (min_day and value_day < min_day) or (max_day and value_day > max_day) then
                        style = "muted"
                    end
                    spans[#spans + 1] = render.span(string.format(" %2d", day), style)
                else
                    spans[#spans + 1] = render.span("   ", nil)
                end
            end
            lines[#lines + 1] = spans
        end

        local cursor
        if state.focus then
            local rows, position = entry:render()
            local spans = { render.span("  date: ", "muted") }
            for _, span in ipairs(rows[1] or {}) do spans[#spans + 1] = span end
            lines[#lines + 1] = spans
            cursor = { row = #lines, column = 8 + ((position and position.column) or 0) }
        else
            lines[#lines + 1] = render.line(
                render.span("  date: ", "muted"),
                render.span(dates.format_date(selected), "accent")
            )
        end
        if show_help then
            lines[#lines + 1] = field_mod.help_line(
                "arrows move  PgUp/PgDn month  t today  / type  enter accept"
            )
        end
        return render.frame(lines, cursor)
    end

    local function apply_entry()
        local text = entry:value():gsub("^%s+", ""):gsub("%s+$", "")
        local parsed = dates.parse_date(text)
        if not parsed then
            state.error = "Use YYYY-MM-DD."
            return false
        end
        local ok = set_days(dates.days_from_civil(parsed.year, parsed.month, parsed.day))
        if ok then state.focus = false end
        return ok
    end

    local function on_event(event)
        if event.type == "resize" then return "continue" end
        if input.ctrl(event, "c") then return "cancel" end
        if input.key(event, "esc") then
            if state.focus then
                state.focus = false
                state.error = nil
                sync_entry()
                return "continue"
            end
            return "cancel"
        end
        if input.key(event, "tab") then
            state.focus = not state.focus
            if state.focus then entry:set_text(dates.format_date(selected)) end
            state.error = nil
            return "continue"
        end

        if state.focus then
            if event.type == "key" or event.type == "paste" then
                state.error = nil
                local action = entry:feed(event)
                if action == "submit" then
                    apply_entry()
                    return "continue"
                elseif action == "abort" then
                    return "cancel"
                end
            end
            return "continue"
        end

        if input.enter(event) then
            return "submit", dates.to_result(selected, options, false)
        end

        local char = input.printable(event)
        if char == "/" then
            state.focus = true
            entry:set_text(dates.format_date(selected))
            state.error = nil
            return "continue"
        elseif char and (char:match("%d") or char == "-") then
            state.focus = true
            entry:set_text("")
            entry:feed { type = "key", code = "char", char = char }
            state.error = nil
            return "continue"
        end

        local moved
        if input.key(event, "left") then moved = -1
        elseif input.key(event, "right") then moved = 1
        elseif input.key(event, "up") then moved = -7
        elseif input.key(event, "down") then moved = 7
        elseif input.key(event, "page_up") then
            selected = dates.add_months(selected, -1)
            local day = dates.days_from_civil(selected.year, selected.month, selected.day)
            if (min_day and day < min_day) or (max_day and day > max_day) then selected = dates.add_months(selected, 1) end
            state.error = nil
            sync_entry()
            return "continue"
        elseif input.key(event, "page_down") then
            selected = dates.add_months(selected, 1)
            local day = dates.days_from_civil(selected.year, selected.month, selected.day)
            if (min_day and day < min_day) or (max_day and day > max_day) then selected = dates.add_months(selected, -1) end
            state.error = nil
            sync_entry()
            return "continue"
        elseif input.key(event, "home") then
            local weekday = dates.weekday(selected.year, selected.month, selected.day)
            local offset = options.week_start == "sunday" and (weekday % 7) or (weekday - 1)
            moved = -offset
        elseif input.key(event, "end") then
            local weekday = dates.weekday(selected.year, selected.month, selected.day)
            local offset = options.week_start == "sunday" and (weekday % 7) or (weekday - 1)
            moved = 6 - offset
        elseif char == "t" then
            local today = dates.today()
            set_days(dates.days_from_civil(today.year, today.month, today.day))
            return "continue"
        end
        if moved then set_days(current_day() + moved) end
        return "continue"
    end

    local field
    field = field_mod.new {
        type = field_options.type or "date",
        options = options,
        message = message,
        draw_active = function(self, width)
            return frame(width, self.max_height)
        end,
        draw_compact = function(self, theme)
            return render.summary(theme, self.message, dates.format_date(selected))
        end,
        handle = function(self, event)
            local action, value = on_event(event)
            self.error = state.error
            return action, value
        end,
        commit = function(self)
            if state.focus then
                if not apply_entry() then
                    self.error = state.error
                    return false, state.error
                end
            end
            self.error = nil
            return true
        end,
        value = function()
            return dates.to_result(selected, options, false)
        end,
        set_value = function(_, value)
            local parsed = dates.from_value(value)
            if not parsed and options.as == "string" and options.format and type(value) == "string" then
                local fields = dates.parse_format(value, options.format)
                if fields and fields.month and fields.day then
                    if not fields.year then fields.year = selected.year end
                    parsed = fields
                end
            end
            if not parsed or not parsed.year or not parsed.month or not parsed.day then
                error("prompt.date: value must be a date", 2)
            end
            if not dates.valid(parsed.year, parsed.month, parsed.day) then
                error("prompt.date: value must be a date", 2)
            end
            selected = dates.clamp(parsed, min_day, max_day)
            state.focus = false
            state.error = nil
            sync_entry()
        end,
        summary = function(self, theme)
            return render.summary(theme, self.message, dates.format_date(selected))
        end,
        close = function()
            entry:close()
        end,
    }
    return field
end

function M.run(options)
    validate(options)
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

function M.__call(_, options)
    options = options or {}
    validate(options)
    if not config.is_interactive() then
        local min_day = dates.bounds(options.min, false)
        local max_day = dates.bounds(options.max, false)
        local parsed_default
        if options.default == nil then
            parsed_default = dates.today()
        else
            parsed_default = dates.from_value(options.default)
            if not parsed_default or not parsed_default.year then error("prompt.date: default must be a date", 3) end
        end
        local default = dates.clamp(parsed_default, min_day, max_day)
        return fallback_run(options, default, min_day, max_day)
    end
    return M.run(options)
end

return setmetatable(M, { __call = function(_, options) return M.__call(M, options) end })
