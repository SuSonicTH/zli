-- Compact multi-field form built from the shared field protocol.
--
-- A form shows one row per field.  The focused field expands below its label;
-- the others collapse back to a summary row.  The body scrolls as a whole so
-- forms taller than the terminal stay usable.  `prompt.wizard` reuses the
-- internal page object to build multi-step forms.

local config = require "prompt.config"
local field_mod = require "prompt.field"
local input = require "prompt.input"
local render = require "prompt.render"
local scroll = require "prompt.scroll"
local theme_mod = require "prompt.theme"

local M = {}

local field_modules = {
    text = "text",
    multiline = "multiline",
    password = "password",
    confirm = "confirm",
    date = "date",
    time = "time",
    datetime = "datetime",
}

local helpers = {
    text = function(options) return require("prompt.text")(options) end,
    multiline = function(options) return require("prompt.multiline")(options) end,
    password = function(options) return require("prompt.password")(options) end,
    confirm = function(options) return require("prompt.confirm")(options) end,
    select = function(options) return require("prompt.select").select(options) end,
    multiselect = function(options) return require("prompt.select").multiselect(options) end,
    date = function(options) return require("prompt.date")(options) end,
    time = function(options) return require("prompt.time")(options) end,
    datetime = function(options) return require("prompt.datetime")(options) end,
}

local function type_name(spec, index)
    local name = spec.type or "text"
    if name == "select" or name == "multiselect" then return name end
    if field_modules[name] == nil then
        error("prompt.form: field " .. index .. " has unknown type '" .. tostring(name) .. "'", 4)
    end
    return name
end

local function is_empty(value)
    if value == nil then return true end
    if type(value) == "string" then return value == "" end
    if type(value) == "table" then return next(value) == nil end
    return false
end

local function table_copy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local result = {}
    seen[value] = result
    for key, item in pairs(value) do result[table_copy(key, seen)] = table_copy(item, seen) end
    return result
end

local function table_equal(left, right, seen)
    if left == right then return true end
    if type(left) ~= "table" or type(right) ~= "table" then return false end
    seen = seen or {}
    if seen[left] == right then return true end
    seen[left] = right
    for key, value in pairs(left) do
        if not table_equal(value, right[key], seen) then return false end
    end
    for key in pairs(right) do
        if left[key] == nil then return false end
    end
    return true
end

--- Check one field spec against its current value.
-- Returns a message when the value is invalid and nil otherwise.
local function check_field(spec, value)
    if spec.type == "multiselect" then
        local count = type(value) == "table" and #value or 0
        local minimum = spec.required and math.max(1, spec.min or 0) or (spec.min or 0)
        if count < minimum then
            return "Choose at least " .. tostring(minimum) .. "."
        end
        if spec.max and count > spec.max then
            return "Choose at most " .. tostring(spec.max) .. "."
        end
    elseif spec.required and is_empty(value) then
        return "An answer is required."
    end
    if spec.validate then
        local ok, message = spec.validate(value)
        if ok == false or (ok == nil and message ~= nil) then
            return tostring(message or "Invalid value.")
        end
    end
    return nil
end

local function is_ctrl_enter(event)
    if not event or event.type ~= "key" then return false end
    if event.code == "enter" and event.control then return true end
    if event.code == "char" and event.control then
        return event.char == "\r" or event.char == "\n"
    end
    return false
end

local function build_field(spec)
    local name = type_name(spec, 1)
    local options = {}
    for key, value in pairs(spec) do options[key] = value end
    options.message = spec.message or spec.name

    local field_options = {
        message = options.message,
        show_help = false,
    }
    if name == "select" or name == "multiselect" then
        field_options.multi = name == "multiselect"
        if name == "multiselect" and options.required == nil and options.min ~= nil then
            -- The component already understands min/max; nothing to add.
        end
        return require("prompt.select").new_field(options, field_options)
    end
    if name == "multiline" then
        -- Inside a form Enter inserts a newline and Alt+Enter advances.
        field_options.submit_on_enter = false
        field_options.alt_enter_newline = true
    end
    return require("prompt." .. field_modules[name]).new_field(options, field_options)
end

local Page = {}
Page.__index = Page

function Page:focus_index(index)
    if index == nil then return end
    if index < 1 then index = #self.entries end
    if index > #self.entries then index = 1 end
    self.focus = index
    self.footer = nil
    return index
end

function Page:focus_next() return self:focus_index(self.focus + 1) end
function Page:focus_previous() return self:focus_index(self.focus - 1) end

function Page:focus_type()
    local entry = self.entries[self.focus]
    return entry and entry.spec.type or "text"
end

--- True when the focused field consumes ordinary letter keys.
function Page:accepts_text()
    local name = self:focus_type()
    return name == "text" or name == "multiline" or name == "password"
        or name == "select" or name == "multiselect"
end

function Page:values()
    local values = {}
    for _, entry in ipairs(self.entries) do
        values[entry.spec.name] = entry.field:value()
    end
    return values
end

function Page:load(values)
    if type(values) ~= "table" then return self end
    for _, entry in ipairs(self.entries) do
        local value = values[entry.spec.name]
        if value ~= nil then entry.field:set_value(value) end
    end
    return self
end

--- Commit every field without validating or moving focus.
-- Returns false when at least one field could not commit.  Password fields are
-- skipped when `skip_password` is set so a baseline snapshot does not advance
-- their confirmation stage.
function Page:commit_fields(skip_password)
    local ok = true
    for _, entry in ipairs(self.entries) do
        if not (skip_password and entry.spec.type == "password") then
            if not entry.field:commit() then ok = false end
        end
    end
    return ok
end

function Page:validate()
    local first_invalid
    for index, entry in ipairs(self.entries) do
        local ok, message = entry.field:commit()
        local problem
        if not ok then
            problem = message or entry.field.error or "Invalid value."
        else
            problem = check_field(entry.spec, entry.field:value())
        end
        entry.field.error = problem
        if problem and first_invalid == nil then first_invalid = index end
    end
    if first_invalid then
        self.focus = first_invalid
        self.footer = nil
        return false
    end
    return true
end

function Page:submit()
    if not self:validate() then return "continue" end
    local values = self:values()
    if self.options.validate then
        local ok, message = self.options.validate(values)
        if ok == false or (ok == nil and message ~= nil) then
            self.footer = tostring(message or "Invalid values.")
            return "continue"
        end
    end
    self.footer = nil
    return "submit", values
end

function Page:summary_lines(theme)
    local lines = {}
    for _, entry in ipairs(self.entries) do
        lines[#lines + 1] = entry.field:summary(theme)
    end
    return lines
end

function Page:close()
    for _, entry in ipairs(self.entries) do entry.field:close() end
end

--- Render a scrollable body.
-- Returns the visible lines, the first/last body index and whether a top
-- overflow indicator was emitted.
function M._view(body, scroller, height, theme, focus_first, focus_last)
    scroller:set_rows(#body)
    local reserve = (#body > height and height >= 4) and 2 or 0
    scroller:set_height(math.max(1, height - reserve))

    if focus_first then
        scroller:follow(focus_first)
        if focus_last then
            local last_visible = scroller.top + scroller.height - 1
            if focus_last > last_visible then
                scroller.top = focus_last - scroller.height + 1
            end
        end
    end
    scroller:clamp()

    local first, last = scroller:visible()
    local lines = {}
    local top_used = false
    if reserve > 0 and scroller:has_above() then
        lines[#lines + 1] = render.line(
            render.span("  " .. theme.symbol("arrow_up") .. " more", "muted")
        )
        top_used = true
    end
    for index = first, last do lines[#lines + 1] = body[index] end
    if reserve > 0 and scroller:has_below() then
        lines[#lines + 1] = render.line(
            render.span("  " .. theme.symbol("arrow_down") .. " more", "muted")
        )
    end
    return lines, first, last, top_used
end

--- Validate and copy field specs.
-- Shared by the interactive and plain-text paths so both reject the same
-- malformed field tables.
function M._normalize_fields(fields)
    local specs = {}
    local seen = {}
    for index, spec in ipairs(fields) do
        if type(spec) ~= "table" then
            error("prompt.form: field " .. index .. " must be a table", 4)
        end
        if type(spec.name) ~= "string" or spec.name == "" then
            error("prompt.form: field " .. index .. " needs a name", 4)
        end
        if seen[spec.name] then
            error("prompt.form: duplicate field name '" .. spec.name .. "'", 4)
        end
        local name = type_name(spec, index)
        local normalized = {}
        for key, value in pairs(spec) do normalized[key] = value end
        normalized.type = name
        normalized.message = spec.message or spec.name
        specs[index] = normalized
        seen[spec.name] = true
    end
    return specs
end

--- Build a form page.
-- Internal, but shared with `prompt.wizard`.  `options.fields` uses the same
-- field specs as `prompt.form`.
function M.new_page(options)
    local page = setmetatable({
        options = options,
        title = options.title,
        entries = {},
        focus = 1,
        footer = nil,
        scroller = scroll.new { rows = 1, height = 1 },
        help = "Tab next  Shift+Tab previous  Enter next  Ctrl+Enter submit  Esc cancel",
    }, Page)

    for index, spec in ipairs(M._normalize_fields(options.fields)) do
        page.entries[index] = {
            spec = spec,
            field = build_field(spec),
        }
    end

    page:load(options.values or {})
    return page
end

function Page:draw(width, theme, view)
    view = view or {}
    theme = theme or theme_mod.build()
    local size = require("term").size() or { columns = 80, rows = 24 }
    local columns = width and math.max(1, math.floor(width)) or size.columns

    local body = {}
    local focus_start, focus_end, focus_cursor
    for index, entry in ipairs(self.entries) do
        local start = #body + 1
        local lines, cursor
        if index == self.focus then
            lines, cursor = entry.field:draw(columns, true, theme)
        else
            lines = entry.field:draw(columns, false, theme)
        end
        for _, line in ipairs(lines or {}) do body[#body + 1] = line end
        if index == self.focus then
            focus_start = start
            focus_end = #body
            focus_cursor = cursor
        end
    end

    local header = view.header and 1 or 0
    local title = self.title and 1 or 0
    local footer = (view.footer or self.footer) and 1 or 0
    local help = 1
    local available = math.max(1, size.rows - header - title - footer - help - 1)

    local lines = {}
    if view.header then
        if type(view.header) == "string" then
            lines[#lines + 1] = render.line(render.span(view.header, "muted"))
        elseif view.header.text then
            lines[#lines + 1] = view.header
        else
            lines[#lines + 1] = render.line(view.header)
        end
    end
    if self.title then
        lines[#lines + 1] = render.line(render.span(self.title, "title"))
    end

    local body_lines, first, _, top_used = M._view(
        body, self.scroller, available, theme, focus_start, focus_end
    )
    for _, line in ipairs(body_lines) do lines[#lines + 1] = line end

    local message = view.footer or self.footer
    if message then
        lines[#lines + 1] = field_mod.error_line(message)
    end
    local help_text = view.help
    if not help_text then
        help_text = self.help
        if self.options.submit and self.focus == #self.entries then
            help_text = "Tab next  Shift+Tab previous  Enter "
                .. self.options.submit .. "  Ctrl+Enter submit  Esc cancel"
        end
    end
    lines[#lines + 1] = field_mod.help_line(help_text)

    local cursor
    if focus_cursor and focus_start and first and focus_start >= first then
        local row = header + title + (top_used and 1 or 0) + (focus_start - first) + 1
        cursor = {
            row = row + (focus_cursor.row or 1) - 1,
            column = focus_cursor.column,
        }
    end
    return render.frame(lines, cursor)
end

function Page:handle(event)
    if not event or event.type == "resize" then return "continue" end

    if is_ctrl_enter(event) then
        return self:submit()
    end

    local entry = self.entries[self.focus]
    if event.type == "key" and event.code == "tab" then
        local ok, message = entry.field:commit()
        if not ok then
            entry.field.error = message
            return "continue"
        end
        if event.shift then self:focus_previous() else self:focus_next() end
        return "continue"
    end
    if entry.spec.type == "multiline" and event.type == "key" and event.code == "enter" then
        -- Inside a form Enter inserts a newline and Alt+Enter advances.  The
        -- editor already treats Alt+Enter as the newline key when
        -- `alt_enter_newline` is set, so swap the two roles here.
        if event.alt then
            if self.focus < #self.entries then
                self:focus_next()
                return "continue"
            end
            return self:submit()
        end
        local synthetic = {}
        for key, value in pairs(event) do synthetic[key] = value end
        synthetic.alt = true
        synthetic.control = false
        entry.field:handle(synthetic)
        return "continue"
    end

    local action, value = entry.field:handle(event)
    if action == "submit" then
        if self.focus < #self.entries then
            self:focus_next()
            return "continue"
        end
        return self:submit()
    elseif action == "cancel" then
        return "cancel"
    elseif action == "eof" then
        return "eof"
    end
    self.footer = nil
    return "continue"
end

local function validate_options(options)
    if type(options) ~= "table" then
        error("prompt.form: expecting an options table", 3)
    end
    if type(options.fields) ~= "table" or #options.fields == 0 then
        error("prompt.form: fields must be a non-empty table", 3)
    end
    if options.title ~= nil and type(options.title) ~= "string" then
        error("prompt.form: title must be a string", 3)
    end
    if options.values ~= nil and type(options.values) ~= "table" then
        error("prompt.form: values must be a table", 3)
    end
    if options.validate ~= nil and type(options.validate) ~= "function" then
        error("prompt.form: validate must be a function", 3)
    end
    if options.submit ~= nil and type(options.submit) ~= "string" then
        error("prompt.form: submit must be a string", 3)
    end
end

--- Prompt every field in sequence without a terminal.
-- Shared with `prompt.wizard`; returns the collected values or nil, message.
function M._prompt_fields(fields, values)
    local result = {}
    for _, spec in ipairs(M._normalize_fields(fields)) do
        local options = {}
        for key, value in pairs(spec) do options[key] = value end
        options.message = spec.message or spec.name
        if values and values[spec.name] ~= nil then
            options.default = values[spec.name]
        end
        local value, message = helpers[spec.type](options)
        if value == nil then return nil, message end
        result[spec.name] = value
        local problem = check_field(spec, value)
        if problem then
            io.write(problem .. "\n")
            return nil, problem
        end
    end
    return result
end

function M.__call(_, options)
    validate_options(options)
    if not config.is_interactive() then
        if options.title then io.write(options.title .. "\n") end
        local values, message = M._prompt_fields(options.fields, options.values)
        if values == nil then return nil, message end
        if options.validate then
            local ok, problem = options.validate(values)
            if ok == false or (ok == nil and problem ~= nil) then
                problem = tostring(problem or "Invalid values.")
                io.write(problem .. "\n")
                return nil, problem
            end
        end
        return values
    end

    local page = M.new_page(options)
    local theme = theme_mod.build()
    local function draw() return page:draw(nil, theme) end
    local packed = table.pack(xpcall(function()
        return input.run {
            screen = options.screen,
            commit = options.commit,
            frame = draw,
            on_event = function(event) return page:handle(event) end,
            summary = function()
                return render.status(theme, "success", options.title or "form submitted")
            end,
            final_frame = draw,
        }
    end, debug.traceback))
    page:close()
    if not packed[1] then error(packed[2], 0) end
    return table.unpack(packed, 2, packed.n)
end

return setmetatable(M, { __call = function(_, options) return M.__call(M, options) end })
