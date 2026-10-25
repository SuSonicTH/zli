-- HTML rendering for the web UI component tree.
--
-- The rendered markup is already wired for htmx: interactive components carry
-- hx-post/hx-trigger/hx-include attributes, and every node has a stable
-- data-id so idiomorph can reuse the DOM node across updates.

local markdown = require "markdown"

local M = {}

local ENDPOINT = "/__webui/event"
local TARGET = "#webui-root"
local SWAP = "morph:outerHTML"

-- ---------------------------------------------------------------------------
-- escaping and attribute helpers
-- ---------------------------------------------------------------------------

local escapes = {
    ["&"] = "&amp;",
    ["<"] = "&lt;",
    [">"] = "&gt;",
    ['"'] = "&quot;",
    ["'"] = "&#39;",
}

local function esc(value)
    return (tostring(value):gsub("[&<>\"']", escapes))
end

M.escape = esc

local function single_quote_esc(value)
    return (tostring(value):gsub("[&'<>]", escapes))
end

local function json_string(value)
    local text = tostring(value)
    text = text:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("[\r\n\t]", " ")
    return '"' .. text .. '"'
end

local function json_object(values)
    local keys = {}
    for key in pairs(values) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    local out = {}
    for _, key in ipairs(keys) do
        local value = values[key]
        if type(value) == "number" then
            out[#out + 1] = json_string(key) .. ":" .. tostring(value)
        elseif type(value) == "boolean" then
            out[#out + 1] = json_string(key) .. ":" .. tostring(value)
        else
            out[#out + 1] = json_string(key) .. ":" .. json_string(value)
        end
    end
    return "{" .. table.concat(out, ",") .. "}"
end

local function size(value)
    if type(value) == "number" then
        return tostring(value) .. "px"
    end
    if value == "full" then
        return "100%"
    end
    return tostring(value)
end

local function validate_style(name, value)
    if type(name) ~= "string" or not name:match("^[a-z][a-z0-9%-]*$") then
        error("invalid style property '" .. tostring(name) .. "'", 3)
    end
    local text = tostring(value)
    if text:find("[;{}<>]") or text:find("url%(") then
        error("invalid value for style property '" .. name .. "'", 3)
    end
    return text
end

local function style_of(node)
    local props = node.props
    local parts = {}

    local function add(name, value)
        parts[#parts + 1] = name .. ":" .. validate_style(name, value)
    end

    if props.width then add("width", size(props.width)) end
    if props.height then add("height", size(props.height)) end
    if props.grow then add("flex", props.grow) end
    if props.gap then add("gap", size(props.gap)) end
    if props.padding then add("padding", size(props.padding)) end
    if props.margin then add("margin", size(props.margin)) end
    if props.justify then add("justify-content", props.justify) end

    for name, value in pairs(props.style or {}) do
        add(name, value)
    end

    if #parts == 0 then
        return nil
    end
    return table.concat(parts, ";")
end

local function common_attrs(node)
    local out = { 'data-id="' .. esc(node.id) .. '"' }
    local style = style_of(node)
    if style then
        out[#out + 1] = 'style="' .. esc(style) .. '"'
    end
    if node.props.class then
        local class = tostring(node.props.class)
        if not class:match("^[%w%-_ ]+$") then
            error("invalid class '" .. class .. "'", 3)
        end
        out[#out + 1] = 'class="' .. esc(class) .. '"'
    end
    if node.props.hidden then
        out[#out + 1] = "hidden"
    end
    for name, value in pairs(node.props.aria or {}) do
        if not tostring(name):match("^[a-z][a-z0-9%-]*$") then
            error("invalid aria attribute '" .. tostring(name) .. "'", 3)
        end
        out[#out + 1] = 'aria-' .. name .. '="' .. esc(value) .. '"'
    end
    for name, value in pairs(node.props.data or {}) do
        if not tostring(name):match("^[a-z][a-z0-9%-]*$") then
            error("invalid data attribute '" .. tostring(name) .. "'", 3)
        end
        out[#out + 1] = 'data-' .. name .. '="' .. esc(value) .. '"'
    end
    return table.concat(out, " ")
end

--- htmx attributes for an event sending element.
-- kind == nil means the client derives the kind from the trigger that fired.
local function event_attrs(node, kind, trigger, sync, params)
    local values = { id = node.id }
    if kind then
        values.kind = kind
    end
    for name, value in pairs(params or {}) do
        values[name] = value
    end

    local out = {
        'hx-post="' .. ENDPOINT .. '"',
        'hx-trigger="' .. esc(trigger) .. '"',
        "hx-vals='" .. single_quote_esc(json_object(values)) .. "'",
        'hx-include="' .. TARGET .. ' [name]"',
        'hx-sync="' .. esc(sync) .. '"',
        'hx-target="' .. TARGET .. '"',
        'hx-swap="' .. SWAP .. '"',
    }
    if kind == nil then
        out[#out + 1] = 'data-webui-trigger-kind="1"'
    end
    return table.concat(out, " ")
end

-- ---------------------------------------------------------------------------
-- renderers
-- ---------------------------------------------------------------------------

local renderers = {}

local function children_html(node)
    local out = {}
    for _, child in ipairs(node.children) do
        out[#out + 1] = M.render(child)
    end
    return table.concat(out)
end

local function label_html(node)
    if node.props.label == nil or node.props.label == "" then
        return ""
    end
    return '<span class="webui-label">' .. esc(node.props.label) .. "</span>"
end

local function error_html(node)
    if node.state.error == nil then
        return ""
    end
    return '<span class="webui-error-text">' .. esc(node.state.error) .. "</span>"
end

local function field_class(node)
    return node.state.error ~= nil and "webui-field webui-error" or "webui-field"
end

local direction = {
    vertical = "webui-layout-vertical",
    column = "webui-layout-vertical",
    horizontal = "webui-layout-horizontal",
    row = "webui-layout-horizontal",
}

local function layout(node)
    local align = node.props.align or (node.kind == "horizontalLayout" and "horizontal" or "vertical")
    local class = direction[align]
    if class == nil then
        error("align has to be 'vertical' or 'horizontal', got '" .. tostring(align) .. "'", 3)
    end
    local classes = { "webui-layout", class }
    if node.props.wrap then
        classes[#classes + 1] = "webui-layout-wrap"
    end
    return '<div class="' .. table.concat(classes, " ") .. '" '
        .. common_attrs(node) .. ">" .. children_html(node) .. "</div>"
end

renderers.verticalLayout = layout
renderers.horizontalLayout = layout

renderers.panel = function(node)
    local out = { '<div class="webui-panel" ', common_attrs(node), ">" }
    if node.props.title then
        out[#out + 1] = '<div class="webui-panel-title">' .. esc(node.props.title) .. "</div>"
    end
    out[#out + 1] = children_html(node)
    out[#out + 1] = "</div>"
    return table.concat(out)
end

renderers.label = function(node)
    local class = node.props.muted and "webui-label webui-muted" or "webui-label"
    return '<span class="' .. class .. '" ' .. common_attrs(node) .. ">"
        .. esc(node.props.text or "") .. "</span>"
end

renderers.heading = function(node)
    local level = tonumber(node.props.level) or 2
    if level < 1 or level > 6 then
        error("heading level has to be between 1 and 6", 3)
    end
    local tag = "h" .. level
    return "<" .. tag .. ' class="webui-heading" ' .. common_attrs(node) .. ">"
        .. esc(node.props.text or "") .. "</" .. tag .. ">"
end

renderers.button = function(node)
    local attrs = common_attrs(node)
    if node.props.disabled then
        attrs = attrs .. " disabled"
    end
    if node.handlers.onClick then
        attrs = attrs .. " " .. event_attrs(node, "click", "click", TARGET .. ":queue all")
    end
    return '<button type="button" class="webui-button" ' .. attrs .. ">"
        .. esc(node.props.text or "") .. "</button>"
end

renderers.textField = function(node)
    local input_type = node.props.type or "text"
    if not tostring(input_type):match("^[a-z]+$") then
        error("invalid text field type", 3)
    end
    local attrs = {
        'class="webui-input"',
        'type="' .. esc(input_type) .. '"',
    }
    if node.props.name then
        attrs[#attrs + 1] = 'name="' .. esc(node.props.name) .. '"'
    end
    if node.props.placeholder then
        attrs[#attrs + 1] = 'placeholder="' .. esc(node.props.placeholder) .. '"'
    end
    if node.props.readonly then
        attrs[#attrs + 1] = "readonly"
    end
    if node.props.disabled then
        attrs[#attrs + 1] = "disabled"
    end
    attrs[#attrs + 1] = 'value="' .. esc(node.state.value or "") .. '"'
    attrs[#attrs + 1] = common_attrs(node)
    if node.handlers.onInput or node.handlers.onChange then
        attrs[#attrs + 1] = event_attrs(node, nil, "input changed delay:120ms, change", "this:queue last")
    end
    return '<div class="' .. field_class(node) .. '">' .. label_html(node)
        .. "<input " .. table.concat(attrs, " ") .. ">" .. error_html(node) .. "</div>"
end

renderers.textArea = function(node)
    local attrs = { 'class="webui-textarea"' }
    if node.props.name then
        attrs[#attrs + 1] = 'name="' .. esc(node.props.name) .. '"'
    end
    if node.props.placeholder then
        attrs[#attrs + 1] = 'placeholder="' .. esc(node.props.placeholder) .. '"'
    end
    if node.props.rows then
        attrs[#attrs + 1] = 'rows="' .. esc(node.props.rows) .. '"'
    end
    if node.props.readonly then
        attrs[#attrs + 1] = "readonly"
    end
    if node.props.disabled then
        attrs[#attrs + 1] = "disabled"
    end
    attrs[#attrs + 1] = common_attrs(node)
    if node.handlers.onInput or node.handlers.onChange then
        attrs[#attrs + 1] = event_attrs(node, nil, "input changed delay:120ms, change", "this:queue last")
    end
    return '<div class="' .. field_class(node) .. '">' .. label_html(node)
        .. "<textarea " .. table.concat(attrs, " ") .. ">" .. esc(node.state.value or "")
        .. "</textarea>" .. error_html(node) .. "</div>"
end

renderers.checkbox = function(node)
    local attrs = {
        'class="webui-checkbox"',
        'type="checkbox"',
    }
    if node.props.name then
        attrs[#attrs + 1] = 'name="' .. esc(node.props.name) .. '"'
    end
    attrs[#attrs + 1] = 'value="on"'
    if node.state.value then
        attrs[#attrs + 1] = "checked"
    end
    if node.props.disabled then
        attrs[#attrs + 1] = "disabled"
    end
    attrs[#attrs + 1] = common_attrs(node)
    if node.handlers.onChange then
        attrs[#attrs + 1] = event_attrs(node, "change", "change", "this:queue last")
    end
    return "<label " .. attrs[1] .. "><input " .. table.concat(attrs, " ", 2) .. ">"
        .. "<span>" .. esc(node.props.text or "") .. "</span></label>"
end

local function options_list(node)
    local entries = node.props.options or {}
    local out = {}
    for index, option in ipairs(entries) do
        if type(option) == "table" then
            out[#out + 1] = {
                value = option.value ~= nil and option.value or option[1] or option.label,
                label = option.label or option[2] or option.value or option[1],
                disabled = option.disabled,
            }
        else
            out[#out + 1] = { value = option, label = option }
        end
    end
    return out
end

renderers.select = function(node)
    local attrs = { 'class="webui-select"' }
    if node.props.name then
        attrs[#attrs + 1] = 'name="' .. esc(node.props.name) .. '"'
    end
    if node.props.disabled then
        attrs[#attrs + 1] = "disabled"
    end
    attrs[#attrs + 1] = common_attrs(node)
    if node.handlers.onChange then
        attrs[#attrs + 1] = event_attrs(node, "change", "change", "this:queue last")
    end

    local out = { '<div class="' .. field_class(node) .. '">', label_html(node) }
    out[#out + 1] = "<select " .. table.concat(attrs, " ") .. ">"
    if node.props.placeholder then
        out[#out + 1] = '<option value="">' .. esc(node.props.placeholder) .. "</option>"
    end
    for _, option in ipairs(options_list(node)) do
        local selected = tostring(option.value) == tostring(node.state.value) and " selected" or ""
        local disabled = option.disabled and " disabled" or ""
        out[#out + 1] = '<option value="' .. esc(option.value) .. '"' .. selected .. disabled .. ">"
            .. esc(option.label) .. "</option>"
    end
    out[#out + 1] = "</select>" .. error_html(node) .. "</div>"
    return table.concat(out)
end

renderers.radioGroup = function(node)
    local out = { '<div class="' .. field_class(node) .. '">', label_html(node) }
    out[#out + 1] = '<div class="webui-radio-group" role="radiogroup" ' .. common_attrs(node) .. ">"
    for _, option in ipairs(options_list(node)) do
        local checked = tostring(option.value) == tostring(node.state.value) and " checked" or ""
        local name = node.props.name and (' name="' .. esc(node.props.name) .. '"') or ""
        local attrs = 'type="radio"' .. name .. ' value="' .. esc(option.value) .. '"' .. checked
        if node.props.disabled then
            attrs = attrs .. " disabled"
        end
        if node.handlers.onChange then
            attrs = attrs .. " " .. event_attrs(node, "change", "change", "this:queue last")
        end
        out[#out + 1] = '<label class="webui-radio"><input ' .. attrs .. "><span>"
            .. esc(option.label) .. "</span></label>"
    end
    out[#out + 1] = "</div>" .. error_html(node) .. "</div>"
    return table.concat(out)
end

renderers.list = function(node)
    local tag = node.props.ordered and "ol" or "ul"
    local out = { "<" .. tag .. ' class="webui-list" ' .. common_attrs(node) .. ">" }
    for index, item in ipairs(node.props.items or {}) do
        local attrs = ""
        if node.handlers.onSelect then
            attrs = " " .. event_attrs(node, "select", "click", TARGET .. ":queue all", { value = index })
        end
        out[#out + 1] = "<li" .. attrs .. ">" .. esc(item) .. "</li>"
    end
    out[#out + 1] = "</" .. tag .. ">"
    return table.concat(out)
end

local function row_values(node, row, index)
    local columns = node.props.columns or {}
    local out = {}
    for column_index, column in ipairs(columns) do
        if type(column) == "table" then
            out[column_index] = row[column.field or column[1] or column_index]
        else
            out[column_index] = row[column]
        end
    end
    return out
end

local function column_header(column, index)
    if type(column) == "table" then
        return column.header or column.label or column.field or column[1] or tostring(index)
    end
    return tostring(column)
end

renderers.table = function(node)
    local columns = node.props.columns or {}
    local rows = node.props.rows or {}
    local key_function = node.props.rowKey

    local out = { '<table class="webui-table" ' .. common_attrs(node) .. ">" }
    if #columns > 0 then
        out[#out + 1] = "<thead><tr>"
        for index, column in ipairs(columns) do
            out[#out + 1] = "<th>" .. esc(column_header(column, index)) .. "</th>"
        end
        out[#out + 1] = "</tr></thead>"
    end
    out[#out + 1] = "<tbody>"
    if #rows == 0 then
        out[#out + 1] = '<tr><td class="webui-muted" colspan="'
            .. tostring(math.max(#columns, 1)) .. '">' .. esc(node.props.empty or "") .. "</td></tr>"
    end
    for index, row in ipairs(rows) do
        local key = key_function and key_function(row, index) or index
        local attrs = ' data-id="' .. esc(node.id .. "-r" .. tostring(key)) .. '"'
        if node.handlers.onRowClick then
            attrs = attrs .. " " .. event_attrs(node, "rowclick", "click", TARGET .. ":queue all", {
                value = tostring(key),
            })
        end
        out[#out + 1] = "<tr" .. attrs .. ">"
        for _, value in ipairs(row_values(node, row, index)) do
            out[#out + 1] = "<td>" .. esc(value) .. "</td>"
        end
        out[#out + 1] = "</tr>"
    end
    out[#out + 1] = "</tbody></table>"
    return table.concat(out)
end

renderers.image = function(node)
    if node.props.src == nil then
        error("image requires src", 3)
    end
    local attrs = { 'class="webui-image"', 'src="' .. esc(node.props.src) .. '"' }
    if node.props.alt then
        attrs[#attrs + 1] = 'alt="' .. esc(node.props.alt) .. '"'
    end
    attrs[#attrs + 1] = common_attrs(node)
    return "<img " .. table.concat(attrs, " ") .. ">"
end

renderers.link = function(node)
    local href = node.props.href or "#"
    local attrs = {
        'class="webui-link"',
        'href="' .. esc(href) .. '"',
    }
    attrs[#attrs + 1] = common_attrs(node)
    if node.props.route then
        attrs[#attrs + 1] = 'hx-get="' .. esc(href) .. '"'
        attrs[#attrs + 1] = 'hx-target="' .. TARGET .. '"'
        attrs[#attrs + 1] = 'hx-swap="' .. SWAP .. '"'
        attrs[#attrs + 1] = 'hx-push-url="true"'
    end
    return "<a " .. table.concat(attrs, " ") .. ">" .. esc(node.props.text or "") .. "</a>"
end

renderers.markdown = function(node)
    local rendered = markdown.html(node.props.text or "")
    return '<div class="webui-markdown" ' .. common_attrs(node) .. ">" .. rendered .. "</div>"
end

renderers.html = function(node)
    return '<div class="webui-html" ' .. common_attrs(node) .. ">" .. tostring(node.props.text or "") .. "</div>"
end

renderers.divider = function(node)
    return '<hr class="webui-divider" ' .. common_attrs(node) .. ">"
end

renderers.progress = function(node)
    local attrs = { 'class="webui-progress"' }
    if node.props.max then
        attrs[#attrs + 1] = 'max="' .. esc(node.props.max) .. '"'
    end
    if not node.props.indeterminate then
        attrs[#attrs + 1] = 'value="' .. esc(node.state.value or node.props.value or 0) .. '"'
    end
    attrs[#attrs + 1] = common_attrs(node)
    return "<progress " .. table.concat(attrs, " ") .. "></progress>"
end

renderers.tabs = function(node)
    local labels = node.props.labels or {}
    local active = tonumber(node.state.value) or 1

    local out = { '<div class="webui-tabs" ' .. common_attrs(node) .. ">" }
    out[#out + 1] = '<div class="webui-tabbar" role="tablist">'
    for index = 1, math.max(#labels, #node.children) do
        local label = labels[index] or tostring(index)
        local classes = "webui-tab"
        if index == active then
            classes = classes .. " webui-tab-active"
        end
        local attrs = 'class="' .. classes .. '" data-id="' .. esc(node.id .. "-t" .. index) .. '"'
        if node.handlers.onChange then
            attrs = attrs .. " " .. event_attrs(node, "change", "click", TARGET .. ":queue all", { value = index })
        end
        out[#out + 1] = '<button type="button" ' .. attrs .. ">" .. esc(label) .. "</button>"
    end
    out[#out + 1] = "</div>"
    local child = node.children[active]
    if child then
        out[#out + 1] = '<div class="webui-tab-body">' .. M.render(child) .. "</div>"
    end
    out[#out + 1] = "</div>"
    return table.concat(out)
end

renderers.dialog = function(node)
    local attrs = { 'class="webui-dialog"' }
    if node.state.open or node.props.open then
        attrs[#attrs + 1] = "open"
    end
    attrs[#attrs + 1] = common_attrs(node)

    local out = { "<dialog " .. table.concat(attrs, " ") .. ">" }
    if node.props.title then
        out[#out + 1] = '<div class="webui-dialog-title">' .. esc(node.props.title) .. "</div>"
    end
    out[#out + 1] = children_html(node)
    if node.handlers.onClose then
        local close_attrs = event_attrs(node, "close", "click", TARGET .. ":queue all")
        out[#out + 1] = '<button type="button" class="webui-button" ' .. close_attrs .. ">"
            .. esc(node.props.closeText or "Close") .. "</button>"
    end
    out[#out + 1] = "</dialog>"
    return table.concat(out)
end

function M.render(node)
    local renderer = renderers[node.kind]
    if renderer == nil then
        if node.kind == "page" then
            return children_html(node)
        end
        error("no renderer for component '" .. tostring(node.kind) .. "'", 2)
    end
    return renderer(node)
end

--- Inner HTML of the page, without the swap wrapper.
function M.render_body(page)
    return children_html(page)
end

--- The morphed root element. Both the server side rendered document and the
-- SSE/POST fragments use exactly this markup, so idiomorph can update the
-- attributes (route/revision) together with the children.
function M.render_root(page, options)
    options = options or {}
    return table.concat {
        '<main id="webui-root" data-route="', esc(options.route or "/"),
        '" data-rev="', tostring(options.rev or 1), '"',
        ' sse-swap="html" hx-swap="', SWAP, '">',
        M.render_body(page),
        "</main>",
    }
end

local csp = table.concat({
    "default-src 'self'",
    "script-src 'self'",
    "style-src 'self' 'unsafe-inline'",
    "img-src 'self' data:",
    "connect-src 'self'",
}, "; ")

function M.render_document(page, options)
    options = options or {}
    local title = page.props.title or "webui"
    local lang = page.props.lang or "en"
    local theme = page.props.theme or "auto"
    local token = options.token or ""

    local head = {
        '<!DOCTYPE html>\n<html lang="' .. esc(lang) .. '" data-theme="' .. esc(theme) .. '">\n<head>\n',
        '<meta charset="utf-8">\n',
        '<meta name="viewport" content="width=device-width, initial-scale=1">\n',
        '<meta http-equiv="Content-Security-Policy" content="' .. csp .. '">\n',
        '<meta name="webui-token" content="' .. esc(token) .. '">\n',
        "<title>" .. esc(title) .. "</title>\n",
        '<link rel="stylesheet" href="/__webui/app.css">\n',
        '<script src="/__webui/vendor.js" defer></script>\n',
        '<script src="/__webui/app.js" defer></script>\n',
    }
    if page.props.css then
        head[#head + 1] = "<style>\n" .. tostring(page.props.css) .. "\n</style>\n"
    end
    head[#head + 1] = "</head>\n"

    return table.concat(head)
        .. '<body hx-ext="sse,morph" sse-connect="/__webui/events">\n'
        .. M.render_root(page, options)
        .. '\n<div id="webui-toasts" aria-live="polite"></div>\n'
        .. "</body>\n</html>\n"
end

return M
