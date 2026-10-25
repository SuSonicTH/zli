local lu = require 'luaunit'
lu.ORDER_ACTUAL_EXPECTED = false

local support = require "test/support"
local http = require "httpclient"
local webserver = require "webserver"

Test_webserver = {}

local TOKEN = "testtoken"

local function home()
    return support.temp_dir("webhome")
end

local function server_source(options)
    options = options or {}
    return ([[
local web = require "webserver"

web.asset_set("webui/extra.txt", "extra asset", "text/plain; charset=utf-8")

web.serve {
    port = 0,
    token = %q,
    stop_path = "/__stop",
    assets_dir = %s,
    on_start = function(info) print(info.url) end,
    routes = {
        GET = {
            ["/"] = "hello",
            ["/json"] = function() return { ok = true } end,
            ["/push"] = function()
                local web = require "webserver"
                local count = web.broadcast("html", "pushed")
                return {
                    status = 200,
                    body = tostring(count),
                    header = { content_type = "text/plain" },
                }
            end,
            ["/late-asset"] = function()
                local ok, message = web.asset_set("webui/late.txt", "late")
                return {
                    status = 200,
                    body = tostring(ok) .. ":" .. tostring(message),
                    header = { content_type = "text/plain" },
                }
            end,
            ["/typed"] = function()
                return { status = 201, body = "typed", header = { content_type = "text/plain" } }
            end,
        },
        POST = {
            ["/echo"] = function(request)
                return { status = 201, body = request.body, header = { content_type = "text/plain" } }
            end,
        },
    },
}
print("done")
]]):format(TOKEN, options.assets_dir and string.format("%q", options.assets_dir) or "nil")
end

--- Start the test server, run `fn(url, request)`, then stop it and assert a
-- clean exit.
local function with_server(fn, options)
    options = options or {}
    local script = support.temp_file("webserver", server_source(options))
    local handle = support.spawn({ script }, { home = home() })
    local url = handle.line

    if url == nil then
        local rest, code = support.spawn_finish(handle)
        error("server did not start, exit " .. tostring(code) .. ": " .. rest)
    end

    local function request(method, path, body, headers)
        return http.call(method, url .. (path:gsub("^/", "")), { header = headers or {} }, body)
    end

    local ok, err = pcall(fn, url, request)
    -- Always stop the child, even when an assertion failed.
    pcall(request, "POST", "/__stop", nil, { cookie = "webui_session=" .. TOKEN })
    local rest, code = support.spawn_finish(handle)
    if not ok then
        error(err, 0)
    end
    lu.assertEquals(0, code, "server exit status: " .. rest)
    lu.assertStrContains(rest, "done")
end

function Test_webserver:Test_get_routes()
    with_server(function(_, request)
        local response, body = request("GET", "/")
        lu.assertEquals(200, response.status)
        lu.assertEquals("hello", body)
        lu.assertEquals("text/html; charset=utf-8", response.content_type)

        local json, json_body = request("GET", "/json")
        lu.assertEquals(200, json.status)
        lu.assertEquals("application/json", json.content_type)
        lu.assertEquals(true, require("cjson").decode(json_body).ok)

        local typed, typed_body = request("GET", "/typed")
        lu.assertEquals(201, typed.status)
        lu.assertEquals("typed", typed_body)
        lu.assertEquals("text/plain", typed.content_type)

        local missing = request("GET", "/missing")
        lu.assertEquals(404, missing.status)
    end)
end

function Test_webserver:Test_post_requires_the_session_cookie()
    with_server(function(_, request)
        local response = request("POST", "/echo", "payload")
        lu.assertEquals(403, response.status)

        local with_cookie, body = request("POST", "/echo", "payload", { cookie = "webui_session=" .. TOKEN })
        lu.assertEquals(201, with_cookie.status)
        lu.assertEquals("payload", body)
    end)
end

function Test_webserver:Test_origin_is_checked()
    with_server(function(url, request)
        local port = url:match(":(%d+)/$")
        local cookie = { cookie = "webui_session=" .. TOKEN }

        local bad = request("POST", "/echo", "x", {
            cookie = cookie.cookie,
            origin = "http://evil.example",
        })
        lu.assertEquals(403, bad.status)

        local good = request("POST", "/echo", "x", {
            cookie = cookie.cookie,
            origin = "http://127.0.0.1:" .. port,
        })
        lu.assertEquals(201, good.status)

        local localhost = request("POST", "/echo", "x", {
            cookie = cookie.cookie,
            origin = "http://localhost:" .. port,
        })
        lu.assertEquals(201, localhost.status)
    end)
end

function Test_webserver:Test_assets_and_etag()
    with_server(function(_, request)
        local runtime, runtime_body = request("GET", "/__webui/extra.txt")
        lu.assertEquals(200, runtime.status)
        lu.assertEquals("extra asset", runtime_body)

        local css, css_body = request("GET", "/__webui/app.css")
        lu.assertEquals(200, css.status)
        lu.assertEquals("text/css; charset=utf-8", css.content_type)
        lu.assertNotEquals(0, #css_body)

        local vendor, vendor_body = request("GET", "/__webui/vendor.js")
        lu.assertEquals(200, vendor.status)
        lu.assertEquals("text/javascript; charset=utf-8", vendor.content_type)
        lu.assertStrContains(vendor_body, "webui vendor bundle")

        -- A conditional request must not transfer the body again.
        local cached, cached_body = request("GET", "/__webui/app.css", nil, { ["if-none-match"] = "*" })
        lu.assertEquals(304, cached.status)
        lu.assertEquals("", cached_body)
    end)
end

function Test_webserver:Test_assets_dir_overrides_embedded_assets()
    local dir = support.temp_dir("webassets")
    require("filesystem").create_tree(dir .. "/webui")
    io.write_file(dir .. "/webui/app.css", "/* override */")

    with_server(function(_, request)
        local response, body = request("GET", "/__webui/app.css")
        lu.assertEquals(200, response.status)
        lu.assertEquals("/* override */", body)
    end, { assets_dir = dir })
end

function Test_webserver:Test_asset_lookup_reports_the_source()
    local data, content_type, source = webserver.asset("webui/app.css")
    lu.assertStrContains(data, "--webui-accent")
    lu.assertEquals("text/css; charset=utf-8", content_type)
    lu.assertEquals("embedded", source)

    local payload, payload_type, payload_source = webserver.asset("docs.lua")
    lu.assertStrContains(payload, "return")
    lu.assertEquals("application/octet-stream", payload_type)
    lu.assertEquals("payload", payload_source)

    lu.assertNil(webserver.asset("webui/does-not-exist.js"))
end

function Test_webserver:Test_asset_set_cannot_change_assets_while_serving()
    with_server(function(_, request)
        local response, body = request("GET", "/late-asset")
        lu.assertEquals(200, response.status)
        lu.assertEquals("nil:", body:sub(1, 4))
        lu.assertStrContains(body, "cannot change assets while serving")
    end)
end

function Test_webserver:Test_sse_once_streams_one_event_and_closes()
    with_server(function(_, request)
        local response, body = request("GET", "/__webui/events?once=1&push=hello", nil, {
            cookie = "webui_session=" .. TOKEN,
        })
        lu.assertEquals(200, response.status)
        lu.assertEquals("text/event-stream", response.content_type)
        lu.assertEquals("event: html\ndata: hello\n\n", body)
    end)
end

function Test_webserver:Test_sse_requires_the_session_cookie()
    with_server(function(_, request)
        local response = request("GET", "/__webui/events?once=1&push=hello")
        lu.assertEquals(403, response.status)
    end)
end

function Test_webserver:Test_broadcast_reports_the_number_of_clients()
    with_server(function(_, request)
        local response, body = request("GET", "/push")
        lu.assertEquals(200, response.status)
        lu.assertEquals("0", body)
    end)
end

function Test_webserver:Test_stop_path_only_listens_to_post()
    with_server(function(_, request)
        local get = request("GET", "/__stop")
        lu.assertEquals(404, get.status)

        local response, body = request("POST", "/__stop", nil, { cookie = "webui_session=" .. TOKEN })
        lu.assertEquals(200, response.status)
        lu.assertEquals("stopping", body)
    end)
end

function Test_webserver:Test_serve_validates_options()
    lu.assertError(function()
        webserver.serve {}
    end)

    local result, message = webserver.serve { routes = {}, address = "0.0.0.0" }
    lu.assertNil(result)
    lu.assertStrContains(tostring(message), "allow_remote")

    lu.assertNil(webserver.info())
    lu.assertEquals(0, #webserver.clients())
end

function Test_webserver:Test_status_constants()
    lu.assertEquals(200, webserver.status.ok)
    lu.assertEquals(404, webserver.status.not_found)
    lu.assertEquals(500, webserver.status.internal_server_error)
    lu.assertEquals(403, webserver.status["forbidden"])
end

if not RUN_ALL then
    os.exit(lu.LuaUnit.run('-v'))
end
