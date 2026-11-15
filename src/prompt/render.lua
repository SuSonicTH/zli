-- Frame model and inline/alternate presenters.

local term = require "term"
local config = require "prompt.config"
local theme_mod = require "prompt.theme"

local M = {}

local function normalize_span(value)
    if type(value) == "string" then return { text = value } end
    if type(value) ~= "table" then return { text = tostring(value) } end
    return { text = tostring(value.text or ""), style = value.style }
end

local function normalize_line(line)
    if type(line) == "string" then return { { text = line } } end
    if type(line) ~= "table" then return { { text = tostring(line) } } end
    if line.text ~= nil then return { normalize_span(line) } end
    local spans = {}
    for _, span in ipairs(line) do spans[#spans + 1] = normalize_span(span) end
    if line.help then spans.help = true end
    return spans
end

function M.frame(lines, cursor)
    local result = { lines = {}, cursor = cursor }
    for _, line in ipairs(lines or {}) do
        result.lines[#result.lines + 1] = normalize_line(line)
    end
    if #result.lines == 0 then result.lines[1] = {} end
    return result
end

function M.span(text, style)
    return { text = tostring(text), style = style }
end

function M.line(...)
    local spans = {}
    for index = 1, select("#", ...) do
        local value = select(index, ...)
        if type(value) == "table" and value.text ~= nil then
            spans[#spans + 1] = normalize_span(value)
        elseif type(value) == "table" then
            for _, span in ipairs(value) do spans[#spans + 1] = normalize_span(span) end
        else
            spans[#spans + 1] = { text = tostring(value) }
        end
    end
    return spans
end

function M.width(spans)
    local total = 0
    for _, span in ipairs(spans) do
        total = term.width(string.rep(" ", total) .. span.text)
    end
    return total
end

function M.plain(spans)
    local parts = {}
    for _, span in ipairs(spans) do parts[#parts + 1] = span.text end
    return table.concat(parts)
end

function M.clip(spans, columns, symbols)
    if columns <= 0 then return {} end
    local total = M.width(spans)
    if total <= columns then return spans end

    local ellipsis = symbols and symbols.symbol("ellipsis") or "..."
    local ellipsis_width = term.width(ellipsis)
    local budget = columns
    local add_ellipsis = false
    if ellipsis_width > 0 and ellipsis_width < columns then
        budget = columns - ellipsis_width
        add_ellipsis = true
    end

    local result = {}
    local used = 0
    for _, span in ipairs(spans) do
        if used >= budget then break end
        local prefixed = string.rep(" ", used) .. span.text
        local combined = term.width(prefixed)
        if combined <= budget then
            result[#result + 1] = span
            used = combined
        else
            local text = term.truncate(prefixed, budget, "")
            text = text:sub(used + 1)
            if text ~= "" then
                result[#result + 1] = { text = text, style = span.style }
            end
            used = budget
            break
        end
    end
    if add_ellipsis then
        result[#result + 1] = { text = ellipsis, style = "muted" }
    end
    return result
end

function M.write_spans(spans, theme)
    for _, span in ipairs(spans) do
        theme.reset()
        theme.apply(span.style)
        term.write(span.text)
    end
    theme.reset()
end

local function byte_length(byte)
    if byte == nil then return 1 end
    if byte < 0x80 then return 1 end
    if byte < 0xC0 then return 1 end
    if byte < 0xE0 then return 2 end
    if byte < 0xF0 then return 3 end
    return 4
end

local function escape_length(text, index)
    local next_byte = text:byte(index + 1)
    if next_byte == nil then return 1 end
    if next_byte == 0x5B then -- CSI
        local position = index + 2
        while position <= #text do
            local byte = text:byte(position)
            if byte >= 0x40 and byte <= 0x7E then return position - index + 1 end
            position = position + 1
        end
        return #text - index + 1
    end
    if next_byte == 0x5D or next_byte == 0x50 or next_byte == 0x5E or next_byte == 0x5F then
        local position = index + 2
        while position <= #text do
            local byte = text:byte(position)
            if byte == 0x07 then return position - index + 1 end
            if byte == 0x1B and text:byte(position + 1) == 0x5C then
                return position - index + 2
            end
            position = position + 1
        end
        return #text - index + 1
    end
    return 2
end

--- Wrap spans into display lines without splitting escape sequences.
-- Tabs advance to the next eight-column stop when they fit; a tab that would
-- overflow is expanded to spaces up to the column budget.  Newlines start a
-- new line.
function M.wrap_spans(spans, columns)
    if type(columns) ~= "number" or columns < 1 then
        error("prompt.wrap_spans: columns must be a positive number", 2)
    end
    columns = math.floor(columns)

    local lines = { {} }
    local used = 0

    local function new_line()
        lines[#lines + 1] = {}
        used = 0
    end

    local function append(text, style)
        local line = lines[#lines]
        local last = line[#line]
        if last and last.style == style then
            last.text = last.text .. text
        else
            line[#line + 1] = { text = text, style = style }
        end
    end

    for _, span in ipairs(spans or {}) do
        local text = tostring(span.text or "")
        local style = span.style
        local index = 1
        while index <= #text do
            local byte = text:byte(index)
            if byte == 0x0A then
                new_line()
                index = index + 1
            elseif byte == 0x09 then
                local advance = 8 - (used % 8)
                if used > 0 and used + advance > columns then
                    new_line()
                    advance = 8
                end
                if used + advance > columns then
                    -- A tab cannot fit on this line; expand it to the
                    -- remaining width instead of overflowing.
                    local spaces = math.max(1, math.min(advance, columns - used))
                    append(string.rep(" ", spaces), style)
                    used = used + spaces
                else
                    append("\t", style)
                    used = used + advance
                end
                index = index + 1
            elseif byte == 0x1B then
                local length = escape_length(text, index)
                append(text:sub(index, index + length - 1), style)
                index = index + length
            else
                local length = byte_length(byte)
                if index + length - 1 > #text then length = 1 end
                local char = text:sub(index, index + length - 1)
                local width = term.width(char)
                if used > 0 and used + width > columns then new_line() end
                append(char, style)
                used = used + width
                index = index + length
            end
        end
    end
    return lines
end

--- Slice `lines` to a height-limited viewport.
-- Returns the visible slice, the clamped first index and the last index.
function M.viewport(lines, top, height)
    lines = lines or {}
    if #lines == 0 then return {}, 1, 0 end
    top = math.floor(tonumber(top) or 1)
    height = math.max(1, math.floor(tonumber(height) or #lines))
    top = math.max(1, math.min(top, #lines))
    local last = math.min(#lines, top + height - 1)
    local result = {}
    for index = top, last do result[#result + 1] = lines[index] end
    return result, top, last
end

--- Pad spans to `width` display columns.
-- `align` is "left" (default), "right" or "center".
function M.pad(spans, width, align)
    if type(width) ~= "number" or width < 0 then
        error("prompt.pad: width must be zero or positive", 2)
    end
    align = align or "left"
    if align ~= "left" and align ~= "right" and align ~= "center" then
        error("prompt.pad: align must be 'left', 'right' or 'center'", 2)
    end
    local used = M.width(spans)
    local gap = math.floor(width) - used
    if gap <= 0 then return spans end

    local left = 0
    local right = gap
    if align == "right" then
        left, right = gap, 0
    elseif align == "center" then
        left = math.floor(gap / 2)
        right = gap - left
    end

    local result = {}
    if left > 0 then result[#result + 1] = { text = string.rep(" ", left) } end
    for _, span in ipairs(spans) do result[#result + 1] = span end
    if right > 0 then result[#result + 1] = { text = string.rep(" ", right) } end
    return result
end

local function copy_spans(spans)
    local result = {}
    for index, span in ipairs(spans) do
        result[index] = { text = span.text, style = span.style }
    end
    return result
end

local function copy_frame(frame)
    local result = { lines = {}, cursor = frame.cursor and { row = frame.cursor.row, column = frame.cursor.column } }
    for index, line in ipairs(frame.lines) do result.lines[index] = copy_spans(line) end
    return result
end

local Capture = {}
Capture.__index = Capture

function Capture:draw(frame)
    self.frames[#self.frames + 1] = copy_frame(frame)
end

function Capture:commit(kind, summary, final_frame)
    self.commits[#self.commits + 1] = {
        kind = kind,
        summary = summary and copy_spans(summary),
        frame = final_frame and copy_frame(final_frame),
    }
end

function Capture:close() end

local Inline = {}
Inline.__index = Inline

local function terminal_size()
    local size = term.size()
    if not size then return { columns = 80, rows = 24 } end
    return size
end

function Inline:new(theme)
    return setmetatable({
        theme = theme,
        drawn = 0,
        cursor_row = nil,
    }, self)
end

function Inline:to_bottom()
    if self.cursor_row then
        term.move_by(0, self.drawn - self.cursor_row + 1)
        self.cursor_row = nil
    end
end

function Inline:draw(frame)
    local size = terminal_size()
    local max_lines = math.max(1, size.rows - 1)
    if self.drawn > max_lines then
        self.drawn = 0
        self.cursor_row = nil
    end

    local lines = {}
    for index, line in ipairs(frame.lines) do
        if index > max_lines then break end
        lines[#lines + 1] = M.clip(line, size.columns, self.theme)
    end
    if #lines == 0 then lines[1] = {} end

    term.batch(function()
        term.hide_cursor()
        self:to_bottom()
        if self.drawn > 0 then
            term.move_by(0, -self.drawn)
            term.move_to_column(1)
        end

        for _, line in ipairs(lines) do
            term.clear("line")
            M.write_spans(line, self.theme)
            term.write("\n")
        end

        local count = #lines
        if count < self.drawn then
            local stale = self.drawn - count
            for _ = 1, stale do
                term.clear("line")
                term.write("\n")
            end
            term.move_by(0, -stale)
        end
        self.drawn = count

        local cursor = frame.cursor
        if cursor and cursor.row and cursor.row >= 1 and cursor.row <= count then
            local row = math.min(cursor.row, count)
            term.move_by(0, -(count - row + 1))
            term.move_to_column(math.max(1, math.min((cursor.column or 0) + 1, size.columns)))
            term.show_cursor()
            self.cursor_row = row
        else
            term.hide_cursor()
        end
    end)
end

function Inline:commit(kind, summary, frame)
    if M.capture then
        self.frames[#self.frames + 1] = { kind = kind, summary = summary, frame = frame }
        return
    end
    term.batch(function()
        term.hide_cursor()
        self:to_bottom()
        if self.drawn > 0 then
            term.move_by(0, -self.drawn)
            term.move_to_column(1)
            for _ = 1, self.drawn do
                term.clear("line")
                term.write("\n")
            end
            term.move_by(0, -self.drawn)
        end
        self.drawn = 0
        self.cursor_row = nil

        if kind == "summary" and summary then
            M.write_spans(summary, self.theme)
            term.write("\n")
        elseif kind == "frame" and frame then
            local size = terminal_size()
            for _, line in ipairs(frame.lines) do
                M.write_spans(M.clip(line, size.columns, self.theme), self.theme)
                term.write("\n")
            end
        end
        term.show_cursor()
    end)
end

function Inline:close()
    self:commit("none")
end

local Alternate = {}
Alternate.__index = Alternate

function Alternate:new(theme)
    return setmetatable({
        theme = theme,
        active = false,
        shared = config.get("screen_hold"),
    }, self)
end

function Alternate:enter()
    if self.active then return end
    if not self.shared then term.alternate_screen(true) end
    term.hide_cursor()
    self.active = true
end

function Alternate:draw(frame)
    term.batch(function()
        self:enter()
        local size = terminal_size()
        local content_width = math.min(size.columns, 80)
        local left = math.max(1, math.floor((size.columns - content_width) / 2) + 1)
        term.clear("all")
        local max_lines = math.max(1, size.rows)
        for index, line in ipairs(frame.lines) do
            if index > max_lines then break end
            term.move_to(left, index)
            term.clear("line")
            M.write_spans(M.clip(line, content_width, self.theme), self.theme)
        end

        local cursor = frame.cursor
        if cursor and cursor.row and cursor.row >= 1 and cursor.row <= max_lines then
            term.move_to(left + math.min(cursor.column or 0, content_width - 1), cursor.row)
            term.show_cursor()
        else
            term.hide_cursor()
        end
    end)
end

function Alternate:commit(kind, summary, frame)
    if self.shared then
        -- In a shared alternate screen the next prompt clears the frame
        -- immediately.  Printing a summary here only flashes for one frame,
        -- so leave the screen untouched until the next draw or scope exit.
        self.active = true
        return
    end

    term.batch(function()
        if self.active then
            term.alternate_screen(false)
            self.active = false
        end
        if kind == "summary" and summary then
            M.write_spans(summary, self.theme)
            term.write("\n")
        elseif kind == "frame" and frame then
            for _, line in ipairs(frame.lines) do
                M.write_spans(line, self.theme)
                term.write("\n")
            end
        end
        term.show_cursor()
    end)
end

function Alternate:close()
    if self.shared then return end
    term.batch(function()
        if self.active then
            term.alternate_screen(false)
            self.active = false
        end
        term.show_cursor()
    end)
end

function M.new(screen)
    local theme = theme_mod.build()
    if M.capture then
        local capture = setmetatable({ theme = theme, frames = M.capture, commits = M.capture.commits or {} }, Capture)
        M.capture.commits = capture.commits
        return capture
    end
    if screen == "alternate" then return Alternate:new(theme) end
    return Inline:new(theme)
end

function M.summary(theme, message, value)
    local spans = {
        { text = "? ", style = "accent" },
        { text = message, style = "message" },
    }
    if value ~= nil and value ~= "" then
        spans[#spans + 1] = { text = " " .. theme.symbol("separator") .. " ", style = "muted" }
        spans[#spans + 1] = { text = tostring(value), style = "selected" }
    end
    return spans
end

function M.status(theme, kind, text)
    local symbol = kind == "success" and theme.symbol("tick")
        or kind == "danger" and theme.symbol("cross")
        or theme.symbol("bullet")
    return {
        { text = symbol .. " ", style = kind or "accent" },
        { text = tostring(text), style = kind or "message" },
    }
end

return M
