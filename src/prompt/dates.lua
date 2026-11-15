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
    if not parsed then error("prompt: invalid date bound", 3) end
    if is_time then
        return (parsed.hour or 0) * 3600 + (parsed.min or 0) * 60 + (parsed.sec or 0)
    end
    return M.days_from_civil(parsed.year, parsed.month, parsed.day)
end

return M
