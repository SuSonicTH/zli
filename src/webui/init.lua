-- Public API of the web UI library.
--
-- A page is a component tree. Components are created with `ui.<kind>{...}`,
-- can be nested either in the table constructor or with `parent:add(...)`, and
-- are addressed from event callbacks through `ui.current.<name>`.

local component = require "webui.component"

local ui = {}

local active_page = nil

local factories = {
    "page",
    "verticalLayout",
    "horizontalLayout",
    "panel",
    "label",
    "heading",
    "button",
    "textField",
    "textArea",
    "checkbox",
    "select",
    "radioGroup",
    "list",
    "table",
    "image",
    "link",
    "markdown",
    "html",
    "divider",
    "progress",
    "tabs",
    "dialog",
}

for _, kind in ipairs(factories) do
    ui[kind] = function(options, ...)
        return component.create(kind, options, ...)
    end
end

ui.card = ui.panel

--- The page whose callback is currently running. Set by the dispatcher.
function ui.activate(page)
    active_page = page
    return page
end

function ui.page_now()
    return active_page
end

local function require_page(name)
    if active_page == nil then
        error(name .. " is only available while serving a page", 3)
    end
    return active_page
end

-- `ui.current.user` resolves the name in the active page. Names are unique per
-- page, so routes cannot shadow each other.
ui.current = setmetatable({}, {
    __index = function(_, name)
        local page = require_page("ui.current")
        local node = component.named(page, name)
        if node == nil then
            error("no component named '" .. tostring(name) .. "' on this page", 2)
        end
        return node
    end,
})

--- Append a dialog to the page and open it.
function ui.open(dialog)
    local page = require_page("ui.open")
    dialog.state.open = true
    page:add(dialog)
    return dialog
end

--- Non blocking notification. Sent to every connected browser after the
-- callback returns.
function ui.notify(text, options)
    local page = require_page("ui.notify")
    options = options or {}
    page.toasts = page.toasts or {}
    page.toasts[#page.toasts + 1] = {
        kind = options.kind or "info",
        text = tostring(text),
        ms = options.ms or 3000,
    }
end

--- Dialog with two buttons; never blocks the server.
function ui.confirm(options)
    options = options or {}
    local page = require_page("ui.confirm")

    local dialog
    dialog = ui.open(ui.dialog {
        title = options.title,
        closeText = options.no or "No",
        onClose = function()
            dialog:close()
            if options.onNo then
                options.onNo(dialog)
            end
        end,
    })
    dialog:add(ui.label { text = options.text or "" })
    dialog:add(ui.horizontalLayout {
        align = "horizontal",
        ui.button {
            text = options.yes or "Yes",
            onClick = function()
                dialog:close()
                if options.onYes then
                    options.onYes(dialog)
                end
            end,
        },
    })
    return dialog
end

function ui.close(dialog)
    if dialog and dialog.close then
        dialog:close()
    end
end

--- Ask the browser to focus a component after the next update.
function ui.focus(node)
    local page = require_page("ui.focus")
    page.pending_focus = node.id
end

--- Navigate the browser to another route.
function ui.navigate(path)
    local page = require_page("ui.navigate")
    page.pending_navigate = path
end

--- Force a re-render even when the callback did not touch the tree.
function ui.refresh()
    local page = require_page("ui.refresh")
    page.dirty = true
end

function ui.stop()
    require("webserver").stop()
end

ui.component = component

return ui
