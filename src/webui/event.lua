-- Event parsing and dispatch for the web UI.
--
-- The browser posts form encoded parameters: `id` and `kind` identify the
-- component and the interaction, and every named input in the page is included
-- so the server always sees the current values.

local component = require "webui.component"

local M = {}

-- kinds whose value is sent by the browser
local value_kinds = {
    textField = true,
    textArea = true,
    checkbox = true,
    select = true,
    radioGroup = true,
}

-- kind of event -> handler name, per component kind
local handlers = {
    button = { click = "onClick" },
    link = { click = "onClick" },
    textField = { input = "onInput", change = "onChange" },
    textArea = { input = "onInput", change = "onChange" },
    checkbox = { change = "onChange" },
    select = { change = "onChange" },
    radioGroup = { change = "onChange" },
    list = { select = "onSelect" },
    table = { rowclick = "onRowClick" },
    tabs = { change = "onChange" },
    dialog = { close = "onClose" },
}

local function decode(text)
    text = text:gsub("+", " ")
    text = text:gsub("%%(%x%x)", function(hex)
        return string.char(tonumber(hex, 16))
    end)
    return text
end

--- Parse an url encoded request body into a table. Later values win.
function M.parse_form(body)
    local params = {}
    for pair in tostring(body or ""):gmatch("[^&]+") do
        local key, value = pair:match("^([^=]*)=?(.*)$")
        if key and key ~= "" then
            params[decode(key)] = decode(value)
        end
    end
    return params
end

M.decode = decode

--- Apply the submitted form values to the named components of a page.
function M.apply_values(page, params)
    for name, node in pairs(component.index(page)) do
        if value_kinds[node.kind] then
            if node.kind == "checkbox" then
                node.state.value = params[name] ~= nil
            else
                node.state.value = params[name]
            end
        end
    end
end

--- Find a component by id in any of the pages.
-- returns: node, route, page
function M.find(pages, id)
    for route, page in pairs(pages) do
        local found = nil
        component.walk(page, function(node)
            if node.id == id then
                found = node
            end
        end)
        if found then
            return found, route, page
        end
    end
    return nil
end

local function coerce_value(node, event_kind, value)
    if value == nil then
        return nil
    end
    if node.kind == "list" or node.kind == "tabs" then
        return tonumber(value) or value
    end
    if node.kind == "table" then
        return value
    end
    return tostring(value)
end

--- Run the handler of one posted event.
-- returns: error message (nil on success)
function M.call(page, node, params, client)
    local event_kind = params.kind or "click"
    local table_for_kind = handlers[node.kind]
    local handler_name = table_for_kind and table_for_kind[event_kind]
    if handler_name == nil then
        return "component does not handle '" .. tostring(event_kind) .. "'"
    end

    local handler = node.handlers[handler_name]
    if handler == nil then
        return nil
    end

    local event = {
        kind = event_kind,
        value = coerce_value(node, event_kind, params.value),
        client = client,
        values = params,
    }

    local ok, err = pcall(handler, node, event)
    if not ok then
        return tostring(err)
    end
    return nil
end

function M.handler_name(kind, event_kind)
    local table_for_kind = handlers[kind]
    return table_for_kind and table_for_kind[event_kind]
end

return M
