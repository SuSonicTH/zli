-- Public API of the web UI library.
--
-- A page is a component tree. Components are created with `ui.<kind>{...}`,
-- can be nested either in the table constructor or with `parent:add(...)`, and
-- are addressed from event callbacks through `ui.current.<name>`.

local component = require "webui.component"
local render = require "webui.html"
local events = require "webui.event"
local json = require "cjson"

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

-- serving ------------------------------------------------------------------

local function open_browser(url)
    if os.is_windows then
        os.execute('start "" ' .. url)
    elseif os.is_linux then
        os.execute("xdg-open " .. url .. " >/dev/null 2>&1 &")
    elseif tostring(os.name):find("mac") then
        os.execute("open " .. url .. " >/dev/null 2>&1 &")
    end
end

local function normalize(response)
    if type(response) == "string" then
        return { status = 200, body = response, header = { content_type = "text/plain; charset=utf-8" } }
    end
    if type(response) == "table" then
        return response
    end
    return { status = 500, body = "no response" }
end

local function route_lookup(routes, path)
    local exact = routes[path]
    if exact ~= nil then
        return exact
    end
    for pattern, value in pairs(routes) do
        local match = path:match(pattern)
        if match and #match == #path then
            return value
        end
    end
    return nil
end

--- Serve one page (`page = ...`) or several routes (`pages = { ["/"] = ... }`).
-- Blocks until `ui.stop()` is called.
function ui.serve(options)
    options = options or {}
    local web = require "webserver"

    local pages = {}
    if options.page then
        pages["/"] = options.page
    end
    for path, page in pairs(options.pages or {}) do
        pages[path] = page
    end
    if next(pages) == nil then
        error("ui.serve requires 'page' or 'pages'", 2)
    end
    for path, page in pairs(pages) do
        if type(path) ~= "string" or path:sub(1, 1) ~= "/" then
            error("ui.serve: page routes have to start with '/', got '" .. tostring(path) .. "'", 2)
        end
        if type(page) ~= "table" or page.kind ~= "page" then
            error("ui.serve: route '" .. path .. "' is not a page", 2)
        end
        page._rev = 0
        page._root = render.render_root(page, { route = path, rev = 0 })
    end

    local api = options.api or {}
    local revision = 0

    local function bump_and_broadcast()
        for path, page in pairs(pages) do
            local root = render.render_root(page, { route = path, rev = page._rev })
            local forced = page.dirty == true
            page.dirty = nil
            if forced or root ~= page._root then
                revision = revision + 1
                page._rev = revision
                page._root = render.render_root(page, { route = path, rev = page._rev })
                web.broadcast("html", page._root)
            end
        end
    end

    local function fragment(page, route, err)
        local triggers = {}
        if err then
            triggers["webui:error"] = { text = err }
        end

        local toasts = page.toasts
        page.toasts = nil
        if toasts and #toasts > 0 then
            triggers["webui:toasts"] = toasts
        end
        if page.pending_focus then
            triggers["webui:focus"] = { id = page.pending_focus }
            page.pending_focus = nil
        end
        local navigate = page.pending_navigate
        page.pending_navigate = nil

        local target_page, target_route = page, route
        if navigate then
            if pages[navigate] == nil then
                triggers["webui:error"] = { text = "unknown route '" .. tostring(navigate) .. "'" }
                navigate = nil
            else
                target_page, target_route = pages[navigate], navigate
            end
        end

        bump_and_broadcast()

        local header = {
            content_type = "text/html; charset=utf-8",
            ["cache-control"] = "no-store",
        }
        if next(triggers) ~= nil then
            header["hx-trigger"] = json.encode(triggers)
        end
        if navigate then
            header["hx-push-url"] = navigate
        end

        return {
            status = 200,
            body = target_page._root
                or render.render_root(target_page, { route = target_route, rev = target_page._rev }),
            header = header,
        }
    end

    local function handle_event(request)
        local params = events.parse_form(request.body)
        local node, route, page = events.find(pages, params.id)
        if node == nil then
            -- a stale id (for example a double click on a button that removed
            -- itself) must not morph the page to an empty body
            return {
                status = 204,
                header = { content_type = "text/html; charset=utf-8" },
            }
        end

        ui.activate(page)
        events.apply_values(page, params)

        local err = events.call(page, node, params, request.client)
        local body = fragment(page, route, err)
        if err then
            io.stderr:write("webui: " .. err .. "\n")
        end
        return body
    end

    local function dispatch(request)
        local path = request.path
        local method = request.method

        if path == "/__webui/event" and method == "POST" then
            return handle_event(request)
        end

        local api_routes = api[method]
        if api_routes then
            local route = route_lookup(api_routes, path)
            if route then
                if type(route) == "function" then
                    return normalize(route(request))
                end
                return normalize(route)
            end
        end

        if method == "GET" or method == "HEAD" then
            local page = pages[path]
            if page == nil then
                return { status = 404, body = "not found", header = { content_type = "text/plain; charset=utf-8" } }
            end
            local info = web.info()
            if request.headers["hx-request"] then
                return {
                    status = 200,
                    body = render.render_root(page, { route = path, rev = page._rev }),
                    header = { content_type = "text/html; charset=utf-8", ["cache-control"] = "no-store" },
                }
            end
            return {
                status = 200,
                body = render.render_document(page, {
                    token = info and info.token or "",
                    route = path,
                    rev = page._rev,
                }),
                header = { content_type = "text/html; charset=utf-8", ["cache-control"] = "no-store" },
            }
        end

        return { status = 405, body = "method not allowed", header = { content_type = "text/plain; charset=utf-8" } }
    end

    local function on_start(info)
        print("webui: " .. info.url)
        if options.open_browser ~= false then
            open_browser(info.url)
        end
        if options.on_start then
            options.on_start(info)
        end
    end

    return web.serve {
        address = options.address,
        port = options.port,
        allow_remote = options.allow_remote,
        assets_dir = options.assets_dir,
        stop_path = options.stop_path,
        warn_ms = options.warn_ms,
        token = options.token,
        on_start = on_start,
        handler = dispatch,
    }
end

ui.component = component

return ui
