-- Progress bars with optional count, percent, rate and ETA.

local config = require "prompt.config"
local live = require "prompt.live"
local render = require "prompt.render"
local theme_mod = require "prompt.theme"

local M = {}

local allowed = {
    label = true, bar = true, percent = true, count = true, total = true,
    elapsed = true, rate = true, eta = true, items = true,
}

local function clamp(value, minimum, maximum)
    if value < minimum then return minimum end
    if maximum and value > maximum then return maximum end
    return value
end

local function duration(seconds)
    seconds = math.max(0, math.floor(seconds))
    if seconds < 60 then return seconds .. "s" end
    if seconds < 3600 then return string.format("%dm%02ds", math.floor(seconds / 60), seconds % 60) end
    return string.format("%dh%02dm", math.floor(seconds / 3600), math.floor((seconds % 3600) / 60))
end

local Progress = {}
Progress.__index = Progress

function Progress:new(options)
    options = options or {}
    if options.items ~= nil and type(options.items) ~= "table" then
        error("prompt.progress: items must be a table", 3)
    end
    if options.bar_width ~= nil and (type(options.bar_width) ~= "number" or options.bar_width < 1) then
        error("prompt.progress: bar_width must be a positive number", 3)
    end
    if options.min_interval ~= nil and (type(options.min_interval) ~= "number" or options.min_interval < 0) then
        error("prompt.progress: min_interval must be zero or positive", 3)
    end
    local total = options.total
    if total == nil and options.items then total = #options.items end
    if total ~= nil and (type(total) ~= "number" or total < 0) then
        error("prompt.progress: total must be a non-negative number", 3)
    end
    if options.show ~= nil and options.show ~= "percent" and options.show ~= "count"
        and options.show ~= "both" and options.show ~= "bar" then
        error("prompt.progress: show must be 'bar', 'percent', 'count' or 'both'", 3)
    end
    if options.template then
        if type(options.template) ~= "string" then
            error("prompt.progress: template must be a string", 3)
        end
        for name in options.template:gmatch("{([%a_]+)}") do
            if not allowed[name] then
                error("prompt.progress: unknown template field '" .. name .. "'", 3)
            end
        end
    end
    if options.label ~= nil and type(options.label) ~= "string" then
        error("prompt.progress: label must be a string", 3)
    end

    if options.screen ~= nil and options.screen ~= "inline" and options.screen ~= "alternate" then
        error("prompt.progress: screen must be 'inline' or 'alternate'", 3)
    end
    local progress = setmetatable({
        options = options,
        total = total,
        current = 0,
        label = options.label or "",
        started = os.nanotime(),
        last_render = 0,
        rendered = false,
        interval = options.min_interval or config.get("progress_interval"),
        live = live.new(options.screen),
        finished = false,
    }, self)
    progress.theme = theme_mod.build()
    return progress
end

function Progress:bar(width)
    local ratio
    if self.total then
        ratio = self.total == 0 and 1 or clamp(self.current / self.total, 0, 1)
    else
        ratio = nil
    end
    local full, empty = self.theme.symbol("bar_full"), self.theme.symbol("bar_empty")
    local parts = {}
    if ratio then
        local fill = math.floor(ratio * width)
        for index = 1, width do parts[index] = index <= fill and full or empty end
    else
        local elapsed = os.nanotime() - self.started
        local block = math.max(3, math.floor(width / 5))
        local position = math.floor(elapsed * 8) % (width + block)
        for index = 1, width do
            parts[index] = (index >= position and index < position + block) and full or empty
        end
    end
    return table.concat(parts)
end

function Progress:value(name, width)
    if name == "label" then return self.label end
    if name == "bar" then return "[" .. self:bar(width) .. "]" end
    if name == "percent" then
        if not self.total or self.total == 0 then return "" end
        return tostring(math.floor(clamp(self.current / self.total, 0, 1) * 100)) .. "%"
    end
    if name == "count" then
        if self.total then return tostring(self.current) .. "/" .. tostring(self.total) end
        return tostring(self.current)
    end
    if name == "total" then return self.total and tostring(self.total) or "" end
    if name == "items" then return self.options.items and tostring(#self.options.items) or "" end
    local elapsed = math.max(0, os.nanotime() - self.started)
    if name == "elapsed" then return duration(elapsed) end
    if name == "rate" then
        if elapsed <= 0 then return "0/s" end
        return string.format("%.1f/s", self.current / elapsed)
    end
    if name == "eta" then
        if not self.total or self.total == 0 or self.current <= 0 then return "" end
        local rate = self.current / elapsed
        if rate <= 0 then return "" end
        return duration((self.total - self.current) / rate)
    end
    return ""
end

function Progress:line()
    local size = require("term").size() or { columns = 80 }
    local width = self.options.bar_width or math.min(24, math.max(8, size.columns - 34))
    local text
    if self.options.template then
        text = self.options.template:gsub("{([%a_]+)}", function(name)
            return self:value(name, width)
        end)
        text = text:gsub(" +", " "):gsub("^%s+", ""):gsub("%s+$", "")
        return render.line(render.span(text, "message"))
    end

    local spans = {}
    if self.label ~= "" then
        spans[#spans + 1] = render.span(self.label .. " ", "message")
    end
    spans[#spans + 1] = render.span("[", "muted")
    spans[#spans + 1] = render.span(self:bar(width), "accent")
    spans[#spans + 1] = render.span("]", "muted")

    local show = self.options.show or (self.total and "both" or "bar")
    if show == "percent" or show == "both" then
        spans[#spans + 1] = render.span(" " .. self:value("percent"), "accent")
    end
    if show == "count" or show == "both" then
        spans[#spans + 1] = render.span(" " .. self:value("count"), "muted")
    end
    return spans
end

function Progress:draw(force)
    if self.finished then return self end
    local now = os.nanotime()
    if not self.rendered then force = true end
    if not force and (now - self.last_render) < self.interval then return self end
    self.last_render = now
    self.rendered = true
    self.live:update(self:line())
    return self
end

function Progress:update(value)
    value = tonumber(value) or 0
    self.current = clamp(value, 0, self.total)
    return self:draw(false)
end

function Progress:advance(amount)
    return self:update(self.current + (amount or 1))
end

function Progress:set_total(total)
    if type(total) ~= "number" or total < 0 then
        error("prompt.progress: total must be a non-negative number", 2)
    end
    self.total = total
    self.current = clamp(self.current, 0, total)
    return self:draw(true)
end

function Progress:set_label(label)
    self.label = tostring(label or "")
    return self:draw(true)
end

function Progress:finish(text)
    if self.finished then return self end
    if self.total then self.current = self.total end
    local message = text or self.label
    if message == "" then message = "done" end
    self.live:finish("success", message)
    self.finished = true
    return self
end

function Progress:fail(text)
    if self.finished then return self end
    self.live:finish("danger", text or (self.label ~= "" and self.label or "failed"))
    self.finished = true
    return self
end

function Progress:close()
    if not self.finished then self.live:close() end
    self.finished = true
end

Progress.__close = Progress.close

function M.progress(options)
    return Progress:new(options)
end

function M.each(items, options)
    if type(items) ~= "table" then
        error("prompt.progress.each: expecting an items table", 2)
    end
    local progress_options = {}
    for key, value in pairs(options or {}) do progress_options[key] = value end
    progress_options.total = #items
    if progress_options.label == nil then progress_options.label = "Working" end
    local progress = Progress:new(progress_options)
    local index = 0
    local function iterator()
        index = index + 1
        if index > #items then
            progress:finish()
            return nil
        end
        progress:update(index - 1)
        return index, items[index]
    end
    return iterator, nil, nil, progress
end

return setmetatable({ each = M.each }, { __call = function(_, options) return M.progress(options) end })
