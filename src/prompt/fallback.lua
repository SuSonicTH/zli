-- Plain-text prompts used when stdin or stdout is not a terminal.

local config = require "prompt.config"
local items_mod = require "prompt.items"

local M = {}

local function out(text)
    io.write(text)
    io.flush()
end

local function read_line()
    local line = io.read("l")
    if line == nil then return nil end
    return line
end

local function trim(text)
    return (text:gsub("^%s+", ""):gsub("%s+$", ""))
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

local function invalid(message)
    if message then out(message .. "\n") end
end

function M.select(options, items, selected)
    out("? " .. options.message .. "\n")
    for _, item in ipairs(items) do
        local marker = item.index == selected and " (default)" or ""
        local disabled = item.disabled and " (disabled)" or ""
        out(string.format("  %d) %s%s%s\n", item.index, item.label, disabled, marker))
    end
    local hint = selected and (" [" .. selected .. "]") or ""
    out("choice" .. hint .. ": ")

    while true do
        local line = read_line()
        if line == nil then return eof_result(selected and items[selected].value or nil) end
        line = trim(line)
        if line == "" then
            if selected then return items[selected].value end
            invalid("Please choose one of the listed numbers.")
        else
            local number = tonumber(line)
            local item
            if number and items[number] then
                item = items[number]
            else
                for _, candidate in ipairs(items) do
                    if candidate.label == line then item = candidate break end
                end
            end
            if item == nil then
                invalid("Unknown choice '" .. line .. "'.")
            elseif item.disabled then
                invalid("That choice is disabled.")
            elseif options.return_index then
                return item.index
            else
                return item.value
            end
        end
        out("choice: ")
    end
end

local function default_values(items, set)
    local values = items_mod.selected_values(items, set)
    if #values == 0 then return {} end
    return values
end

function M.multiselect(options, items, selected)
    out("? " .. options.message .. "\n")
    for _, item in ipairs(items) do
        local mark = selected[item.index] and "[x]" or "[ ]"
        local disabled = item.disabled and " (disabled)" or ""
        out(string.format("  %s %d) %s%s\n", mark, item.index, item.label, disabled))
    end
    out("choices (comma separated, a=all, n=none, blank=default): ")

    while true do
        local line = read_line()
        if line == nil then
            if options.has_default then return default_values(items, selected) end
            return eof_result(nil)
        end
        line = trim(line):lower()
        if line == "" then
            return default_values(items, selected)
        elseif line == "a" then
            for _, item in ipairs(items) do
                if not item.disabled then selected[item.index] = true end
            end
        elseif line == "n" then
            selected = {}
        else
            local next_set = {}
            local valid = true
            for token in line:gmatch("[^,%s]+") do
                local number = tonumber(token)
                if not number or not items[number] then
                    invalid("Unknown choice '" .. token .. "'.")
                    valid = false
                    break
                elseif items[number].disabled then
                    invalid("Choice " .. number .. " is disabled.")
                    valid = false
                    break
                end
                next_set[number] = true
            end
            if valid then selected = next_set end
        end

        local count = 0
        for _ in pairs(selected) do count = count + 1 end
        local minimum = options.required and math.max(1, options.min or 0) or (options.min or 0)
        if count < minimum then
            invalid("Choose at least " .. minimum .. ".")
        elseif options.max and count > options.max then
            invalid("Choose at most " .. options.max .. ".")
        else
            return items_mod.selected_values(items, selected)
        end
        out("choices: ")
    end
end

local function prompt_text(options, default, password)
    local suffix = ""
    if password then
        suffix = default and " [hidden]" or ""
    elseif default ~= nil and default ~= "" then
        suffix = " [" .. default .. "]"
    elseif options.placeholder then
        suffix = " (" .. options.placeholder .. ")"
    end
    out("? " .. options.message .. suffix .. ": ")
    local line = read_line()
    if line == nil then
        if default ~= nil then return eof_result(default) end
        return eof_result(nil)
    end
    if line == "" then
        if default ~= nil then return default end
        return ""
    end
    return line
end

function M.text(options, default)
    return prompt_text(options, default, false)
end

function M.password(options)
    return prompt_text(options, nil, true)
end

function M.multiline(options, default)
    out("? " .. options.message .. " (end with a line containing .)\n")
    local lines = {}
    while true do
        local line = read_line()
        if line == nil then
            if #lines == 0 then
                if default ~= nil then return eof_result(default) end
                return eof_result(nil)
            end
            break
        end
        if line == "." then break end
        lines[#lines + 1] = line
    end
    if #lines == 0 and default ~= nil then return default end
    return table.concat(lines, "\n")
end

function M.confirm(options)
    local default = options.default
    local hint = default == true and " [Y/n]" or default == false and " [y/N]" or " [y/n]"
    out("? " .. options.message .. hint .. ": ")
    while true do
        local line = read_line()
        if line == nil then
            if default ~= nil then return default end
            return eof_result(nil)
        end
        line = trim(line):lower()
        if line == "" and default ~= nil then return default end
        if line == "y" or line == "yes" then return true end
        if line == "n" or line == "no" then return false end
        invalid("Please answer y or n.")
        out("? " .. options.message .. hint .. ": ")
    end
end

function M.pause() end

return M
