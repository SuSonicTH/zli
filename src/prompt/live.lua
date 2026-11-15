-- Single-line and block live output shared by progress bars and spinners.

local config = require "prompt.config"
local render = require "prompt.render"
local term = require "term"
local theme_mod = require "prompt.theme"

local M = {}

local Live = {}
Live.__index = Live

function Live:new(screen, plain_start)
    return setmetatable({
        screen = screen or config.get("screen"),
        plain_start = plain_start,
        plain_started = false,
        theme = theme_mod.build(),
        active = false,
        alternate = false,
        shared = config.get("screen_hold"),
        cleared = false,
        finished = false,
        drawn = 0,
    }, self)
end

function Live:columns()
    local size = term.size()
    return size and size.columns or 80
end

function Live:rows()
    local size = term.size()
    return size and size.rows or 24
end

function Live:write_line(spans)
    local columns = self:columns()
    render.write_spans(render.clip(spans, math.max(1, columns - 1), self.theme), self.theme)
end

local function plain_block(lines)
    local result = {}
    for index, line in ipairs(lines) do result[index] = render.plain(line) end
    return result
end

--- Clear an inline block and leave the cursor where the block started.
function Live:clear_inline_block()
    if self.drawn <= 0 then return end
    term.move_by(0, -self.drawn)
    term.move_to_column(1)
    for _ = 1, self.drawn do
        term.clear("line")
        term.write("\n")
    end
    term.move_by(0, -self.drawn)
    self.drawn = 0
end

--- Clear the rows owned by a block in the alternate screen.
function Live:clear_alternate_block()
    if self.drawn <= 0 then return end
    for row = 1, self.drawn do
        term.move_to(1, row)
        term.clear("line")
    end
    self.drawn = 0
    term.move_to(1, 1)
end

function Live:update(spans)
    if M.capture then
        if self.drawn > 0 then
            -- A block was visible before this single-line update.
            self.drawn = 0
        end
        M.capture[#M.capture + 1] = { kind = "update", text = render.plain(spans) }
        return
    end
    if not config.is_interactive() then
        if not self.plain_started and self.plain_start and self.plain_start ~= "" then
            io.write(self.plain_start, "\n")
            io.flush()
        end
        self.plain_started = true
        return
    end
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
            self:clear_alternate_block()
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
        self:clear_inline_block()
        term.write("\r")
        term.clear("line")
        self:write_line(spans)
        term.show_cursor()
    end)
    self.active = true
end

--- Draw several lines in one live region.
-- `lines` is an array of span arrays.  Lines longer than the terminal are
-- clipped; extra lines are dropped.
function Live:update_block(lines)
    if type(lines) ~= "table" then
        error("prompt.live: update_block expects a table of lines", 2)
    end
    local limit = self.screen == "alternate" and self:rows() or math.max(1, self:rows() - 1)
    local count = math.max(1, math.min(#lines, limit))
    local visible = {}
    for index = 1, count do visible[index] = lines[index] or {} end

    if M.capture then
        M.capture[#M.capture + 1] = {
            kind = "update",
            text = table.concat(plain_block(visible), "\n"),
            lines = plain_block(visible),
        }
        self.drawn = count
        return
    end
    if not config.is_interactive() then
        if not self.plain_started and self.plain_start and self.plain_start ~= "" then
            io.write(self.plain_start, "\n")
            io.flush()
        end
        self.plain_started = true
        return
    end
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
            local previous = self.drawn
            for index = 1, count do
                term.move_to(1, index)
                term.clear("line")
                self:write_line(visible[index])
            end
            for row = count + 1, previous do
                term.move_to(1, row)
                term.clear("line")
            end
            self.drawn = count
            term.show_cursor()
        end)
        self.active = true
        return
    end

    term.batch(function()
        term.hide_cursor()
        local previous = self.drawn
        if previous > 0 then
            term.move_by(0, -previous)
            term.move_to_column(1)
        end
        for index = 1, count do
            term.clear("line")
            self:write_line(visible[index])
            term.write("\n")
        end
        if previous > count then
            local stale = previous - count
            for _ = 1, stale do
                term.clear("line")
                term.write("\n")
            end
            term.move_by(0, -stale)
        end
        self.drawn = count
        term.show_cursor()
    end)
    self.active = true
end

function Live:finish(kind, text)
    local spans = render.status(self.theme, kind, text)
    if M.capture then
        M.capture[#M.capture + 1] = { kind = "finish", status = kind, text = text }
        self.drawn = 0
        return
    end
    if not config.is_interactive() then
        if not self.plain_started and self.plain_start and self.plain_start ~= "" then
            io.write(self.plain_start, "\n")
        end
        if text and text ~= "" then
            io.write(render.plain(spans) .. "\n")
        end
        io.flush()
        self.finished = true
        return
    end

    term.batch(function()
        if self.alternate then
            if self.shared then
                self:clear_alternate_block()
                term.move_to(1, 1)
                term.clear("line")
            else
                term.alternate_screen(false)
                self.alternate = false
            end
        else
            term.hide_cursor()
            if self.drawn > 0 then
                self:clear_inline_block()
            else
                term.write("\r")
                term.clear("line")
            end
        end
        self:write_line(spans)
        term.write("\n")
        term.show_cursor()
    end)
    self.active = false
    self.drawn = 0
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
                local had_block = self.drawn > 0
                self:clear_alternate_block()
                if not had_block and self.active then
                    term.move_to(1, 1)
                    term.clear("line")
                end
            else
                term.alternate_screen(false)
                self.alternate = false
            end
        elseif self.drawn > 0 then
            self:clear_inline_block()
        elseif self.active then
            term.write("\r")
            term.clear("line")
            term.write("\n")
        end
        term.show_cursor()
    end)
    self.active = false
    self.drawn = 0
    self.finished = true
end

function M.new(screen, plain_start)
    return Live:new(screen, plain_start)
end

return M
