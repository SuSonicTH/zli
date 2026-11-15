-- Time-throttled spinner with optional elapsed time.

local config = require "prompt.config"
local live = require "prompt.live"
local render = require "prompt.render"
local theme_mod = require "prompt.theme"

local M = {}

local unicode_frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
local ascii_frames = { "|", "/", "-", "\\" }

local function duration(seconds)
    seconds = math.max(0, math.floor(seconds))
    if seconds < 60 then return seconds .. "s" end
    return string.format("%dm%02ds", math.floor(seconds / 60), seconds % 60)
end

local Spinner = {}
Spinner.__index = Spinner

function Spinner:new(options)
    options = options or {}
    if options.text ~= nil and type(options.text) ~= "string" then
        error("prompt.spinner: text must be a string", 3)
    end
    local frames = options.frames
    if frames ~= nil then
        if type(frames) ~= "table" or #frames == 0 then
            error("prompt.spinner: frames must be a non-empty table", 3)
        end
    end
    local interval = options.interval or config.get("spinner_interval")
    if type(interval) ~= "number" or interval <= 0 then
        error("prompt.spinner: interval must be a positive number", 3)
    end

    if options.screen ~= nil and options.screen ~= "inline" and options.screen ~= "alternate" then
        error("prompt.spinner: screen must be 'inline' or 'alternate'", 3)
    end
    local spinner = setmetatable({
        options = options,
        text = options.text or "",
        frames = frames,
        interval = interval,
        index = 0,
        started = os.nanotime(),
        last_render = 0,
        rendered = false,
        live = live.new(options.screen),
        finished = false,
    }, self)
    spinner.theme = theme_mod.build()
    spinner.frames = spinner.frames or (spinner.theme.unicode and unicode_frames or ascii_frames)
    return spinner
end

function Spinner:line()
    local frame = self.frames[(self.index % #self.frames) + 1]
    local spans = {
        render.span(frame, "accent"),
        render.span(" " .. self.text, "message"),
    }
    if self.options.show_elapsed then
        local elapsed = os.nanotime() - self.started
        spans[#spans + 1] = render.span(" " .. duration(elapsed), "muted")
    end
    return spans
end

function Spinner:step(text, force)
    if self.finished then return self end
    if text ~= nil then self.text = tostring(text) end
    local now = os.nanotime()
    if not self.rendered then force = true end
    if not force and (now - self.last_render) < self.interval then return self end
    self.last_render = now
    self.rendered = true
    self.index = self.index + 1
    self.live:update(self:line())
    return self
end

function Spinner:set_text(text)
    self.text = tostring(text or "")
    return self:step(nil, true)
end

function Spinner:finish(text)
    if self.finished then return self end
    local message = text or self.text
    if message == "" then message = "done" end
    self.live:finish("success", message)
    self.finished = true
    return self
end

function Spinner:fail(text)
    if self.finished then return self end
    self.live:finish("danger", text or (self.text ~= "" and self.text or "failed"))
    self.finished = true
    return self
end

function Spinner:close()
    if not self.finished then self.live:close() end
    self.finished = true
end

Spinner.__close = Spinner.close

return function(options)
    return Spinner:new(options)
end
