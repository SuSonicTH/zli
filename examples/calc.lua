-- A basic calculator served through the webui component model, evaluating the
-- keys with the usual arithmetic precedence.
--
-- Run it with `zli examples/calc.lua`; see calc.md for the key reference and
-- the rules the arithmetic follows.
--
-- The layout is built from the components webui already ships: the keypad is a
-- stack of horizontal layouts whose keys grow to the same width.  No custom
-- page style is used, so the page looks like the rest of a webui page.

local argparse = require "argparse"
local ui = require "webui"

local MAX_DIGITS = 32

-- ---------------------------------------------------------------------------
-- calculator state
-- ---------------------------------------------------------------------------

-- `tokens` is the part of the expression that has been committed (numbers and
-- operators), `entry` the number currently being typed or the last result.
local state = {
    tokens = {},
    entry = "0",
    typing = false,
    memory = 0,
    error = nil,
    last_op = nil, -- what "=" repeats
    last_operand = nil,

    --- True while an error message blocks every key but C, CE and the digits.
    blocked = function(self)
        return self.error ~= nil
    end,

    --- Latch an error message; "C", "CE" or a digit clears it again.
    fail = function(self, message)
        self.error = message
        self.typing = false
    end,

    --- Reset the expression and the display, keeping memory.
    clear_all = function(self)
        self.tokens = {}
        self.entry = "0"
        self.typing = false
        self.error = nil
        self.last_op = nil
        self.last_operand = nil
    end,

    --- Clear only the number being typed, keeping the expression before it.
    clear_entry = function(self)
        self.entry = "0"
        self.typing = true
        self.error = nil
    end
}

--- The entry as a number. The entry keys keep it parseable, so this is an
-- invariant rather than user input validation.
local function entry_number()
    local value = tonumber(state.entry)
    assert(value ~= nil, "unparsable entry: " .. state.entry)
    return value
end

--- True when the entry is a plain decimal literal that a digit or "." extends.
-- Computed values can be formatted in exponent notation ("1e-06"), which no
-- longer takes appended characters without changing meaning or breaking the
-- parse, so those keys start a fresh number instead.
local function entry_is_plain()
    return state.entry:match("^%-?%d+%.?%d*$") ~= nil
end

--- Text for a computed value. Integers lose the ".0"; everything else uses
-- the shortest %g form that hides double rounding noise (0.1 + 0.2 -> "0.3").
local function format_value(value)
    local integer = math.tointeger(value)
    if integer ~= nil then
        return tostring(integer)
    end
    return string.format("%.15g", value)
end

local function finite(value)
    return value == value and value ~= math.huge and value ~= -math.huge
end

--- Put a computed value into the entry, keeping it visible while an operator
-- waits for it. The entry therefore only ever holds text that parses again;
-- a non-finite result is reported like any other overflow.
local function set_entry(value)
    if not finite(value) then
        state:fail("Overflow.")
        return
    end
    state.entry = format_value(value)
    state.typing = #state.tokens > 0
end

--- The expression as the user typed it, plus the number in progress.
local function display_text()
    local parts = {}
    for _, token in ipairs(state.tokens) do
        parts[#parts + 1] = token.text
    end
    if state.typing or #state.tokens == 0 then
        parts[#parts + 1] = state.entry
    end
    return table.concat(parts)
end

local function number_token(text)
    local value = tonumber(text)
    assert(value ~= nil, "unparsable number: " .. text)
    return { kind = "number", text = text, value = value }
end

--- Apply one binary operator, reporting the two arithmetic errors.
local function apply(op, left, right)
    if op == "/" and right == 0 then
        return nil, "Cannot divide by zero."
    end
    local value
    if op == "+" then
        value = left + right
    elseif op == "-" then
        value = left - right
    elseif op == "*" then
        value = left * right
    else
        value = left / right
    end
    if not finite(value) then
        return nil, "Overflow."
    end
    return value
end

--- Evaluate a well formed token list: numbers and operators, in order.
-- "*" and "/" are folded left to right first, then "+" and "-" over the
-- results, which is the usual precedence without a parser stack.
local function evaluate(tokens)
    local numbers, ops = {}, {}
    for _, token in ipairs(tokens) do
        if token.kind == "number" then
            numbers[#numbers + 1] = token.value
        else
            ops[#ops + 1] = token.text
        end
    end

    -- pass one: multiplication and division
    local values, adds = { numbers[1] }, {}
    for index, op in ipairs(ops) do
        local right = numbers[index + 1]
        if op == "*" or op == "/" then
            local value, err = apply(op, values[#values], right)
            if err then
                return nil, err
            end
            values[#values] = value
        else
            adds[#adds + 1] = op
            values[#values + 1] = right
        end
    end

    -- pass two: addition and subtraction, left to right
    local total = values[1]
    for index, op in ipairs(adds) do
        local value, err = apply(op, total, values[index + 1])
        if err then
            return nil, err
        end
        total = value
    end
    return total
end

--- Value of everything before the trailing operator, for "%".
local function prefix_value()
    local prefix = {}
    for index = 1, #state.tokens - 1 do
        prefix[index] = state.tokens[index]
    end
    return evaluate(prefix)
end

-- ---------------------------------------------------------------------------
-- keys
-- ---------------------------------------------------------------------------

local function digit(text)
    if state:blocked() then
        state:clear_all()
    end
    if state.typing and entry_is_plain() then
        local digits = #(state.entry:gsub("%D", ""))
        if digits >= MAX_DIGITS then
            return
        end
        if state.entry == "0" then
            state.entry = text
        elseif state.entry == "-0" then
            state.entry = "-" .. text
        else
            state.entry = state.entry .. text
        end
    else
        state.entry = text
        state.typing = true
    end
end

local function decimal_point()
    if state:blocked() then
        state:clear_all()
    end
    if not state.typing or not entry_is_plain() then
        state.entry = "0."
        state.typing = true
    elseif not state.entry:find(".", 1, true) then
        state.entry = state.entry .. "."
    end
end

local function backspace()
    if state:blocked() then
        return
    end
    if state.typing then
        local shorter = state.entry:sub(1, -2)
        if not entry_is_plain() or shorter == "" or shorter == "-" then
            -- the number is gone, so the next backspace undoes the operator
            state.entry = "0"
            state.typing = false
        else
            state.entry = shorter
        end
        return
    end
    -- undo the last operator: pull its left hand number back into the entry
    local last = state.tokens[#state.tokens]
    if last == nil or last.kind ~= "op" then
        return
    end
    table.remove(state.tokens)
    local number = state.tokens[#state.tokens]
    if number ~= nil and number.kind == "number" then
        table.remove(state.tokens)
        state.entry = number.text
        state.typing = true
    end
end

local function negate()
    if state:blocked() then
        return
    end
    if not state.typing and #state.tokens > 0 then
        -- the expression ends with an operator, there is no operand to flip
        return
    end
    if entry_number() == 0 then
        return
    end
    if state.entry:sub(1, 1) == "-" then
        state.entry = state.entry:sub(2)
    else
        state.entry = "-" .. state.entry
    end
end

--- A unary key works on the entry. When an operator is pending the entry still
-- holds the number that operator will use, so "√", "1/x", "%" and "+/-" apply
-- to the operand on the left of the operator.
local function apply_unary(transform)
    if state:blocked() then
        return
    end
    local value, err = transform(entry_number())
    if err then
        state:fail(err)
        return
    end
    set_entry(value)
end

local function square_root()
    apply_unary(function(value)
        if value < 0 then
            return nil, "Invalid input."
        end
        return math.sqrt(value)
    end)
end

local function reciprocal()
    apply_unary(function(value)
        if value == 0 then
            return nil, "Cannot divide by zero."
        end
        return 1 / value
    end)
end

local function percent()
    if state:blocked() then
        return
    end
    local value = entry_number()
    local last = state.tokens[#state.tokens]
    local result
    if last ~= nil and (last.text == "+" or last.text == "-") then
        -- "100 + 10 %" is ten percent of what is already there
        local base, err = prefix_value()
        if err then
            state:fail(err)
            return
        end
        result = base * value / 100
    else
        result = value / 100
    end
    set_entry(result)
end

local function set_operator(op)
    if state:blocked() then
        return
    end
    local last = state.tokens[#state.tokens]
    if last ~= nil and last.kind == "op" and not state.typing then
        -- a second operator in a row replaces the pending one
        last.text = op
        return
    end
    state.tokens[#state.tokens + 1] = number_token(state.entry)
    state.tokens[#state.tokens + 1] = { kind = "op", text = op }
    state.typing = false
    state.last_op = nil
    state.last_operand = nil
end

local function equals()
    if state:blocked() then
        return
    end

    local tokens = { table.unpack(state.tokens) }

    if state.typing then
        tokens[#tokens + 1] = number_token(state.entry)
    elseif #tokens > 0 and tokens[#tokens].kind == "op" then
        -- "2 + =" applies the operator to the number on its left
        local number = tokens[#tokens - 1]
        tokens[#tokens + 1] = number_token(number.text)
    elseif #tokens == 0 then
        if state.last_op == nil then
            return
        end
        -- "=" again repeats the last operation on the result
        tokens[1] = number_token(state.entry)
        tokens[2] = { kind = "op", text = state.last_op }
        tokens[3] = number_token(format_value(state.last_operand))
    end

    local last_op, last_operand
    for _, token in ipairs(tokens) do
        if token.kind == "op" then
            last_op = token.text
        else
            last_operand = token.value
        end
    end

    local result, err = evaluate(tokens)
    if err then
        state.tokens = {}
        state.last_op = nil
        state.last_operand = nil
        state:fail(err)
        return
    end

    state.tokens = {}
    state.entry = format_value(result)
    state.typing = false
    state.last_op = last_op
    state.last_operand = last_operand
end

local function memory_clear()
    if state:blocked() then
        return
    end
    state.memory = 0
end

local function memory_recall()
    if state:blocked() then
        return
    end
    set_entry(state.memory)
end

local function memory_store()
    if state:blocked() then
        return
    end
    state.memory = entry_number()
end

local function memory_add()
    if state:blocked() then
        return
    end
    local total = state.memory + entry_number()
    if not finite(total) then
        state:fail("Overflow.")
        return
    end
    state.memory = total
end

-- ---------------------------------------------------------------------------
-- page
-- ---------------------------------------------------------------------------

local function create_page()
    local page = ui.page { title = "Calculator" }

    -- the display is a right aligned label above a divider, which keeps the
    -- number readable without a page style block
    local display = ui.label {
        text = "",
        style = { ["text-align"] = "right" },
    }
    local memory_marker = ui.label { text = "", muted = true }

    local function redraw()
        display.props.text = state.error or display_text()
        memory_marker.props.text = state.memory ~= 0 and "M" or ""
    end

    -- The action is called with the visible label, so the digit and operator
    -- handlers can be passed directly: their label is the value they need.
    local function key(label, action)
        return ui.button {
            text = label,
            grow = 1,
            onClick = function()
                action(label)
                redraw()
            end,
        }
    end

    -- an empty cell three keys wide, used to align the top row; a single wide
    -- spacer keeps its share in a row and leaves one blank line instead of
    -- three when the layout stacks on a narrow screen
    local function spacer()
        return ui.label { text = "", grow = 3 }
    end

    local function row(...)
        local layout = ui.horizontalLayout { align = "horizontal" }
        layout:add(...)
        return layout
    end

    local shell = ui.verticalLayout { width = 380 }
    shell:add(ui.heading { text = "Calculator", level = 1 })
    shell:add(ui.horizontalLayout {
        align = "horizontal",
        justify = "space-between",
        memory_marker,
        display,
    })
    shell:add(ui.divider())

    shell:add(row(
        spacer(),
        key("←", backspace),
        key("CE", function() state:clear_entry() end),
        key("C", function() state:clear_all() end)))

    shell:add(row(
        key("MC", memory_clear),
        key("7", digit),
        key("8", digit),
        key("9", digit),
        key("/", set_operator),
        key("√", square_root)))

    shell:add(row(
        key("MR", memory_recall),
        key("4", digit),
        key("5", digit),
        key("6", digit),
        key("*", set_operator),
        key("%", percent)))

    shell:add(row(
        key("MS", memory_store),
        key("1", digit),
        key("2", digit),
        key("3", digit),
        key("-", set_operator),
        key("1/x", reciprocal)))

    shell:add(row(
        key("M+", memory_add),
        key("0", digit),
        key("+/-", negate),
        key(".", decimal_point),
        key("+", set_operator),
        key("=", equals)))

    page:add(shell)
    redraw()
    return page
end

-- ---------------------------------------------------------------------------
-- command line
-- ---------------------------------------------------------------------------

--- Convert a port option, rejecting ports the server cannot bind.
local function port_number(value)
    local number = tonumber(value)
    if number == nil or number % 1 ~= 0 or number < 0 or number > 65535 then
        return nil -- argparse reports "malformed argument '...'"
    end
    return number
end

local parser = argparse("calc", "A basic calculator on webui; \"=\" evaluates "
    .. "the expression with the usual precedence.")
parser:option("--port", "listen port, 0 picks a free port (default 8080)")
    :default(8080):convert(port_number)
parser:option("--address", "bind address"):default("127.0.0.1")
parser:flag("--no-open", "do not open the system browser")
parser:option("--token", "fixed session token (tests and automation)")
parser:option("--stop-path", "POST path that stops the server (tests and automation)")
local options = parser:parse()

local page = create_page()

ui.serve {
    page = page,
    address = options.address,
    port = options.port,
    open_browser = not options.no_open,
    token = options.token,
    stop_path = options.stop_path,
}
