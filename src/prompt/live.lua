-- Single-line live output shared by progress bars and spinners.

local config = require "prompt.config"
local render = require "prompt.render"
local term = require "term"
local theme_mod = require "prompt.theme"

local M = {}

local Live = {}
Live.__index = Live

function Live:new(screen)
    return setmetatable({
        screen = screen or require("prompt.config").get("screen"),
        theme = theme_mod.build(),
        active = false,
        alternate = false,
        shared = config.get("screen_hold"),
        cleared = false,
        finished = false,
    }, self)
end

function Live:columns()
    local size = term.size()
    return size and size.columns or 80
end

function Live:write_line(spans)
    local columns = self:columns()
    render.write_spans(render.clip(spans, math.max(1, columns - 1), self.theme), self.theme)
end

function Live:update(spans)
    if M.capture then
        M.capture[#M.capture + 1] = { kind = "update", text = render.plain(spans) }
        return
    end
    if not config.is_interactive() then return end
    self.finished = false

    if self.screen == "alternate" then
        term.batch(function()
            if not self.alternate then
                if not self.shared then term.alternate_screen(true) end
                self.alternate = true
            end
            if not self.cleared then
                term.clear("all")
                self.cleared = true
            end
            term.hide_cursor()
            term.move_to(1, 1)
            term.clear("line")
            self:write_line(spans)
            term.show_cursor()
        end)
        self.active = true
        return
    end

    term.batch(function()
        term.hide_cursor()
        term.write("\r")
        term.clear("line")
        self:write_line(spans)
        term.show_cursor()
    end)
    self.active = true
end

function Live:finish(kind, text)
    local spans = render.status(self.theme, kind, text)
    if M.capture then
        M.capture[#M.capture + 1] = { kind = "finish", status = kind, text = text }
        return
    end
    if not config.is_interactive() then
        if text and text ~= "" then
            io.write(render.plain(spans) .. "\n")
            io.flush()
        end
        self.finished = true
        return
    end

    term.batch(function()
        if self.alternate then
            if self.shared then
                term.move_to(1, 1)
                term.clear("line")
            else
                term.alternate_screen(false)
                self.alternate = false
            end
        else
            term.write("\r")
            term.clear("line")
        end
        self:write_line(spans)
        term.write("\n")
        term.show_cursor()
    end)
    self.active = false
    self.finished = true
end

function Live:close()
    if M.capture then return end
    if not config.is_interactive() then
        self.finished = true
        return
    end
    term.batch(function()
        if self.alternate then
            if self.shared then
                term.move_to(1, 1)
                term.clear("line")
            else
                term.alternate_screen(false)
                self.alternate = false
            end
        elseif self.active then
            term.write("\r")
            term.clear("line")
            term.write("\n")
        end
        term.show_cursor()
    end)
    self.active = false
    self.finished = true
end

function M.new(screen)
    return Live:new(screen)
end

return M
