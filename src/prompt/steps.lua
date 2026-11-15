-- One-line step indicator used by `prompt.wizard`.

local term = require "term"
local theme_mod = require "prompt.theme"

local M = {}

local function title_of(step)
    if type(step) == "table" then
        return tostring(step.title or step.label or step.name or "Step")
    end
    return tostring(step)
end

function M.steps(options)
    if type(options) ~= "table" then
        error("prompt.steps: expecting an options table", 3)
    end
    if type(options.steps) ~= "table" or #options.steps == 0 then
        error("prompt.steps: steps must be a non-empty table", 3)
    end
    local current = options.current == nil and 1 or options.current
    if type(current) ~= "number" or current % 1 ~= 0 or current < 1 or current > #options.steps then
        error("prompt.steps: current must be an index into steps", 3)
    end
    if options.width ~= nil and (type(options.width) ~= "number" or options.width < 1) then
        error("prompt.steps: width must be a positive number", 3)
    end

    local theme = theme_mod.build()
    local parts = {}
    local titles = {}
    for index, step in ipairs(options.steps) do
        titles[index] = title_of(step)
        local marker
        if index < current then
            marker = theme.symbol("step_done")
        elseif index == current then
            marker = theme.symbol("step_active")
        else
            marker = theme.symbol("step_pending")
        end
        parts[index] = marker .. " " .. titles[index]
    end

    local full = table.concat(parts, "  ")
    local width = options.width
    if width == nil then
        local size = term.size()
        width = size and size.columns or 80
    end
    if term.width(full) <= width then return full end

    local narrow = current .. "/" .. #options.steps .. " " .. titles[current]
    if term.width(narrow) <= width then return narrow end
    return term.truncate(narrow, math.floor(width))
end

return setmetatable(M, { __call = function(_, options) return M.steps(options) end })
