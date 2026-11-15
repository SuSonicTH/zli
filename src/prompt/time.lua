-- Time picker with segmented entry.

local config = require "prompt.config"
local dates = require "prompt.dates"
local input = require "prompt.input"
local render = require "prompt.render"
local theme_mod = require "prompt.theme"

local M = {}

local function validate(options)
    if type(options) ~= "table" then
        error("prompt.time: expecting an options table", 3)
    end
    if type(options.message) ~= "string" or options.message == "" then
        error("prompt.time: message must be a non-empty string", 3)
    end
    if options.as ~= nil and options.as ~= "table" and options.as ~= "string" and options.as ~= "time" then
        error("prompt.time: as must be 'table', 'string' or 'time'", 3)
    end
    if options.seconds ~= nil and type(options.seconds) ~= "boolean" then
        error("prompt.time: seconds must be a boolean", 3)
    end
    if options.hour24 ~= nil and type(options.hour24) ~= "boolean" then
        error("prompt.time: hour24 must be a boolean", 3)
    end
end

local function from_time(value)
    if value == nil then
        local now = os.date("*t")
        return { hour = now.hour, min = now.min, sec = now.sec }
    end
    if type(value) == "table" and value.hour then
        return { hour = value.hour, min = value.min or 0, sec = value.sec or 0 }
    end
    if type(value) == "string" then
        return dates.parse_time(value)
    end
    if type(value) == "number" then
        local now = os.date("*t", value)
        return { hour = now.hour, min = now.min, sec = now.sec }
    end
    return nil
end

local function limits(options, segment)
    if segment == 1 then return options.hour24 ~= false and 23 or 12 end
    return 59
end

local function normalize(state, seconds)
    state.hour = state.hour % 24
    state.min = state.min % 60
    state.sec = seconds and (state.sec % 60) or 0
end

local function to_result(value, options)
    if options.as == "table" or options.as == nil then
        return { hour = value.hour, min = value.min, sec = value.sec }
    elseif options.as == "string" then
        if options.format then
            local now = dates.today()
            return os.date(options.format, os.time {
                year = now.year, month = now.month, day = now.day,
                hour = value.hour, min = value.min, sec = value.sec,
            })
        end
        return dates.format_time(value, options.seconds)
    elseif options.as == "time" then
        local now = dates.today()
        return os.time {
            year = now.year, month = now.month, day = now.day,
            hour = value.hour, min = value.min, sec = value.sec,
        }
    end
    error("prompt.time: as must be 'table', 'string' or 'time'", 3)
end

local function fallback_run(options, default)
    local shown = dates.format_time(default, options.seconds)
    io.write("? " .. options.message .. " [" .. shown .. "] (" ..
        (options.seconds and "HH:MM:SS" or "HH:MM") .. "): ")
    io.flush()
    while true do
        local line = io.read("l")
        if line == nil then
            local policy = config.get("eof")
            if policy == "error" then error("prompt.time: end of input", 3) end
            if policy == "nil" then return nil, "eof" end
            return to_result(default, options)
        end
        line = line:gsub("^%s+", ""):gsub("%s+$", "")
        local value = line == "" and default or dates.parse_time(line)
        if value == nil then
            io.write("Use HH:MM" .. (options.seconds and ":SS" or "") .. ".\n> ")
        else
            if not options.seconds then value.sec = 0 end
            return to_result(value, options)
        end
        io.flush()
    end
end

function M.run(options)
    validate(options)
    local seconds = options.seconds == true
    local hour24 = options.hour24 ~= false
    local theme = theme_mod.build()
    local selected = from_time(options.default)
    if not selected then error("prompt.time: default must be a time", 3) end
    local state = {
        hour = selected.hour, min = selected.min, sec = selected.sec,
        segment = 1, digits = "", error = nil,
    }

    local function display_hour()
        if hour24 then return state.hour end
        local hour = state.hour % 12
        if hour == 0 then hour = 12 end
        return hour
    end

    local function suffix()
        if hour24 then return "" end
        return state.hour < 12 and " AM" or " PM"
    end

    local function frame()
        local lines = {
            render.line(render.span("? ", "accent"), render.span(options.message, "message")),
        }
        local values = {
            string.format("%02d", display_hour()),
            string.format("%02d", state.min),
        }
        if seconds then values[3] = string.format("%02d", state.sec) end
        local spans = { render.span("  ", nil) }
        for index, text in ipairs(values) do
            if index > 1 then spans[#spans + 1] = render.span(" : ", "muted") end
            spans[#spans + 1] = render.span(text, index == state.segment and "selected" or nil)
        end
        spans[#spans + 1] = render.span(suffix(), "muted")
        lines[#lines + 1] = spans
        if state.digits ~= "" then
            lines[#lines + 1] = render.line(render.span("  typing: " .. state.digits, "muted"))
        end
        if state.error then lines[#lines + 1] = render.line(render.span(state.error, "error")) end
        lines[#lines + 1] = render.line(
            render.span("left/right segment  up/down adjust  digits type  enter accept", "muted")
        )
        return render.frame(lines)
    end

    local function set_segment(value)
        local max = limits(options, state.segment)
        value = math.max(0, math.min(value, max))
        if state.segment == 1 then
            if hour24 then state.hour = value
            else
                local pm = state.hour >= 12
                local hour = value % 12
                if pm then hour = hour + 12 end
                state.hour = hour
            end
        elseif state.segment == 2 then
            state.min = value
        else
            state.sec = value
        end
        state.error = nil
    end

    local function current_value()
        if state.segment == 1 then return hour24 and state.hour or display_hour() end
        if state.segment == 2 then return state.min end
        return state.sec
    end

    local function move_segment(delta)
        local count = seconds and 3 or 2
        state.segment = (state.segment - 1 + delta) % count + 1
        state.digits = ""
        state.error = nil
    end

    local function type_digit(digit)
        state.digits = state.digits .. digit
        local max = limits(options, state.segment)
        local value = tonumber(state.digits)
        if value * 10 > max or #state.digits == 2 then
            set_segment(math.min(value, max))
            state.digits = ""
            local count = seconds and 3 or 2
            if state.segment < count then state.segment = state.segment + 1 end
        end
    end

    local function on_event(event)
        if event.type == "resize" then return "continue" end
        if input.cancel(event) then return "cancel" end
        if input.enter(event) then
            if state.digits ~= "" then
                set_segment(tonumber(state.digits) or current_value())
                state.digits = ""
                return "continue"
            end
            normalize(state, seconds)
            return "submit", to_result(state, options)
        end
        if input.key(event, "left") then move_segment(-1) return "continue" end
        if input.key(event, "right") then move_segment(1) return "continue" end
        if input.key(event, "up") then
            if state.segment == 1 then
                state.hour = (state.hour + 1) % 24
            elseif state.segment == 2 then
                state.min = (state.min + 1) % 60
            else
                state.sec = (state.sec + 1) % 60
            end
            state.error = nil
            return "continue"
        end
        if input.key(event, "down") then
            if state.segment == 1 then
                state.hour = (state.hour - 1) % 24
            elseif state.segment == 2 then
                state.min = (state.min - 1) % 60
            else
                state.sec = (state.sec - 1) % 60
            end
            state.error = nil
            return "continue"
        end
        if input.key(event, "page_up") then
            if state.segment == 1 then state.hour = (state.hour + 5) % 24
            elseif state.segment == 2 then state.min = (state.min + 5) % 60
            else state.sec = (state.sec + 5) % 60 end
            return "continue"
        end
        if input.key(event, "page_down") then
            if state.segment == 1 then state.hour = (state.hour - 5) % 24
            elseif state.segment == 2 then state.min = (state.min - 5) % 60
            else state.sec = (state.sec - 5) % 60 end
            return "continue"
        end
        if input.key(event, "backspace") then
            state.digits = state.digits:sub(1, -2)
            return "continue"
        end
        local char = input.printable(event)
        if char then
            if char:match("%d") then type_digit(char) return "continue" end
            if not hour24 and (char == "a" or char == "A" or char == "p" or char == "P") then
                local pm = char == "p" or char == "P"
                local hour = state.hour % 12
                if pm then hour = hour + 12 end
                state.hour = hour
                state.error = nil
                return "continue"
            end
        end
        return "continue"
    end

    return input.run {
        screen = options.screen,
        commit = options.commit,
        frame = frame,
        on_event = on_event,
        summary = function()
            return render.summary(theme, options.message, dates.format_time(state, seconds))
        end,
        final_frame = frame,
    }
end

return function(options)
    options = options or {}
    validate(options)
    if not config.is_interactive() then
        return fallback_run(options, from_time(options.default))
    end
    return M.run(options)
end
