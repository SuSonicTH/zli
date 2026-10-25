-- Routing and response helpers for the native `webserver` binding.
--
-- The native side owns the socket, keep-alive, assets, limits and shutdown.
-- Requests that are not served by an asset are handed to `dispatch`, which is
-- implemented here: a route table, or a custom handler.

local json = require "cjson"

local status = {
    ok = 200,
    created = 201,
    accepted = 202,
    no_content = 204,
    moved_permanently = 301,
    found = 302,
    not_modified = 304,
    bad_request = 400,
    unauthorized = 401,
    forbidden = 403,
    not_found = 404,
    method_not_allowed = 405,
    conflict = 409,
    payload_too_large = 413,
    unsupported_media_type = 415,
    unprocessable_content = 422,
    too_many_requests = 429,
    internal_server_error = 500,
    not_implemented = 501,
    bad_gateway = 502,
    service_unavailable = 503,
    gateway_timeout = 504,
}

setmetatable(status, {
    __index = function(tbl, key)
        if type(key) == "string" then
            return rawget(tbl, key:lower())
        end
    end,
})

local function match_path(paths, target)
    for path, content in pairs(paths) do
        local match = target:match(path)
        if match and #match == #target then
            return content
        end
    end
end

local function find_route(routes, method, request)
    for _, paths in ipairs { routes[method] or {}, routes["*"] or {} } do
        local content = paths[request.path] or match_path(paths, request.path)
        if content ~= nil then
            return content
        end
    end
end

local function normalize(response)
    local kind = type(response)
    if kind == "string" then
        return {
            status = status.ok,
            body = response,
            header = { content_type = "text/html; charset=utf-8" },
        }
    end
    if kind ~= "table" then
        return { status = status.internal_server_error, body = "no response" }
    end
    if response.body ~= nil and response.header == nil then
        return {
            status = response.status or status.ok,
            body = tostring(response.body),
            header = { content_type = "text/html; charset=utf-8" },
        }
    end
    if response.body == nil and response.status == nil and response.header == nil then
        return {
            status = status.ok,
            body = json.encode(response),
            header = { content_type = "application/json" },
        }
    end
    return response
end

local function dispatch_for(options)
    if options.handler then
        return function(request)
            return normalize(options.handler(request))
        end
    end

    local routes = options.routes
    if routes == nil then
        return function()
            return { status = status.not_found, body = "not found" }
        end
    end

    return function(request)
        local route = find_route(routes, request.method, request)
        if route == nil then
            return { status = status.not_found, body = "not found" }
        end
        if type(route) == "function" then
            return normalize(route(request))
        end
        return normalize(route)
    end
end

local native_serve

local function serve(options)
    arg_check("webserver.serve", 1, type(options) == "table", "expecting a table with server options")
    arg_check("webserver.serve", 1, type(options.routes) == "table" or type(options.handler) == "function",
        "expecting options.routes or options.handler")

    options.dispatch = dispatch_for(options)
    return native_serve(options, options.on_start)
end

return function(webserver)
    native_serve = webserver.serve
    webserver.status = status
    webserver.serve = serve
end
