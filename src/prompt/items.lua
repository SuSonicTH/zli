-- Normalisation and lookup helpers shared by list components.

local M = {}

local function value_of(item)
    if item.value ~= nil then return item.value end
    return item.label
end

function M.normalize(items, options)
    if type(items) ~= "table" then
        error("prompt: items must be a table", 3)
    end
    local result = {}
    for index, item in ipairs(items) do
        if type(item) == "string" or type(item) == "number" then
            result[#result + 1] = {
                index = #result + 1,
                label = tostring(item),
                value = item,
            }
        elseif type(item) == "table" then
            local label = item.label
            if label == nil then
                error("prompt: item " .. index .. " needs a label", 3)
            end
            local value = value_of(item)
            result[#result + 1] = {
                index = #result + 1,
                label = tostring(label),
                value = value,
                description = item.description and tostring(item.description) or nil,
                disabled = item.disabled and true or false,
                checked = item.checked and true or false,
            }
        else
            error("prompt: item " .. index .. " must be a string or a table", 3)
        end
    end
    if #result == 0 then
        error("prompt: items must not be empty", 3)
    end
    for _, item in ipairs(result) do
        item.search = item.label:lower()
        if item.description then item.search = item.search .. " " .. item.description:lower() end
    end
    return result
end

function M.find(items, value)
    if value == nil then return nil end
    for _, item in ipairs(items) do
        if item.value == value then return item.index end
    end
    return nil
end

function M.find_index(items, index)
    if index == nil then return nil end
    if type(index) ~= "number" or items[index] == nil then return nil end
    return index
end

function M.first_enabled(items)
    for _, item in ipairs(items) do
        if not item.disabled then return item.index end
    end
    return 1
end

function M.default_index(items, default, default_index)
    local index = M.find_index(items, default_index)
    if index and not items[index].disabled then return index end
    index = M.find(items, default)
    if index and not items[index].disabled then return index end
    return nil
end

function M.default_set(items, default, default_indices)
    local set = {}
    if type(default_indices) == "table" then
        for _, index in ipairs(default_indices) do
            if items[index] and not items[index].disabled then set[index] = true end
        end
    end
    if type(default) == "table" then
        for _, value in ipairs(default) do
            local index = M.find(items, value)
            if index and not items[index].disabled then set[index] = true end
        end
    elseif default ~= nil then
        local index = M.find(items, default)
        if index and not items[index].disabled then set[index] = true end
    end
    return set
end

function M.selected_values(items, set)
    local values = {}
    for _, item in ipairs(items) do
        if set[item.index] then values[#values + 1] = item.value end
    end
    return values
end

function M.filter(items, query)
    if query == nil or query == "" then return items end
    local needle = query:lower()
    local result = {}
    for _, item in ipairs(items) do
        if item.search:find(needle, 1, true) then result[#result + 1] = item end
    end
    return result
end

return M
