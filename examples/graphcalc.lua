-- An example graphical calculator served through the webui layer.
--
-- Run it with `zli examples/graphcalc.lua`; see graphcalc.md for the options.
--
-- Expressions are parsed and compiled into Lua closures, so nothing the user
-- types is ever evaluated as code.  The plot is rendered server side as a self
-- contained SVG (presentation attributes, no external CSS), which makes the
-- same markup usable both inside the page and from the download link.

local ui = require "webui"

local MAX_CURVES = 8
local MAX_EXPRESSION = 300
local SAMPLES = 900
local PLOT_WIDTH = 760
local PLOT_HEIGHT = 460
local MARGIN = { left = 58, right = 18, top = 18, bottom = 38 }

local palette = {
    "#2f6feb", "#e0562f", "#1f9d55", "#8b5cf6",
    "#d4a017", "#0ea5e9", "#d9468b", "#6b7280",
}

-- ---------------------------------------------------------------------------
-- expression engine
-- ---------------------------------------------------------------------------

local constants = {
    pi = math.pi,
    e = math.exp(1),
    tau = math.pi * 2,
    phi = (1 + math.sqrt(5)) / 2,
    inf = math.huge,
    nan = 0 / 0,
}

local functions = {}

local function define(name, minimum, maximum, fn)
    functions[name] = { min = minimum, max = maximum or minimum, fn = fn }
end

define("sin", 1, 1, math.sin)
define("cos", 1, 1, math.cos)
define("tan", 1, 1, math.tan)
define("asin", 1, 1, math.asin)
define("acos", 1, 1, math.acos)
define("atan", 1, 2, math.atan)
define("sinh", 1, 1, math.sinh)
define("cosh", 1, 1, math.cosh)
define("tanh", 1, 1, math.tanh)
define("asinh", 1, 1, math.asinh)
define("acosh", 1, 1, math.acosh)
define("atanh", 1, 1, math.atanh)
define("sqrt", 1, 1, math.sqrt)
define("cbrt", 1, 1, function(x) return x < 0 and -((-x) ^ (1 / 3)) or x ^ (1 / 3) end)
define("exp", 1, 1, math.exp)
define("ln", 1, 1, math.log)
define("log", 1, 2, math.log)
define("log2", 1, 1, function(x) return math.log(x, 2) end)
define("log10", 1, 1, function(x) return math.log(x, 10) end)
define("abs", 1, 1, math.abs)
define("sign", 1, 1, function(x) return x > 0 and 1 or (x < 0 and -1 or 0) end)
define("floor", 1, 1, math.floor)
define("ceil", 1, 1, math.ceil)
define("round", 1, 1, function(x) return math.floor(x + 0.5) end)
define("trunc", 1, 1, function(x) return x < 0 and math.ceil(x) or math.floor(x) end)
define("fract", 1, 1, function(x) return x - math.floor(x) end)
define("pow", 2, 2, function(a, b) return a ^ b end)
define("hypot", 2, 2, function(a, b) return math.sqrt(a * a + b * b) end)
define("atan2", 2, 2, function(y, x) return math.atan(y, x) end)
define("mod", 2, 2, math.fmod)
define("min", 2, math.huge, math.min)
define("max", 2, math.huge, math.max)
define("clamp", 3, 3, function(x, low, high) return math.min(math.max(x, low), high) end)
define("deg", 1, 1, math.deg)
define("rad", 1, 1, math.rad)

local function syntax_error(position, message)
    error({ position = position, message = message }, 0)
end

local function tokenize(text)
    local tokens = {}
    local length = #text
    local index = 1
    while index <= length do
        local char = text:sub(index, index)
        local digit = text:sub(index, index + 1)
        if char:match("%s") then
            index = index + 1
        elseif char:match("%d") or (char == "." and digit:sub(2, 2):match("%d")) then
            local start = index
            local number = text:match("^%d*%.?%d+", index)
            index = index + #number
            local exponent = text:match("^[eE][+-]?%d+", index)
            if exponent then
                number = number .. exponent
                index = index + #exponent
            end
            tokens[#tokens + 1] = { type = "number", value = tonumber(number), position = start }
        elseif char:match("[%a_]") then
            local start = index
            local name = text:match("^[%a_][%w_]*", index)
            index = index + #name
            tokens[#tokens + 1] = { type = "name", value = name, position = start }
        elseif char == "(" or char == ")" or char == "," then
            tokens[#tokens + 1] = { type = char, position = index }
            index = index + 1
        elseif char == "*" and text:sub(index + 1, index + 1) == "*" then
            tokens[#tokens + 1] = { type = "^", position = index }
            index = index + 2
        elseif char:match("[%+%-%*/%^%%]") then
            tokens[#tokens + 1] = { type = char, position = index }
            index = index + 1
        else
            return nil, "unexpected character '" .. char .. "' at " .. tostring(index)
        end
    end
    tokens[#tokens + 1] = { type = "eof", position = length + 1 }
    return tokens
end

local function token_label(token)
    if token.type == "eof" then
        return "end of expression"
    elseif token.type == "number" then
        return tostring(token.value)
    elseif token.type == "name" then
        return "'" .. token.value .. "'"
    end
    return "'" .. token.type .. "'"
end

local Parser = {}
Parser.__index = Parser

function Parser:peek()
    return self.tokens[self.index]
end

function Parser:advance()
    local token = self.tokens[self.index]
    self.index = self.index + 1
    return token
end

local parse_expression, parse_term, parse_unary, parse_power, parse_primary

parse_expression = function(self)
    local node = parse_term(self)
    while true do
        local token = self:peek()
        if token.type == "+" or token.type == "-" then
            self:advance()
            local left = node
            local right = parse_term(self)
            if token.type == "+" then
                node = function(x) return left(x) + right(x) end
            else
                node = function(x) return left(x) - right(x) end
            end
        else
            return node
        end
    end
end

parse_term = function(self)
    local node = parse_unary(self)
    while true do
        local token = self:peek()
        -- a number, a name or "(" after a value is an implicit product: 2x, 3sin(x)
        local implicit = token.type == "number" or token.type == "name" or token.type == "("
        if token.type == "*" or token.type == "/" or token.type == "%" or implicit then
            local operator = token.type
            if not implicit then
                self:advance()
            end
            local left = node
            local right = parse_unary(self)
            if operator == "*" or implicit then
                node = function(x) return left(x) * right(x) end
            elseif operator == "/" then
                node = function(x) return left(x) / right(x) end
            else
                node = function(x) return left(x) % right(x) end
            end
        else
            return node
        end
    end
end

parse_unary = function(self)
    local token = self:peek()
    if token.type == "-" then
        self:advance()
        local operand = parse_unary(self)
        return function(x) return -operand(x) end
    elseif token.type == "+" then
        self:advance()
        return parse_unary(self)
    end
    return parse_power(self)
end

parse_power = function(self)
    local base = parse_primary(self)
    if self:peek().type == "^" then
        self:advance()
        -- right associative and binding tighter than unary minus: -2^2 == -4
        local exponent = parse_unary(self)
        return function(x) return base(x) ^ exponent(x) end
    end
    return base
end

parse_primary = function(self)
    local token = self:advance()
    if token.type == "number" then
        local value = token.value
        return function() return value end
    elseif token.type == "name" then
        local name = token.value
        if name == "x" or name == "t" then
            return function(x) return x end
        end
        local constant = constants[name]
        if constant ~= nil then
            return function() return constant end
        end
        local spec = functions[name]
        if spec == nil then
            syntax_error(token.position, "unknown name '" .. name .. "'")
        end
        if self:peek().type ~= "(" then
            syntax_error(token.position, "function '" .. name .. "' needs parentheses")
        end
        self:advance()
        local arguments = {}
        if self:peek().type ~= ")" then
            while true do
                arguments[#arguments + 1] = parse_expression(self)
                if self:peek().type == "," then
                    self:advance()
                else
                    break
                end
            end
        end
        local close = self:peek()
        if close.type ~= ")" then
            syntax_error(close.position, "expected ')' after the arguments of '" .. name .. "'")
        end
        self:advance()

        local count = #arguments
        if count < spec.min or count > spec.max then
            local expected
            if spec.min == spec.max then
                expected = tostring(spec.min)
            elseif spec.max == math.huge then
                expected = "at least " .. tostring(spec.min)
            else
                expected = tostring(spec.min) .. " to " .. tostring(spec.max)
            end
            syntax_error(token.position,
                "'" .. name .. "' takes " .. expected .. " argument(s), got " .. tostring(count))
        end

        local apply = spec.fn
        return function(x)
            local values = {}
            for index = 1, count do
                values[index] = arguments[index](x)
            end
            return apply(table.unpack(values, 1, count))
        end
    elseif token.type == "(" then
        local node = parse_expression(self)
        local close = self:peek()
        if close.type ~= ")" then
            syntax_error(close.position, "expected ')'")
        end
        self:advance()
        return node
    end
    syntax_error(token.position, "unexpected " .. token_label(token))
end

--- Compile an expression into `f(x)`.
-- returns: function, or nil plus a message with the offending position
local function compile(text)
    if type(text) ~= "string" then
        return nil, "expression has to be a string"
    end
    if text == "" then
        return nil, "empty expression"
    end
    if #text > MAX_EXPRESSION then
        return nil, "expression is longer than " .. tostring(MAX_EXPRESSION) .. " characters"
    end

    local tokens, err = tokenize(text)
    if tokens == nil then
        return nil, err
    end

    local parser = setmetatable({ tokens = tokens, index = 1 }, Parser)
    local ok, result = pcall(parse_expression, parser)
    if not ok then
        if type(result) == "table" and result.message then
            return nil, "at " .. tostring(result.position or 0) .. ": " .. result.message
        end
        return nil, tostring(result)
    end

    local rest = parser:peek()
    if rest.type ~= "eof" then
        return nil, "at " .. tostring(rest.position) .. ": unexpected " .. token_label(rest)
    end
    return result
end

-- ---------------------------------------------------------------------------
-- numbers and plotting
-- ---------------------------------------------------------------------------

local function trim(text)
    return (tostring(text):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function escape(text)
    return (tostring(text):gsub("[&<>\"']", {
        ["&"] = "&amp;",
        ["<"] = "&lt;",
        [">"] = "&gt;",
        ['"'] = "&quot;",
        ["'"] = "&#39;",
    }))
end

local function fmt_number(value)
    local integer = math.tointeger(value)
    if integer then
        return tostring(integer)
    end
    return string.format("%.8g", value)
end

--- True when `low < high` and the span is usable for scaling.
local function valid_span(low, high)
    if low == nil or high == nil then
        return false
    end
    local span = high - low
    return low < high and span > 0 and span < math.huge
end

local function fmt_tick(value)
    if value == 0 then
        return "0"
    end
    local magnitude = math.abs(value)
    if magnitude >= 1e5 or magnitude < 1e-3 then
        return string.format("%.3g", value)
    end
    return (string.format("%.10f", value):gsub("0+$", ""):gsub("%.$", ""))
end

local function nice_step(span, target)
    local raw = span / math.max(target, 1)
    local magnitude = 10 ^ math.floor(math.log(raw, 10))
    local normalized = raw / magnitude
    local factor
    if normalized <= 1 then
        factor = 1
    elseif normalized <= 2 then
        factor = 2
    elseif normalized <= 5 then
        factor = 5
    else
        factor = 10
    end
    return factor * magnitude
end

local function ticks(minimum, maximum, target)
    local span = maximum - minimum
    if not (span > 0) or span ~= span or span == math.huge then
        return {}
    end
    local step = nice_step(span, target)
    local first = math.ceil(minimum / step) * step
    local count = math.floor((maximum - first) / step + 1e-9)
    local out = {}
    for index = 0, math.min(count, 100) do
        local value = first + index * step
        if math.abs(value) < step * 1e-9 then
            value = 0
        end
        out[#out + 1] = value
    end
    return out
end

--- Pick a y window that keeps asymptotes from flattening the visible curve.
local function auto_domain(values)
    if #values == 0 then
        return -5, 5
    end
    table.sort(values)
    local minimum, maximum = values[1], values[#values]
    local low = values[math.max(1, math.floor(#values * 0.02) + 1)]
    local high = values[math.max(1, math.floor(#values * 0.98) + 1)]
    if high > low and maximum - minimum > 30 * (high - low) then
        minimum, maximum = low, high
    end
    local span = maximum - minimum
    if span < 1e-9 then
        local pad = math.max(1, math.abs(minimum) * 0.25)
        minimum, maximum = minimum - pad, maximum + pad
    else
        local pad = span * 0.08
        minimum, maximum = minimum - pad, maximum + pad
    end
    if not valid_span(minimum, maximum) then
        return -5, 5
    end
    return minimum, maximum
end

local function render_legend(curves, state, ymin, ymax)
    local out = { '<div class="gc-legend">' }
    if #curves == 0 then
        out[#out + 1] = '<span class="gc-window">enter a function to plot it</span>'
    else
        for _, curve in ipairs(curves) do
            out[#out + 1] = string.format(
                '<span class="gc-chip"><span class="gc-swatch" style="background:%s"></span>%s</span>',
                curve.color, escape(curve.expr))
        end
    end
    out[#out + 1] = string.format(
        '<span class="gc-window">x: %s … %s · y: %s … %s</span>',
        escape(fmt_number(state.xmin)), escape(fmt_number(state.xmax)),
        escape(fmt_number(ymin)), escape(fmt_number(ymax)))
    out[#out + 1] = "</div>"
    return table.concat(out)
end

--- SVG path data for one curve, split at gaps and asymptotes.
local function path_data(values, state, ymin, ymax, project_x, project_y)
    local span = ymax - ymin
    local low_limit = ymin - span
    local high_limit = ymax + span
    local width = state.xmax - state.xmin
    local parts = {}
    local pen = false
    local previous = nil

    for index = 0, SAMPLES do
        local value = values[index]
        if value == nil then
            pen = false
            previous = nil
        else
            -- the curve left the frame on one side and came back on the other,
            -- which is what an asymptote looks like in the samples
            if previous ~= nil
                and ((previous < ymin and value > ymax) or (previous > ymax and value < ymin)) then
                pen = false
            end
            local clamped = value
            if clamped < low_limit then
                clamped = low_limit
            elseif clamped > high_limit then
                clamped = high_limit
            end
            local x = state.xmin + width * index / SAMPLES
            parts[#parts + 1] = string.format("%s%.2f %.2f", pen and "L" or "M",
                project_x(x), project_y(clamped))
            pen = true
            previous = value
        end
    end

    return table.concat(parts)
end

local function render_svg(state, series, ymin, ymax)
    local width, height = PLOT_WIDTH, PLOT_HEIGHT
    local left, right, top, bottom = MARGIN.left, MARGIN.right, MARGIN.top, MARGIN.bottom
    local plot_width = width - left - right
    local plot_height = height - top - bottom
    local xmin, xmax = state.xmin, state.xmax
    local x_span = xmax - xmin
    local y_span = ymax - ymin

    local function project_x(x)
        return left + (x - xmin) / x_span * plot_width
    end

    local function project_y(y)
        return top + (ymax - y) / y_span * plot_height
    end

    local out = {}
    out[#out + 1] = string.format(
        '<svg class="gc-svg" viewBox="0 0 %d %d" width="100%%" role="img" aria-label="graph">',
        width, height)
    out[#out + 1] = string.format(
        '<defs><clipPath id="gc-clip"><rect x="%d" y="%d" width="%d" height="%d"/></clipPath></defs>',
        left, top, plot_width, plot_height)
    out[#out + 1] = string.format(
        '<rect x="%d" y="%d" width="%d" height="%d" fill="none" stroke="rgba(128,128,128,0.45)"/>',
        left, top, plot_width, plot_height)

    local x_ticks = ticks(xmin, xmax, 10)
    local y_ticks = ticks(ymin, ymax, 6)

    out[#out + 1] = '<g stroke="rgba(128,128,128,0.22)" stroke-width="1">'
    for _, value in ipairs(x_ticks) do
        local x = project_x(value)
        out[#out + 1] = string.format('<line x1="%.2f" y1="%d" x2="%.2f" y2="%d"/>',
            x, top, x, top + plot_height)
    end
    for _, value in ipairs(y_ticks) do
        local y = project_y(value)
        out[#out + 1] = string.format('<line x1="%d" y1="%.2f" x2="%d" y2="%.2f"/>',
            left, y, left + plot_width, y)
    end
    out[#out + 1] = "</g>"

    out[#out + 1] = '<g stroke="rgba(128,128,128,0.8)" stroke-width="1.3">'
    if ymin <= 0 and ymax >= 0 then
        local y = project_y(0)
        out[#out + 1] = string.format('<line x1="%d" y1="%.2f" x2="%d" y2="%.2f"/>',
            left, y, left + plot_width, y)
    end
    if xmin <= 0 and xmax >= 0 then
        local x = project_x(0)
        out[#out + 1] = string.format('<line x1="%.2f" y1="%d" x2="%.2f" y2="%d"/>',
            x, top, x, top + plot_height)
    end
    out[#out + 1] = "</g>"

    out[#out + 1] = '<g fill="#8a919c" font-family="system-ui, sans-serif" font-size="11">'
    for _, value in ipairs(x_ticks) do
        local x = project_x(value)
        out[#out + 1] = string.format('<text x="%.2f" y="%d" text-anchor="middle">%s</text>',
            x, top + plot_height + 18, escape(fmt_tick(value)))
    end
    for _, value in ipairs(y_ticks) do
        local y = project_y(value)
        out[#out + 1] = string.format(
            '<text x="%d" y="%.2f" text-anchor="end" dominant-baseline="middle">%s</text>',
            left - 8, y, escape(fmt_tick(value)))
    end
    out[#out + 1] = "</g>"

    out[#out + 1] = '<g clip-path="url(#gc-clip)" fill="none" stroke-width="2" '
        .. 'stroke-linejoin="round" stroke-linecap="round">'
    for _, item in ipairs(series) do
        local data = path_data(item.values, state, ymin, ymax, project_x, project_y)
        if data ~= "" then
            out[#out + 1] = string.format('<path class="gc-curve" d="%s" stroke="%s"/>',
                data, item.curve.color)
        end
    end
    out[#out + 1] = "</g></svg>"

    return table.concat(out)
end

--- Recompile every curve that changed.
local function compile_curves(state)
    for _, curve in ipairs(state.curves) do
        local text = trim(curve.expr or "")
        if curve.compiled_text ~= text then
            curve.compiled_text = text
            curve.fn, curve.error = nil, nil
            if text ~= "" then
                curve.fn, curve.error = compile(text)
            end
        end
    end
end

--- Sample the visible curves and render the plot plus the legend markup.
local function build_plot(state)
    local active = {}
    for _, curve in ipairs(state.curves) do
        if curve.visible and curve.fn then
            active[#active + 1] = curve
        end
    end

    local series = {}
    local values = {}
    local x_span = state.xmax - state.xmin
    for _, curve in ipairs(active) do
        local samples = {}
        for index = 0, SAMPLES do
            local x = state.xmin + x_span * index / SAMPLES
            local ok, y = pcall(curve.fn, x)
            if ok and type(y) == "number" and y == y
                and y ~= math.huge and y ~= -math.huge then
                samples[index] = y
                values[#values + 1] = y
            end
        end
        series[#series + 1] = { curve = curve, values = samples }
    end

    local ymin, ymax = state.ymin, state.ymax
    if state.auto_y then
        ymin, ymax = auto_domain(values)
    end

    return render_svg(state, series, ymin, ymax), render_legend(active, state, ymin, ymax)
end

-- ---------------------------------------------------------------------------
-- page
-- ---------------------------------------------------------------------------

local CSS = [==[
.gc-header { align-items: baseline; justify-content: space-between; margin-bottom: 12px; }
.gc-tag { font-size: .78rem; letter-spacing: .08em; text-transform: uppercase; }
.gc-layout { align-items: flex-start; gap: 16px; }
.gc-controls { width: 320px; flex: 0 0 auto; }
.gc-stack { display: flex; flex-direction: column; gap: 10px; }
.gc-controls .webui-field { flex: 1 1 0; min-width: 0; }
.gc-controls .webui-input { width: 100%; box-sizing: border-box; min-width: 0; }
.gc-controls .webui-layout-horizontal { gap: 6px; align-items: flex-end; }
.gc-plot { flex: 1 1 420px; min-width: 0; }
.gc-plot svg { display: block; height: auto; max-width: 100%; }
.gc-curves { gap: 8px; }
.gc-row { align-items: flex-end; gap: 6px; }
.gc-row .webui-field { flex: 1 1 auto; min-width: 0; }
.gc-row .webui-input { width: 100%; box-sizing: border-box; min-width: 0; }
.gc-icon { background: transparent; color: var(--webui-muted); border: 1px solid var(--webui-border); padding: 4px 9px; line-height: 1; }
.gc-icon:hover { color: var(--webui-danger); border-color: var(--webui-danger); filter: none; }
.gc-add { background: transparent; color: var(--webui-accent); border: 1px dashed var(--webui-border); }
.gc-add:hover { border-color: var(--webui-accent); filter: none; }
.gc-step { background: var(--webui-surface); color: var(--webui-fg); border: 1px solid var(--webui-border); padding: 4px 10px; }
.gc-step:hover { border-color: var(--webui-accent); filter: none; }
.gc-hint { color: var(--webui-muted); font-size: .8rem; line-height: 1.45; white-space: pre-line; }
.gc-legend { display: flex; flex-wrap: wrap; align-items: center; gap: 4px 14px; margin-top: 10px; font-size: .85rem; }
.gc-chip { display: inline-flex; align-items: center; gap: 6px; }
.gc-swatch { width: 10px; height: 10px; border-radius: 3px; display: inline-block; }
.gc-window { color: var(--webui-muted); margin-left: auto; }
@media (max-width: 720px) {
    .gc-controls { width: 100%; }
}
@media (max-width: 640px) {
    .gc-header { flex-direction: column; align-items: flex-start; gap: 2px; }
    .gc-layout { align-items: stretch; }
    .gc-row,
    .gc-controls .webui-layout-horizontal { flex-direction: row; align-items: flex-end; }
}
]==]

local function default_state()
    return {
        curves = {},
        next_id = 1,
        color_index = 1,
        xmin = -10,
        xmax = 10,
        auto_y = true,
        ymin = -5,
        ymax = 5,
    }
end

local function add_curve(state, expr)
    local curve = {
        id = state.next_id,
        expr = expr or "",
        color = palette[(state.color_index - 1) % #palette + 1],
        visible = true,
    }
    state.next_id = state.next_id + 1
    state.color_index = state.color_index + 1
    state.curves[#state.curves + 1] = curve
    return curve
end

local function create_page(state)
    local page = ui.page { title = "Graph Calculator", css = CSS }
    ui.activate(page)

    local plot = ui.html { name = "plot" }
    local plot_panel = ui.panel { class = "gc-plot" }
    plot_panel:add(plot)

    local curves_box = ui.verticalLayout { class = "gc-curves" }

    -- forward declarations: the handlers below run after the tree is built
    local redraw, add_row, add_curve_row, apply_domain, sync_domain
    local xmin_field, xmax_field, ymin_field, ymax_field, auto_y

    local function read_number(field)
        local text = trim(field:value() or "")
        if text == "" then
            return nil
        end
        local value = tonumber(text)
        if value == nil or value ~= value or value == math.huge or value == -math.huge then
            return nil
        end
        return value
    end

    xmin_field = ui.textField {
        name = "xmin",
        label = "x min",
        value = fmt_number(state.xmin),
        onChange = function() apply_domain() end,
        onInput = function() apply_domain() end,
    }
    xmax_field = ui.textField {
        name = "xmax",
        label = "x max",
        value = fmt_number(state.xmax),
        onChange = function() apply_domain() end,
        onInput = function() apply_domain() end,
    }
    ymin_field = ui.textField {
        name = "ymin",
        label = "y min",
        value = fmt_number(state.ymin),
        onChange = function() apply_domain() end,
        onInput = function() apply_domain() end,
    }
    ymax_field = ui.textField {
        name = "ymax",
        label = "y max",
        value = fmt_number(state.ymax),
        onChange = function() apply_domain() end,
        onInput = function() apply_domain() end,
    }
    auto_y = ui.checkbox {
        name = "auto_y",
        text = "scale y automatically",
        checked = state.auto_y,
        onChange = function(node)
            state.auto_y = node:value() and true or false
            redraw()
        end,
    }

    apply_domain = function()
        redraw()
    end

    -- Fields own the values: every event submits all named inputs, so the
    -- fields are the freshest copy of what the user typed.
    sync_domain = function()
        local xmin, xmax = read_number(xmin_field), read_number(xmax_field)
        if valid_span(xmin, xmax) then
            state.xmin, state.xmax = xmin, xmax
            xmin_field:setError(nil)
            xmax_field:setError(nil)
        else
            local message = "enter two numbers with min < max"
            xmin_field:setError(message)
            xmax_field:setError(message)
        end

        if state.auto_y then
            ymin_field:setError(nil)
            ymax_field:setError(nil)
        else
            local ymin, ymax = read_number(ymin_field), read_number(ymax_field)
            if valid_span(ymin, ymax) then
                state.ymin, state.ymax = ymin, ymax
                ymin_field:setError(nil)
                ymax_field:setError(nil)
            else
                local message = "enter two numbers with min < max"
                ymin_field:setError(message)
                ymax_field:setError(message)
            end
        end
    end

    local function set_window(xmin, xmax)
        state.xmin, state.xmax = xmin, xmax
        xmin_field:setValue(fmt_number(xmin))
        xmax_field:setValue(fmt_number(xmax))
        xmin_field:setError(nil)
        xmax_field:setError(nil)
        redraw()
    end

    local function zoom(factor)
        sync_domain()
        local middle = (state.xmin + state.xmax) / 2
        local half = (state.xmax - state.xmin) / 2 * factor
        set_window(middle - half, middle + half)
    end

    local function reset_view()
        state.auto_y = true
        auto_y:setValue(true)
        set_window(-10, 10)
    end

    add_row = function(curve)
        local row = ui.horizontalLayout { class = "gc-row" }

        -- htmx reports debounced typing through the change handler in this
        -- build, so both events run the same update.
        local function expression_changed(node)
            curve.expr = trim(node:value() or "")
            redraw()
        end

        local field = ui.textField {
            name = "expr_" .. curve.id,
            value = curve.expr,
            placeholder = "e.g. sin(x)",
            onInput = expression_changed,
            onChange = expression_changed,
        }
        curve.field = field

        local visible = ui.checkbox {
            name = "show_" .. curve.id,
            text = "",
            checked = curve.visible,
            aria = { label = "show this function" },
            onChange = function(node)
                curve.visible = node:value() and true or false
                redraw()
            end,
        }

        local remove = ui.button {
            text = "×",
            class = "gc-icon",
            aria = { label = "remove this function" },
            onClick = function()
                for index, candidate in ipairs(state.curves) do
                    if candidate == curve then
                        table.remove(state.curves, index)
                        break
                    end
                end
                if row.parent then
                    row.parent:remove(row)
                end
                redraw()
            end,
        }

        row:add(visible, field, remove)
        curves_box:add(row)
        curve.row = row
    end

    add_curve_row = function(expr)
        if #state.curves >= MAX_CURVES then
            ui.notify("at most " .. tostring(MAX_CURVES) .. " functions", { kind = "warn" })
            return
        end
        add_row(add_curve(state, expr))
        redraw()
    end

    for _, curve in ipairs(state.curves) do
        add_row(curve)
    end

    redraw = function()
        ymin_field.props.disabled = state.auto_y
        ymax_field.props.disabled = state.auto_y

        sync_domain()
        for index, curve in ipairs(state.curves) do
            curve.expr = trim(curve.field:value() or "")
            curve.field.props.label = "f" .. index .. "(x)"
        end
        compile_curves(state)
        for _, curve in ipairs(state.curves) do
            curve.field:setError(curve.error)
        end

        local svg, legend = build_plot(state)
        plot.props.text = svg .. legend
    end

    local controls = ui.verticalLayout { class = "gc-stack" }
    controls:add(ui.label { text = "Functions", muted = true })
    controls:add(curves_box)
    controls:add(ui.button {
        text = "+ add function",
        class = "gc-add",
        onClick = function() add_curve_row("") end,
    })
    controls:add(ui.divider())
    controls:add(ui.label { text = "Window", muted = true })
    controls:add(ui.horizontalLayout { align = "horizontal", xmin_field, xmax_field })
    controls:add(auto_y)
    controls:add(ui.horizontalLayout { align = "horizontal", ymin_field, ymax_field })
    controls:add(ui.horizontalLayout {
        align = "horizontal",
        ui.button {
            text = "−", class = "gc-step", aria = { label = "zoom out" },
            onClick = function() zoom(1.6) end,
        },
        ui.button {
            text = "+", class = "gc-step", aria = { label = "zoom in" },
            onClick = function() zoom(1 / 1.6) end,
        },
        ui.button {
            text = "reset view", class = "gc-step",
            onClick = function() reset_view() end,
        },
    })
    controls:add(ui.divider())
    controls:add(ui.link { text = "download SVG", href = "/plot.svg" })
    controls:add(ui.label {
        class = "gc-hint",
        text = "sin cos tan sqrt abs exp ln log log10\n"
            .. "constants pi, tau, e; implicit products: 2x, 3sin(x)\n"
            .. "^ and ** are powers: -2^2 = -4",
    })

    page:add(ui.horizontalLayout {
        class = "gc-header",
        align = "horizontal",
        ui.heading { text = "Graph Calculator", level = 1 },
        ui.label { text = "zli webui", muted = true, class = "gc-tag" },
    })
    page:add(ui.horizontalLayout {
        class = "gc-layout",
        align = "horizontal",
        ui.panel { class = "gc-controls", controls },
        plot_panel,
    })

    redraw()
    return page
end

-- ---------------------------------------------------------------------------
-- command line
-- ---------------------------------------------------------------------------

local function usage()
    print([[
Usage: zli graphcalc.lua [options]

A graphical calculator: plot several f(x) curves, zoom the window and download
the plot as SVG.  The page is served by the webui component model.

Options:
  --port <port>        listen on this port (0 picks a free port, default 8080)
  --address <addr>     bind address (default 127.0.0.1)
  --expr <f(x)>        start with this expression (repeatable, default sin(x))
  --xmin <n>           initial left edge of the window (default -10)
  --xmax <n>           initial right edge of the window (default 10)
  --no-open            do not open the system browser
  --eval <f(x)>        print f(x) at --at and exit
  --at <n>             x value for --eval (default 0)
  --svg <file>         write the plot as a standalone SVG and exit
  --token <token>      fixed session token (tests and automation)
  --stop-path <path>   POST path that stops the server (tests and automation)
  -h, --help           show this help]])
end

local function fail(message, code)
    io.stderr:write("graphcalc: ", message, "\n")
    os.exit(code or 2)
end

local function parse_number_option(name, value)
    local number = tonumber(value or "")
    if number == nil or number ~= number or number == math.huge or number == -math.huge then
        fail(name .. " requires a number")
    end
    return number
end

local function parse_args(argv)
    local options = {
        port = 8080,
        address = "127.0.0.1",
        open_browser = true,
        expressions = {},
        at = 0,
    }

    local index = 1
    while index <= #argv do
        local value = argv[index]
        if value == "-h" or value == "--help" then
            usage()
            os.exit(0)
        elseif value == "--port" then
            index = index + 1
            local raw = argv[index]
            if raw == nil or not raw:match("^%d+$") or tonumber(raw) > 65535 then
                fail("--port requires an integer between 0 and 65535")
            end
            options.port = tonumber(raw)
            index = index + 1
        elseif value == "--address" then
            index = index + 1
            if argv[index] == nil then
                fail("--address requires a value")
            end
            options.address = argv[index]
            index = index + 1
        elseif value == "--expr" then
            index = index + 1
            if argv[index] == nil then
                fail("--expr requires an expression")
            end
            options.expressions[#options.expressions + 1] = argv[index]
            index = index + 1
        elseif value == "--xmin" or value == "--xmax" then
            local name = value
            index = index + 1
            options[name:sub(3)] = parse_number_option(name, argv[index])
            index = index + 1
        elseif value == "--no-open" then
            options.open_browser = false
            index = index + 1
        elseif value == "--eval" then
            index = index + 1
            if argv[index] == nil then
                fail("--eval requires an expression")
            end
            options.eval = argv[index]
            index = index + 1
        elseif value == "--at" then
            index = index + 1
            options.at = parse_number_option("--at", argv[index])
            index = index + 1
        elseif value == "--svg" then
            index = index + 1
            if argv[index] == nil then
                fail("--svg requires a file name")
            end
            options.svg = argv[index]
            index = index + 1
        elseif value == "--token" then
            index = index + 1
            if argv[index] == nil then
                fail("--token requires a value")
            end
            options.token = argv[index]
            index = index + 1
        elseif value == "--stop-path" then
            index = index + 1
            if argv[index] == nil then
                fail("--stop-path requires a value")
            end
            options.stop_path = argv[index]
            index = index + 1
        else
            fail("unknown option: " .. tostring(value))
        end
    end

    return options
end

local options = parse_args(arg)

if options.eval then
    local fn, err = compile(options.eval)
    if fn == nil then
        fail(err, 1)
    end
    local ok, value = pcall(fn, options.at)
    if not ok then
        fail(tostring(value), 1)
    end
    print(string.format("%.12g", value))
    os.exit(0)
end

local state = default_state()
for _, expr in ipairs(options.expressions) do
    if #state.curves >= MAX_CURVES then
        fail("at most " .. tostring(MAX_CURVES) .. " expressions")
    end
    add_curve(state, expr)
end
if #state.curves == 0 then
    add_curve(state, "sin(x)")
end
if options.xmin then
    state.xmin = options.xmin
end
if options.xmax then
    state.xmax = options.xmax
end
if not valid_span(state.xmin, state.xmax) then
    fail("--xmin has to be less than --xmax")
end

if options.svg then
    compile_curves(state)
    local failed = false
    for _, curve in ipairs(state.curves) do
        if curve.error then
            io.stderr:write("graphcalc: ", curve.expr, ": ", curve.error, "\n")
            failed = true
        end
    end
    if failed then
        os.exit(1)
    end
    local svg = build_plot(state)
    local handle, err = io.open(options.svg, "wb")
    if handle == nil then
        fail("could not open '" .. options.svg .. "': " .. tostring(err), 1)
    end
    handle:write(svg)
    handle:close()
    print("wrote " .. options.svg)
    os.exit(0)
end

local page = create_page(state)

ui.serve {
    page = page,
    address = options.address,
    port = options.port,
    open_browser = options.open_browser,
    token = options.token,
    stop_path = options.stop_path,
    api = {
        GET = {
            ["/plot.svg"] = function()
                compile_curves(state)
                local svg = build_plot(state)
                return {
                    status = 200,
                    body = svg,
                    header = {
                        content_type = "image/svg+xml; charset=utf-8",
                        ["content-disposition"] = 'attachment; filename="plot.svg"',
                        ["cache-control"] = "no-store",
                    },
                }
            end,
        },
    },
}
