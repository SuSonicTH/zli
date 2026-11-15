-- Suggestion filtering and completion shared by text fields and the file picker.

local fuzzy = require "prompt.fuzzy"

local M = {}

local function string_entry(item)
    if type(item) == "string" or type(item) == "number" then
        return { label = tostring(item), value = item }
    end
    return nil
end

function M.normalize(items)
    if type(items) ~= "table" then
        error("prompt.suggest: suggestions must be a table", 3)
    end
    local result = {}
    for index, item in ipairs(items) do
        local normalized = string_entry(item)
        if normalized == nil then
            if type(item) ~= "table" then
                error("prompt.suggest: suggestion " .. index .. " must be a string or a table", 3)
            end
            if item.label == nil then
                error("prompt.suggest: suggestion " .. index .. " needs a label", 3)
            end
            local value
            if item.value ~= nil then value = item.value else value = tostring(item.label) end
            normalized = {
                label = tostring(item.label),
                value = value,
                description = item.description and tostring(item.description) or nil,
            }
        end
        result[#result + 1] = {
            index = #result + 1,
            label = normalized.label,
            value = normalized.value,
            description = normalized.description,
            search = normalized.label:lower(),
        }
    end
    return result
end

local function compare(left, right)
    if left.rank ~= right.rank then return left.rank < right.rank end
    if left.score ~= right.score then return left.score > right.score end
    if #left.item.label ~= #right.item.label then
        return #left.item.label < #right.item.label
    end
    return left.index < right.index
end

--- Filter normalized suggestions.
-- `mode` is "prefix", "substring" or "fuzzy".
function M.filter(items, query, mode)
    mode = mode or "prefix"
    if mode ~= "prefix" and mode ~= "substring" and mode ~= "fuzzy" then
        error("prompt.suggest: mode must be 'prefix', 'substring' or 'fuzzy'", 3)
    end
    query = tostring(query or "")
    if query == "" then
        local result = {}
        for index, item in ipairs(items) do
            result[#result + 1] = { item = item, score = 0, ranges = {}, index = index }
        end
        return result
    end

    local needle = query:lower()
    local matches = {}
    for index, item in ipairs(items) do
        local label = item.label:lower()
        local rank, score, ranges
        if mode == "prefix" then
            if label:sub(1, #needle) == needle then
                rank, score, ranges = 1, #label, { { 1, #query } }
            end
        elseif mode == "substring" then
            local position = label:find(needle, 1, true)
            if position then
                rank, score, ranges = 1, #label, { { position, position + #query - 1 } }
            end
        else
            local value, found = fuzzy.score(item.label, query)
            if value then
                rank, score, ranges = 1, value, found
            end
        end
        if rank then
            matches[#matches + 1] = {
                item = item, rank = rank, score = score, ranges = ranges, index = index,
            }
        end
    end
    table.sort(matches, compare)
    return matches
end

--- Return the longest common prefix of the matching suggestion labels.
function M.common_prefix(matches)
    if #matches == 0 then return nil end
    local function label_of(match)
        if match.label ~= nil then return match.label end
        if type(match.item) == "table" and match.item.label ~= nil then return match.item.label end
        return tostring(match.item)
    end
    local prefix = label_of(matches[1])
    for index = 2, #matches do
        local label = label_of(matches[index])
        local length = math.min(#prefix, #label)
        local position = 1
        while position <= length and prefix:byte(position) == label:byte(position) do
            position = position + 1
        end
        -- Do not leave a partial UTF-8 sequence behind when labels diverge
        -- inside a multibyte character.
        while position > 1 do
            local byte = prefix:byte(position)
            if byte == nil or byte < 0x80 or byte >= 0xC0 then break end
            position = position - 1
        end
        prefix = prefix:sub(1, position - 1)
        if prefix == "" then return "" end
    end
    return prefix
end

--- Resolve what Tab should insert for `query`.
-- A single match returns its value; several matches return their common
-- prefix when it extends the query.  Returns nil when there is nothing useful.
function M.complete(matches, query)
    if #matches == 0 then return nil end
    local function value_of(match)
        if type(match.item) == "table" then
            if match.item.value ~= nil then return match.item.value end
            if match.item.label ~= nil then return match.item.label end
        end
        if match.value ~= nil then return match.value end
        return match.item
    end
    if #matches == 1 then return value_of(matches[1]) end
    local prefix = M.common_prefix(matches)
    if prefix and #prefix > #tostring(query or "") then return prefix end
    return nil
end

return M
