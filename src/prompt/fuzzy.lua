-- Case-insensitive subsequence matching used by search and autocomplete.
--
-- Matching works on codepoints but reports byte ranges so callers can split
-- the original UTF-8 text without re-encoding it.

local M = {}

local function char_length(byte)
    if byte < 0x80 then return 1 end
    if byte < 0xC0 then return 1 end
    if byte < 0xE0 then return 2 end
    if byte < 0xF0 then return 3 end
    return 4
end

local function codepoints(text)
    local result = {}
    local index = 1
    while index <= #text do
        local length = char_length(text:byte(index))
        if index + length - 1 > #text then length = 1 end
        result[#result + 1] = {
            byte = index,
            text = text:sub(index, index + length - 1),
        }
        index = index + length
    end
    return result
end

local function is_separator(char)
    if char == nil or char == "" then return true end
    return char:match("[%s_%-%./\\:]") ~= nil
end

local function is_lower(char)
    if char == nil then return false end
    local lower = char:lower()
    return lower == char and char:match("%a") ~= nil
end

local function merge(ranges, start_byte, end_byte)
    local last = ranges[#ranges]
    if last and start_byte == last[2] + 1 then
        last[2] = end_byte
    else
        ranges[#ranges + 1] = { start_byte, end_byte }
    end
end

--- Score `text` against `query`.
-- Returns the score and byte ranges, or nil when the query is not a
-- subsequence of the text.
function M.score(text, query)
    text = tostring(text or "")
    query = tostring(query or "")
    if query == "" then return 0, {} end

    local lower_text = text:lower()
    local lower_query = query:lower()

    -- Lowering must not change byte offsets; this holds for ASCII and for
    -- UTF-8 text where lower only rewrites single-byte ASCII letters.
    if #lower_text ~= #text or #lower_query ~= #query then
        lower_text = text
        lower_query = query
    end

    local matched = {}
    local search_from = 1
    for _, query_char in ipairs(codepoints(lower_query)) do
        local found = lower_text:find(query_char.text, search_from, true)
        if not found then return nil end
        matched[#matched + 1] = found
        search_from = found + #query_char.text
    end

    local score = 0
    local ranges = {}
    local previous_end = nil

    for position, byte in ipairs(matched) do
        local length = char_length(text:byte(byte))
        local finish = byte + length - 1
        local before = byte > 1 and text:sub(byte - 1, byte - 1) or nil
        local current = text:sub(byte, byte)
        local consecutive = previous_end ~= nil and byte == previous_end + 1
        local at_start = byte == 1
        local boundary = before == nil or is_separator(before)
        local camel = before ~= nil and is_lower(before) and current:match("%u") ~= nil
        local gap = position > 1 and (byte - previous_end - 1) or 0

        score = score + 10
        if consecutive then score = score + 15 end
        if at_start then score = score + 20 end
        if boundary then score = score + 10 end
        if camel then score = score + 8 end
        score = score - math.min(gap, 8)

        merge(ranges, byte, finish)
        previous_end = finish
    end

    if lower_text == lower_query then
        score = score + 100
    elseif lower_text:sub(1, #lower_query) == lower_query then
        score = score + 30
    end
    return score, ranges
end

--- Split `text` into spans, styling the byte ranges from `M.score`.
function M.highlight(text, ranges, style)
    local spans = {}
    local position = 1
    for _, range in ipairs(ranges or {}) do
        if range[1] > position then
            spans[#spans + 1] = { text = text:sub(position, range[1] - 1) }
        end
        if range[2] >= range[1] then
            spans[#spans + 1] = { text = text:sub(range[1], range[2]), style = style }
        end
        position = math.max(position, range[2] + 1)
    end
    if position <= #text then
        spans[#spans + 1] = { text = text:sub(position) }
    end
    return spans
end

local function entry_text(item)
    if type(item) == "string" or type(item) == "number" then return tostring(item) end
    if type(item) == "table" then return tostring(item.label or item.value or "") end
    return tostring(item)
end

local function compare(left, right)
    if left.score ~= right.score then return left.score > right.score end
    local left_length = #left.label
    local right_length = #right.label
    if left_length ~= right_length then return left_length < right_length end
    return left.index < right.index
end

--- Filter and rank strings or `{ label, search }` entries.
-- Returns an array of `{ item, score, ranges, index }` in best-first order.
function M.filter(items, query)
    if type(items) ~= "table" then
        error("prompt.fuzzy: items must be a table", 2)
    end
    local result = {}
    for index, item in ipairs(items) do
        local label = entry_text(item)
        local haystack = label
        if type(item) == "table" and item.search then
            haystack = label .. " " .. tostring(item.search)
        end
        local score, ranges = M.score(haystack, query)
        if score then
            if haystack ~= label then
                local label_score, label_ranges = M.score(label, query)
                if label_score then
                    score = label_score
                    ranges = label_ranges
                else
                    ranges = {}
                end
            end
            result[#result + 1] = {
                item = item,
                label = label,
                score = score,
                ranges = ranges,
                index = index,
            }
        end
    end
    table.sort(result, compare)
    return result
end

return M
