-- Calendar arithmetic and date/time parsing shared by the pickers.

local M = {}

local function floor_div(a, b)
    return math.floor(a / b)
end

function M.days_from_civil(year, month, day)
    year = year - (month <= 2 and 1 or 0)
    local era = floor_div(year, 400)
    local yoe = year - era * 400
    local doy = floor_div(153 * (month + (month > 2 and -3 or 9)) + 2, 5) + day - 1
    local doe = yoe * 365 + floor_div(yoe, 4) - floor_div(yoe, 100) + doy
    return era * 146097 + doe - 719468
end

function M.civil_from_days(days)
    local z = days + 719468
    local era = floor_div(z, 146097)
    local doe = z - era * 146097
    local yoe = floor_div(doe - floor_div(doe, 1460) + floor_div(doe, 36524) - floor_div(doe, 146096), 365)
    local year = yoe + era * 400
    local doy = doe - (365 * yoe + floor_div(yoe, 4) - floor_div(yoe, 100))
    local mp = floor_div(5 * doy + 2, 153)
    local day = doy - floor_div(153 * mp + 2, 5) + 1
    local month = mp + (mp < 10 and 3 or -9)
    year = year + (month <= 2 and 1 or 0)
    return year, month, day
end

function M.is_leap(year)
    return year % 4 == 0 and (year % 100 ~= 0 or year % 400 == 0)
end

function M.days_in_month(year, month)
    if month == 2 then return M.is_leap(year) and 29 or 28 end
    if month == 4 or month == 6 or month == 9 or month == 11 then return 30 end
    return 31
end

function M.weekday(year, month, day)
    return (M.days_from_civil(year, month, day) + 3) % 7 + 1
end

function M.today()
    local now = os.date("*t")
    return { year = now.year, month = now.month, day = now.day, hour = now.hour, min = now.min, sec = now.sec }
end

function M.add_days(value, amount)
    local days = M.days_from_civil(value.year, value.month, value.day) + amount
    local year, month, day = M.civil_from_days(days)
    local result = {}
    for key, item in pairs(value) do result[key] = item end
    result.year, result.month, result.day = year, month, day
    return result
end

function M.add_months(value, amount)
    local total = (value.year * 12 + value.month - 1) + amount
    local year = floor_div(total, 12)
    local month = total - year * 12 + 1
    local day = math.min(value.day, M.days_in_month(year, month))
    local result = {}
    for key, item in pairs(value) do result[key] = item end
    result.year, result.month, result.day = year, month, day
    return result
end

function M.valid(year, month, day)
    if type(year) ~= "number" or type(month) ~= "number" or type(day) ~= "number" then return false end
    if year < 1 or year > 9999 then return false end
    if month < 1 or month > 12 or day < 1 or day > M.days_in_month(year, month) then return false end
    return true
end

function M.parse_date(text)
    local year, month, day = text:match("^%s*(%d%d%d%d)%-(%d%d?)%-(%d%d?)%s*$")
    if not year then return nil end
    year, month, day = tonumber(year), tonumber(month), tonumber(day)
    if not M.valid(year, month, day) then return nil end
    return { year = year, month = month, day = day }
end

function M.parse_time(text)
    local hour, minute, second = text:match("^%s*(%d%d?):(%d%d?):(%d%d?)%s*$")
    if not hour then
        hour, minute = text:match("^%s*(%d%d?):(%d%d?)%s*$")
        second = 0
    end
    if not hour then return nil end
    hour, minute, second = tonumber(hour), tonumber(minute), tonumber(second or 0)
    if hour < 0 or hour > 23 or minute < 0 or minute > 59 or second < 0 or second > 59 then return nil end
    return { hour = hour, min = minute, sec = second }
end

function M.parse_datetime(text)
    local date_part, time_part = text:match("^(.-)%s+(.+)$")
    if not date_part then return nil end
    local date = M.parse_date(date_part)
    local time = M.parse_time(time_part)
    if not date or not time then return nil end
    date.hour, date.min, date.sec = time.hour, time.min, time.sec
    return date
end

local english_short = {
    jan = 1, feb = 2, mar = 3, apr = 4, may = 5, jun = 6,
    jul = 7, aug = 8, sep = 9, oct = 10, nov = 11, dec = 12,
}

local english_long = {
    january = 1, february = 2, march = 3, april = 4, may = 5, june = 6,
    july = 7, august = 8, september = 9, october = 10, november = 11, december = 12,
}

local short_months = {}
local long_months = {}
for name, value in pairs(english_short) do short_months[name] = value end
for name, value in pairs(english_long) do long_months[name] = value end

-- `os.date` is locale-sensitive, so accept the current locale's month names in
-- addition to the English fallback.
local month_stamp_year = os.date("*t").year
for month = 1, 12 do
    local stamp = os.time { year = month_stamp_year, month = month, day = 15, hour = 12 }
    if stamp then
        short_months[os.date("%b", stamp):lower()] = month
        long_months[os.date("%B", stamp):lower()] = month
    end
end

local function month_lookup(map)
    local names = {}
    for name, value in pairs(map) do
        names[#names + 1] = { name = name, value = value }
    end
    table.sort(names, function(left, right) return #left.name > #right.name end)
    return { names = names }
end

local short_lookup = month_lookup(short_months)
local long_lookup = month_lookup(long_months)

local ampm_values = { am = "am", pm = "pm" }
local am_stamp = os.time { year = month_stamp_year, month = 1, day = 15, hour = 9 }
local pm_stamp = os.time { year = month_stamp_year, month = 1, day = 15, hour = 15 }
if am_stamp then
    local name = os.date("%p", am_stamp)
    if name and name ~= "" then ampm_values[name:lower()] = "am" end
end
if pm_stamp then
    local name = os.date("%p", pm_stamp)
    if name and name ~= "" then ampm_values[name:lower()] = "pm" end
end
local ampm_lookup = month_lookup(ampm_values)

local function compile_format(format, short_names, long_names, ampm_names)
    local tokens = {}
    local index = 1

    local function literal(value)
        tokens[#tokens + 1] = { kind = "literal", value = value }
    end

    local function field(name, pattern)
        tokens[#tokens + 1] = {
            kind = "field",
            name = name,
            pattern = pattern,
        }
    end

    while index <= #format do
        local char = format:sub(index, index)
        if char == "%" then
            local spec = format:sub(index + 1, index + 1)
            index = index + 2
            if spec == "F" then
                field("year", "%d%d%d%d")
                literal("-")
                field("month", "%d%d?")
                literal("-")
                field("day", "%d%d?")
            elseif spec == "T" then
                field("hour", "%d%d?")
                literal(":")
                field("min", "%d%d?")
                literal(":")
                field("sec", "%d%d?")
            elseif spec == "R" then
                field("hour", "%d%d?")
                literal(":")
                field("min", "%d%d?")
            elseif spec == "Y" then
                field("year", "%d%d%d%d")
            elseif spec == "y" then
                field("year_short", "%d%d")
            elseif spec == "m" then
                field("month", "%d%d?")
            elseif spec == "d" then
                field("day", "%d%d?")
            elseif spec == "e" then
                tokens[#tokens + 1] = { kind = "day_space" }
            elseif spec == "H" then
                field("hour", "%d%d?")
            elseif spec == "I" then
                field("hour12", "%d%d?")
            elseif spec == "M" then
                field("min", "%d%d?")
            elseif spec == "S" then
                field("sec", "%d%d?")
            elseif spec == "b" then
                tokens[#tokens + 1] = { kind = "month", lookup = short_names }
            elseif spec == "B" then
                tokens[#tokens + 1] = { kind = "month", lookup = long_names }
            elseif spec == "p" then
                tokens[#tokens + 1] = { kind = "ampm", lookup = ampm_names }
            elseif spec == "%" then
                literal("%")
            else
                return nil
            end
        else
            literal(char)
            index = index + 1
        end
    end
    return tokens
end

local function apply_field(result, name, value)
    if name == "year" then
        result.year = tonumber(value)
    elseif name == "year_short" then
        local short = tonumber(value)
        if short == nil then return false end
        result.year = short >= 69 and 1900 + short or 2000 + short
    elseif name == "month" then
        result.month = tonumber(value)
    elseif name == "day" then
        result.day = tonumber(value)
    elseif name == "hour" then
        result.hour = tonumber(value)
    elseif name == "hour12" then
        result.hour12 = tonumber(value)
    elseif name == "min" then
        result.min = tonumber(value)
    elseif name == "sec" then
        result.sec = tonumber(value)
    end
    return true
end

--- Parse a string produced by `os.date(format)` for the common date/time
-- specifiers.  Returns a table of fields, or nil when the format is not
-- supported or the text does not match.
function M.parse_format(text, format, short_names, long_names, ampm_names)
    if type(text) ~= "string" or type(format) ~= "string" then return nil end
    local tokens = compile_format(
        format,
        short_names and month_lookup(short_names) or short_lookup,
        long_names and month_lookup(long_names) or long_lookup,
        ampm_names and month_lookup(ampm_names) or ampm_lookup
    )
    if tokens == nil then return nil end

    local result = {}
    local position = 1
    for _, token in ipairs(tokens) do
        if position > #text + 1 then return nil end
        if token.kind == "literal" then
            if text:sub(position, position + #token.value - 1) ~= token.value then return nil end
            position = position + #token.value
        elseif token.kind == "month" then
            local remaining = text:sub(position):lower()
            local matched
            for _, entry in ipairs(token.lookup.names) do
                if remaining:sub(1, #entry.name) == entry.name then
                    matched = entry
                    break
                end
            end
            if matched == nil then return nil end
            result.month = matched.value
            position = position + #matched.name
        elseif token.kind == "ampm" then
            local remaining = text:sub(position):lower()
            local matched
            for _, entry in ipairs(token.lookup.names) do
                if remaining:sub(1, #entry.name) == entry.name then
                    matched = entry
                    break
                end
            end
            if matched == nil then return nil end
            result.ampm = matched.value
            position = position + #matched.name
        elseif token.kind == "day_space" then
            -- `%e` is always two characters: a space for days 1-9, or two
            -- digits for days 10-31.  This matters when a numeric field follows
            -- without a separator.
            local first = text:sub(position, position)
            local digits
            if first == " " then
                digits = text:sub(position + 1, position + 1)
                if digits == nil or not digits:match("%d") then return nil end
            else
                digits = text:sub(position, position + 1)
                if #digits ~= 2 or not digits:match("^%d%d$") then return nil end
            end
            result.day = tonumber(digits)
            position = position + 2
        elseif token.kind == "field" then
            local subject = text:sub(position)
            local value, consumed
            value = subject:match("^(" .. token.pattern .. ")")
            if value == nil then return nil end
            consumed = #value
            if not apply_field(result, token.name, value) then return nil end
            position = position + consumed
        end
    end
    if position ~= #text + 1 then return nil end

    if result.hour12 ~= nil then
        if result.hour12 < 1 or result.hour12 > 12 then return nil end
        if result.ampm == nil then return nil end
        local hour = result.hour12 % 12
        if result.ampm == "pm" then hour = hour + 12 end
        result.hour = hour
        result.hour12 = nil
    elseif result.ampm ~= nil then
        return nil
    end

    if result.year ~= nil and result.month ~= nil and result.day ~= nil then
        if not M.valid(result.year, result.month, result.day) then return nil end
    end
    if result.month ~= nil and (result.month < 1 or result.month > 12) then return nil end
    if result.day ~= nil and (result.day < 1 or result.day > 31) then return nil end
    if result.hour ~= nil and (result.hour < 0 or result.hour > 23) then return nil end
    if result.min ~= nil and (result.min < 0 or result.min > 59) then return nil end
    if result.sec ~= nil and (result.sec < 0 or result.sec > 59) then return nil end
    return result
end

function M.format_date(value)
    return string.format("%04d-%02d-%02d", value.year, value.month, value.day)
end

function M.format_time(value, seconds)
    if seconds then
        return string.format("%02d:%02d:%02d", value.hour or 0, value.min or 0, value.sec or 0)
    end
    return string.format("%02d:%02d", value.hour or 0, value.min or 0)
end

function M.format_datetime(value, seconds)
    return M.format_date(value) .. " " .. M.format_time(value, seconds)
end

local month_names = {
    "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December",
}

function M.month_name(month)
    return month_names[month] or ""
end

function M.weekday_names()
    return { "Mo", "Tu", "We", "Th", "Fr", "Sa", "Su" }
end

function M.from_value(value)
    if value == nil then return nil end
    if type(value) == "table" then
        if value.year and value.month and value.day then
            if not M.valid(value.year, value.month, value.day) then return nil end
            return {
                year = value.year, month = value.month, day = value.day,
                hour = value.hour, min = value.min, sec = value.sec,
            }
        end
        return nil
    end
    if type(value) == "string" then
        return M.parse_datetime(value) or M.parse_date(value) or M.parse_time(value)
    end
    if type(value) == "number" then
        local now = os.date("*t", value)
        return { year = now.year, month = now.month, day = now.day, hour = now.hour, min = now.min, sec = now.sec }
    end
    return nil
end

function M.to_result(value, options, with_time)
    local as = options.as or "table"
    if as == "table" then
        local result = { year = value.year, month = value.month, day = value.day }
        if with_time then
            result.hour, result.min, result.sec = value.hour or 0, value.min or 0, value.sec or 0
        end
        return result
    end
    if as == "string" then
        if options.format then
            return os.date(options.format, os.time {
                year = value.year, month = value.month, day = value.day,
                hour = value.hour or 0, min = value.min or 0, sec = value.sec or 0,
            })
        end
        if with_time then return M.format_datetime(value, options.seconds) end
        return M.format_date(value)
    end
    if as == "time" then
        return os.time {
            year = value.year, month = value.month, day = value.day,
            hour = value.hour or 0, min = value.min or 0, sec = value.sec or 0,
        }
    end
    error("prompt: as must be 'table', 'string' or 'time'", 3)
end

function M.clamp(value, min_day, max_day)
    local day = M.days_from_civil(value.year, value.month, value.day)
    local target = day
    if min_day and target < min_day then target = min_day end
    if max_day and target > max_day then target = max_day end
    if target == day then return value end
    local year, month, date = M.civil_from_days(target)
    local result = {}
    for key, item in pairs(value) do result[key] = item end
    result.year, result.month, result.day = year, month, date
    return result
end

function M.bounds(value, is_time)
    if value == nil then return nil end
    local parsed = M.from_value(value)
    if not parsed or not parsed.year then error("prompt: invalid date bound", 3) end
    if is_time then
        return (parsed.hour or 0) * 3600 + (parsed.min or 0) * 60 + (parsed.sec or 0)
    end
    return M.days_from_civil(parsed.year, parsed.month, parsed.day)
end

return M
