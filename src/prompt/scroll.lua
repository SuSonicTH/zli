-- Shared vertical viewport math for lists, viewers and forms.

local M = {}

local Scroll = {}
Scroll.__index = Scroll

local function positive(value, name, default)
    if value == nil then return default end
    if type(value) ~= "number" or value < 1 then
        error("prompt.scroll: " .. name .. " must be a positive number", 3)
    end
    return math.floor(value)
end

local function count(value, name)
    if value == nil then return 0 end
    if type(value) ~= "number" or value < 0 then
        error("prompt.scroll: " .. name .. " must be zero or positive", 3)
    end
    return math.floor(value)
end

function M.new(options)
    options = options or {}
    if type(options) ~= "table" then
        error("prompt.scroll: expecting an options table", 2)
    end
    return setmetatable({
        rows = count(options.rows, "rows"),
        height = positive(options.height, "height", 1),
        top = 1,
    }, Scroll)
end

function Scroll:set_rows(rows)
    self.rows = count(rows, "rows")
    self:clamp()
    return self
end

function Scroll:set_height(height)
    self.height = positive(height, "height", 1)
    self:clamp()
    return self
end

function Scroll:max_top()
    if self.rows <= 0 then return 1 end
    return math.max(1, self.rows - self.height + 1)
end

function Scroll:clamp()
    self.top = math.max(1, math.min(self.top or 1, self:max_top()))
    return self
end

function Scroll:move(delta)
    self.top = (self.top or 1) + (delta or 1)
    return self:clamp()
end

function Scroll:page(delta)
    return self:move((delta or 1) * self.height)
end

function Scroll:home()
    self.top = 1
    return self
end

function Scroll:last()
    self.top = self:max_top()
    return self
end

function Scroll:follow(index)
    if index == nil then return self end
    if index < self.top then self.top = index end
    if index > self.top + self.height - 1 then self.top = index - self.height + 1 end
    return self:clamp()
end

function Scroll:reset(rows)
    self.top = 1
    if rows ~= nil then self.rows = count(rows, "rows") end
    return self:clamp()
end

function Scroll:visible()
    if self.rows <= 0 then return 1, 0 end
    local first = math.max(1, math.min(self.top, self.rows))
    local last = math.min(self.rows, first + self.height - 1)
    return first, last
end

function Scroll:has_above()
    return self.top > 1
end

function Scroll:has_below()
    return self.top + self.height - 1 < self.rows
end

return M
