-- Component tree for the web UI.
--
-- Nodes are plain tables with a small method table. Every node has a stable
-- monotonic id that the client uses to morph the DOM, and an optional `name`
-- that makes it reachable through `ui.current`.

local M = {}

local id_sequence = 0

local function next_id()
    id_sequence = id_sequence + 1
    return "c" .. id_sequence
end

M.next_id = next_id

-- props that every component accepts
local universal = {
    name = true,
    width = true,
    height = true,
    grow = true,
    hidden = true,
    disabled = true,
    style = true,
    aria = true,
    data = true,
    class = true,
}

local specs = {}

local function define(kind, spec)
    local props = {}
    for key in pairs(universal) do
        props[key] = true
    end
    for _, key in ipairs(spec.props or {}) do
        props[key] = true
    end
    local events = {}
    for _, key in ipairs(spec.events or {}) do
        events[key] = true
    end
    local value_props = {}
    for _, key in ipairs(spec.value or {}) do
        props[key] = true
        value_props[key] = true
    end
    local required = {}
    for _, key in ipairs(spec.required or {}) do
        props[key] = true
        required[key] = true
    end
    specs[kind] = {
        kind = kind,
        props = props,
        events = events,
        value_props = value_props,
        required = required,
        children = spec.children or false,
        text = spec.text or false,
        alias = spec.alias or {},
    }
end

define("page", { children = true, props = { "title", "lang", "theme", "css", "align", "gap", "padding" } })

define("verticalLayout", { children = true, props = { "align", "gap", "padding", "justify", "wrap" } })
define("horizontalLayout", { children = true, props = { "align", "gap", "padding", "justify", "wrap" } })
define("panel", { children = true, props = { "align", "gap", "padding", "title" }, alias = { "card" } })

define("label", { text = true, props = { "text", "muted" } })
define("heading", { text = true, props = { "text", "level" } })
define("button", { text = true, props = { "text", "kind" }, events = { "onClick" } })
define("textField", {
    props = { "label", "placeholder", "type", "readonly" },
    events = { "onInput", "onChange" },
    value = { "value" },
})
define("textArea", {
    props = { "label", "placeholder", "rows", "readonly" },
    events = { "onInput", "onChange" },
    value = { "value" },
})
define("checkbox", { props = { "text" }, events = { "onChange" }, value = { "checked" } })
define("select", {
    props = { "label", "options", "placeholder" },
    events = { "onChange" },
    value = { "value" },
})
define("radioGroup", { props = { "label", "options" }, events = { "onChange" }, value = { "value" } })
define("list", { props = { "items", "ordered" }, events = { "onSelect" }, value = { "value" } })
define("table", { props = { "columns", "rows", "rowKey", "empty" }, events = { "onRowClick" } })
define("image", { props = { "src", "alt" }, required = { "src" } })
define("link", { text = true, props = { "text", "href", "route" }, events = { "onClick" } })
define("markdown", { props = { "text" } })
define("html", { props = { "text" } })
define("divider", { props = {} })
define("progress", { props = { "value", "max", "indeterminate" } })
define("tabs", {
    children = true,
    props = { "labels", "index" },
    events = { "onChange" },
    value = { "index" },
})
define("dialog", { children = true, props = { "title", "open", "closeText" }, events = { "onClose" } })

local Node = {}
Node.__index = Node

local function fail(format, ...)
    error(format:format(...), 3)
end

local function is_array_key(key)
    return type(key) == "number"
end

local function create(kind, options, ...)
    local spec = specs[kind]
    if spec == nil then
        fail("unknown component '%s'", tostring(kind))
    end

    if type(options) == "string" then
        options = { text = options }
    end
    options = options or {}

    local node = setmetatable({
        kind = kind,
        id = next_id(),
        props = {},
        handlers = {},
        children = {},
        parent = nil,
        state = { value = nil, error = nil, open = false },
    }, Node)

    for key, value in pairs(options) do
        if not is_array_key(key) then
            if spec.events[key] then
                if type(value) ~= "function" then
                    fail("%s.%s has to be a function", kind, key)
                end
                node.handlers[key] = value
            elseif spec.props[key] then
                if spec.value_props[key] then
                    node.state.value = value
                else
                    node.props[key] = value
                end
            else
                fail("%s does not accept '%s'", kind, tostring(key))
            end
        end
    end

    for key in pairs(spec.required) do
        if node.props[key] == nil then
            fail("%s requires '%s'", kind, key)
        end
    end

    local children = {}
    for index = 1, select("#", ...) do
        children[#children + 1] = select(index, ...)
    end
    for index = 1, #options do
        children[#children + 1] = options[index]
    end
    if #children > 0 then
        node:add(table.unpack(children, 1, #children))
    end
    return node
end

M.create = create

function Node:add(...)
    local count = select("#", ...)
    for index = 1, count do
        local child = select(index, ...)
        if child == nil then
            fail("%s:add got nil as child %d", self.kind, index)
        end
        if type(child) ~= "table" or child.kind == nil then
            fail("%s:add expects components, got %s", self.kind, type(child))
        end
        child.parent = self
        self.children[#self.children + 1] = child
    end
    return self
end

function Node:insert(index, child)
    child.parent = self
    table.insert(self.children, index, child)
    return child
end

function Node:remove(child)
    for index, candidate in ipairs(self.children) do
        if candidate == child then
            table.remove(self.children, index)
            child.parent = nil
            return true
        end
    end
    return false
end

function Node:clear()
    for _, child in ipairs(self.children) do
        child.parent = nil
    end
    self.children = {}
    return self
end

function Node:each()
    local index = 0
    return function()
        index = index + 1
        return self.children[index]
    end
end

-- values ------------------------------------------------------------------

function Node:value()
    return self.state.value
end

function Node:setValue(value)
    self.state.value = value
    return self
end

function Node:text()
    return self.props.text
end

function Node:setText(text)
    self.props.text = text
    return self
end

function Node:setError(message)
    self.state.error = message
    return self
end

function Node:error()
    return self.state.error
end

function Node:setVisible(visible)
    self.props.hidden = not visible
    return self
end

function Node:setDisabled(disabled)
    self.props.disabled = disabled
    return self
end

function Node:open()
    self.state.open = true
    return self
end

function Node:close()
    self.state.open = false
    return self
end

function Node:isOpen()
    return self.state.open
end

-- lookup ------------------------------------------------------------------

local function walk(node, visitor)
    visitor(node)
    for _, child in ipairs(node.children) do
        walk(child, visitor)
    end
end

M.walk = walk

function M.index(page)
    local names = {}
    walk(page, function(node)
        local name = node.props.name
        if name == nil then
            return
        end
        if type(name) ~= "string" or name == "" then
            fail("component name has to be a non empty string")
        end
        if name == "id" or name == "kind" or name == "values" then
            fail("component name '%s' is reserved", name)
        end
        if names[name] ~= nil and names[name] ~= node then
            fail("duplicate component name '%s'", name)
        end
        names[name] = node
    end)
    return names
end

function M.named(page, name)
    return M.index(page)[name]
end

M.spec = function(kind)
    return specs[kind]
end

M.kinds = function()
    local list = {}
    for kind in pairs(specs) do
        list[#list + 1] = kind
    end
    table.sort(list)
    return list
end

return M
