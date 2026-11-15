-- Common protocol for form fields.
--
-- Components keep their public blocking functions, but also expose a
-- `new_field(options)` constructor used by `prompt.form` and `prompt.wizard`.
-- A field renders one compact row when inactive and its full editor when the
-- form focuses it.
--
-- Fields provide:
--   draw(width, active, theme) -> lines, cursor
--   handle(event)              -> action, value?
--   value()                    -> current result value
--   set_value(value)           -> replace the current value
--   summary(theme)             -> spans for one compact row
--   close()                    -> release editors
--   error                      -> current validation message or nil

local render = require "prompt.render"

local M = {}

local Field = {}
Field.__index = Field

--- Build a field from component callbacks.
-- `spec.type` names the component, `spec.options` is the original option
-- table and `spec.message` is the row label.  `draw_active` receives the
-- field, width and theme; `draw_compact` receives the field and theme.
function M.new(spec)
    local field = setmetatable({
        type = spec.type,
        options = spec.options or {},
        message = spec.message or (spec.options and spec.options.message) or "",
        error = nil,
        active = false,
        _draw_active = spec.draw_active,
        _draw_compact = spec.draw_compact,
        _handle = spec.handle,
        _value = spec.value,
        _set_value = spec.set_value,
        _summary = spec.summary,
        _close = spec.close,
        _activate = spec.activate,
        _deactivate = spec.deactivate,
    }, Field)
    return field
end

function Field:draw(width, active, theme)
    if active then
        if not self.active then
            self.active = true
            if self._activate then self._activate(self) end
        end
        local result, cursor = self._draw_active(self, width, theme)
        if type(result) == "table" and result.lines then
            cursor = result.cursor
            result = result.lines
        end
        if self.error then
            local insert_at = #result + 1
            for index = #result, 1, -1 do
                if result[index].help then
                    insert_at = index
                    break
                end
            end
            table.insert(result, insert_at, M.error_line(self.error))
        end
        if width ~= nil and width > 0 then
            for index, line in ipairs(result) do
                result[index] = render.clip(line, math.floor(width), theme)
            end
        end
        return result, cursor
    end

    if self.active then
        self.active = false
        if self._deactivate then self._deactivate(self) end
    end

    local spans = self._draw_compact(self, theme)
    if self.error then
        spans[#spans + 1] = { text = "  " .. self.error, style = "error" }
    end
    if width ~= nil and width > 0 then
        spans = render.clip(spans, math.floor(width), theme)
    end
    return { spans }, nil
end

function Field:handle(event)
    return self._handle(self, event)
end

--- Draw the focused field as a complete frame for `input.run`.
function Field:frame(width, theme)
    local lines, cursor = self:draw(width, true, theme)
    return require("prompt.render").frame(lines, cursor)
end

function Field:value()
    return self._value(self)
end

function Field:set_value(value)
    self.error = nil
    if self._set_value then self._set_value(self, value) end
    return self
end

function Field:summary(theme)
    return self._summary(self, theme)
end

function Field:activate()
    if self.active then return self end
    self.active = true
    if self._activate then self._activate(self) end
    return self
end

function Field:deactivate()
    if not self.active then return self end
    self.active = false
    if self._deactivate then self._deactivate(self) end
    return self
end

function Field:close()
    if self._close then self._close(self) end
    return self
end

--- The conventional `? message` line.
function M.label(message)
    return render.line(render.span("? ", "accent"), render.span(message, "message"))
end

--- A compact `? message › value` row.
function M.compact(theme, message, value)
    return render.summary(theme, message, value)
end

function M.error_line(message)
    return render.line(render.span(message, "error"))
end

function M.help_line(text)
    local line = render.line(render.span(text, "muted"))
    line.help = true
    return line
end

--- Apply a field width, falling back to the terminal width.
function M.active_width(width)
    if width ~= nil then return math.max(1, math.floor(width)) end
    local term = require "term"
    local size = term.size()
    return math.max(1, (size and size.columns or 80) - 3)
end

return M
