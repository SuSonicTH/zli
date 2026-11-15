-- Combined date and time picker.

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
        error("prompt.datetime: expecting an options table", 3)
    end
    if type(options.message) ~= "string" or options.message == "" then
        error("prompt.datetime: message must be a non-empty string", 3)
    end
    if options.as ~= nil and options.as ~= "table" and options.as ~= "string" and options.as ~= "time" then
        error("prompt.datetime: as must be 'table', 'string' or 'time'", 3)
    end
    if options.seconds ~= nil and type(options.seconds) ~= "boolean" then
        error("prompt.datetime: seconds must be a boolean", 3)
    end
    if options.week_start ~= nil and options.week_start ~= "monday" and options.week_start ~= "sunday" then
        error("prompt.datetime: week_start must be 'monday' or 'sunday'", 3)
    end
    if options.format ~= nil and type(options.format) ~= "string" then
        error("prompt.datetime: format must be a string", 3)
    end
end

local function fallback_run(options, default, seconds)
    local shown = default and dates.format_datetime(default, seconds) or ""
    io.write("? " .. options.message .. (shown ~= "" and (" [" .. shown .. "]") or "") ..
        " (YYYY-MM-DD HH:MM" .. (seconds and ":SS" or "") .. "): ")
    io.flush()
    while true do
        local line = io.read("l")
        io.write("\n")
        io.flush()
        if line == nil then
            local policy = config.get("eof")
            if policy == "error" then error("prompt.datetime: end of input", 3) end
            if policy == "nil" then return nil, "eof" end
            return dates.to_result(default, options, true)
        end
        line = line:gsub("^%s+", ""):gsub("%s+$", "")
        local value = line == "" and default or dates.parse_datetime(line)
        if value == nil then
            io.write("Use YYYY-MM-DD HH:MM" .. (seconds and ":SS" or "") .. ".\n> ")
        else
            if not seconds then value.sec = 0 end
            return dates.to_result(value, options, true)
        end
        io.flush()
    end
end

--- Build a reusable date-and-time field.
function M.new_field(options, field_options)
    field_options = field_options or {}
    validate(options)
    local seconds = options.seconds == true
    local show_help = field_options.show_help ~= false
    local message = field_options.message or options.message
    local min_day = dates.bounds(options.min, false)
    local max_day = dates.bounds(options.max, false)
    local parsed_default
    if options.default == nil then
        parsed_default = dates.today()
    else
        parsed_default = dates.from_value(options.default)
        if not parsed_default or not parsed_default.year then
            error("prompt.datetime: default must be a date and time", 3)
        end
    end
    local selected = dates.clamp(parsed_default, min_day, max_day)

    local state = {
        hour = selected.hour or 0, min = selected.min or 0, sec = selected.sec or 0,
        segment = 1, digits = "", focus = "date", error = nil, width = 0,
    }
    local entry = editor_mod.new(20, 1, {
        initial = dates.format_datetime(selected, seconds),
        single_line = true,
        submit_on_enter = true,
    })

    local function current_day()
        return dates.days_from_civil(selected.year, selected.month, selected.day)
    end

    local function sync_entry()
        if state.focus ~= "entry" then entry:set_text(dates.format_datetime(selected, seconds)) end
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

    local function offset_and_count()
        local first = dates.weekday(selected.year, selected.month, 1)
        local offset = first - 1
        if options.week_start == "sunday" then offset = first % 7 end
        return offset, dates.days_in_month(selected.year, selected.month)
    end

    local function apply_digits()
        if state.digits == "" then return end
        local max = state.segment == 1 and 23 or 59
        local value = math.min(tonumber(state.digits) or 0, max)
        if state.segment == 1 then state.hour = value
        elseif state.segment == 2 then state.min = value
        else state.sec = value end
        state.digits = ""
    end

    local function result()
        -- Include pending time digits without clearing them; `commit` applies
        -- them when the form advances or submits.
        local hour, min = state.hour, state.min
        local sec = seconds and state.sec or 0
        if state.digits ~= "" then
            local max = state.segment == 1 and 23 or 59
            local value = math.min(tonumber(state.digits) or 0, max)
            if state.segment == 1 then hour = value
            elseif state.segment == 2 then min = value
            elseif seconds then sec = value end
        end
        local value = {
            year = selected.year, month = selected.month, day = selected.day,
            hour = hour, min = min, sec = sec,
        }
        return dates.to_result(value, options, true)
    end

    local function frame(width, max_height)
        local columns = width and math.max(1, math.floor(width)) or (require("term").size() or { columns = 80 }).columns
        local entry_width = math.max(1, columns - 8)
        if entry_width ~= state.width then
            state.width = entry_width
            entry:resize(entry_width, 1)
        end

        local lines = {
            field_mod.label(message),
        }
        local title = dates.month_name(selected.month) .. " " .. selected.year
        lines[#lines + 1] = render.line(render.span(string.rep(" ", math.max(0, math.floor((21 - #title) / 2))) .. title, "title"))
        local names = dates.weekday_names()
        if options.week_start == "sunday" then
            names = { "Su", "Mo", "Tu", "We", "Th", "Fr", "Sa" }
        end
        local header = {}
        for _, name in ipairs(names) do header[#header + 1] = render.span(" " .. name, "muted") end
        lines[#lines + 1] = header

        local offset, count = offset_and_count()
        local week_count = math.ceil((offset + count) / 7)
        local first_week, last_week = 0, week_count - 1
        if max_height then
            local chrome = 4 + (state.focus == "entry" and 1 or 0) + (show_help and 1 or 0)
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
                local day = week * 7 + column - offset
                if day >= 1 and day <= count then
                    local value_day = dates.days_from_civil(selected.year, selected.month, day)
                    local style
                    if day == selected.day then style = state.focus == "date" and "selected" or "accent"
                    elseif value_day == today_day then style = "accent"
                    elseif (min_day and value_day < min_day) or (max_day and value_day > max_day) then style = "muted"
                    end
                    spans[#spans + 1] = render.span(string.format(" %2d", day), style)
                else
                    spans[#spans + 1] = render.span("   ", nil)
                end
            end
            lines[#lines + 1] = spans
        end

        local time_spans = { render.span("  time: ", state.focus == "time" and "message" or "muted") }
        local values = { string.format("%02d", state.hour), string.format("%02d", state.min) }
        if seconds then values[3] = string.format("%02d", state.sec) end
        for index, text in ipairs(values) do
            if index > 1 then time_spans[#time_spans + 1] = render.span(" : ", "muted") end
            time_spans[#time_spans + 1] = render.span(
                text,
                state.focus == "time" and index == state.segment and "selected" or nil
            )
        end
        lines[#lines + 1] = time_spans

        local cursor
        if state.focus == "entry" then
            local rows, position = entry:render()
            local spans = { render.span("  edit: ", "muted") }
            for _, span in ipairs(rows[1] or {}) do spans[#spans + 1] = span end
            lines[#lines + 1] = spans
            cursor = { row = #lines, column = 8 + ((position and position.column) or 0) }
        end
        if show_help then
            lines[#lines + 1] = field_mod.help_line(
                "Tab date/time  arrows move  / type  enter accept  esc cancel"
            )
        end
        return render.frame(lines, cursor)
    end

    local function apply_days(days)
        set_days(days)
    end

    local function apply_entry()
        local text = entry:value():gsub("^%s+", ""):gsub("%s+$", "")
        local parsed = dates.parse_datetime(text)
        if not parsed then
            state.error = "Use YYYY-MM-DD HH:MM."
            return false
        end
        if not set_days(dates.days_from_civil(parsed.year, parsed.month, parsed.day)) then return false end
        state.hour, state.min = parsed.hour, parsed.min
        state.sec = seconds and parsed.sec or 0
        state.focus = "date"
        return true
    end

    local function type_digit(digit)
        state.digits = state.digits .. digit
        local max = state.segment == 1 and 23 or 59
        local value = tonumber(state.digits)
        if value * 10 > max or #state.digits == 2 then
            value = math.min(value, max)
            if state.segment == 1 then state.hour = value
            elseif state.segment == 2 then state.min = value
            else state.sec = value end
            state.digits = ""
            local count = seconds and 3 or 2
            if state.segment < count then state.segment = state.segment + 1 end
        end
    end

    local function on_event(event)
        if event.type == "resize" then return "continue" end
        if input.ctrl(event, "c") then return "cancel" end
        if input.key(event, "esc") then
            if state.focus == "entry" then
                state.focus = "date"
                state.error = nil
                sync_entry()
                return "continue"
            end
            return "cancel"
        end
        if input.ctrl(event, "t") then
            if state.focus == "entry" then
                apply_entry()
                return "continue"
            end
            if state.focus == "time" then apply_digits() end
            if state.focus == "date" then state.focus = "time"
            else state.focus = "date" end
            state.error = nil
            return "continue"
        end
        if input.key(event, "tab") then
            if state.focus == "time" then apply_digits() end
            if state.focus == "date" then state.focus = "time"
            elseif state.focus == "time" then state.focus = "date"
            else state.focus = "date" end
            state.error = nil
            return "continue"
        end

        if state.focus == "entry" then
            state.error = nil
            local action = entry:feed(event)
            if action == "submit" then apply_entry() return "continue" end
            if action == "abort" then return "cancel" end
            return "continue"
        end

        if state.focus == "time" then
            if input.enter(event) then
                apply_digits()
                return "submit", result()
            end
            if input.key(event, "left") then
                local count = seconds and 3 or 2
                state.segment = (state.segment - 2) % count + 1
                state.digits = ""
                return "continue"
            end
            if input.key(event, "right") then
                local count = seconds and 3 or 2
                state.segment = state.segment % count + 1
                state.digits = ""
                return "continue"
            end
            if input.key(event, "up") then
                if state.segment == 1 then state.hour = (state.hour + 1) % 24
                elseif state.segment == 2 then state.min = (state.min + 1) % 60
                else state.sec = (state.sec + 1) % 60 end
                return "continue"
            end
            if input.key(event, "down") then
                if state.segment == 1 then state.hour = (state.hour - 1) % 24
                elseif state.segment == 2 then state.min = (state.min - 1) % 60
                else state.sec = (state.sec - 1) % 60 end
                return "continue"
            end
            local char = input.printable(event)
            if char and char:match("%d") then type_digit(char) return "continue" end
            return "continue"
        end

        if input.enter(event) then return "submit", result() end
        local char = input.printable(event)
        if char == "/" then
            state.focus = "entry"
            entry:set_text(dates.format_datetime(selected, seconds))
            state.error = nil
            return "continue"
        elseif char and (char:match("%d") or char == "-") then
            state.focus = "entry"
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
            local day = current_day()
            if (min_day and day < min_day) or (max_day and day > max_day) then selected = dates.add_months(selected, 1) end
            state.error = nil
            sync_entry()
            return "continue"
        elseif input.key(event, "page_down") then
            selected = dates.add_months(selected, 1)
            local day = current_day()
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
            apply_days(dates.days_from_civil(today.year, today.month, today.day))
            return "continue"
        end
        if moved then apply_days(current_day() + moved) end
        return "continue"
    end

    local field
    field = field_mod.new {
        type = field_options.type or "datetime",
        options = options,
        message = message,
        draw_active = function(self, width)
            return frame(width, self.max_height)
        end,
        draw_compact = function(self, theme)
            local value = { year = selected.year, month = selected.month, day = selected.day,
                hour = state.hour, min = state.min, sec = seconds and state.sec or 0 }
            return render.summary(theme, self.message, dates.format_datetime(value, seconds))
        end,
        handle = function(self, event)
            local action, value = on_event(event)
            self.error = state.error
            return action, value
        end,
        commit = function(self)
            if state.focus == "entry" then
                if not apply_entry() then
                    self.error = state.error
                    return false, state.error
                end
            elseif state.focus == "time" then
                apply_digits()
            end
            self.error = nil
            return true
        end,
        value = function()
            return result()
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
                error("prompt.datetime: value must be a date and time", 2)
            end
            if not dates.valid(parsed.year, parsed.month, parsed.day) then
                error("prompt.datetime: value must be a date and time", 2)
            end
            selected = dates.clamp(parsed, min_day, max_day)
            state.hour = parsed.hour or 0
            state.min = parsed.min or 0
            state.sec = parsed.sec or 0
            state.focus = "date"
            state.segment = 1
            state.digits = ""
            state.error = nil
            sync_entry()
        end,
        summary = function(self, theme)
            local value = { year = selected.year, month = selected.month, day = selected.day,
                hour = state.hour, min = state.min, sec = seconds and state.sec or 0 }
            return render.summary(theme, self.message, dates.format_datetime(value, seconds))
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
            if not parsed_default or not parsed_default.year then
                error("prompt.datetime: default must be a date and time", 3)
            end
        end
        local default = dates.clamp(parsed_default, min_day, max_day)
        return fallback_run(options, default, options.seconds == true)
    end
    return M.run(options)
end

return setmetatable(M, { __call = function(_, options) return M.__call(M, options) end })
