local lu = require 'luaunit'
lu.ORDER_ACTUAL_EXPECTED = false

local ui = require "webui"
local render = require "webui.html"
local component = require "webui.component"
local support = require "test/support"
local http = require "httpclient"

Test_webui = {}

local function new_page()
    local page = ui.page { title = "test" }
    ui.activate(page)
    return page
end

function Test_webui:Test_construction_forms()
    local page = new_page()

    local input = ui.horizontalLayout()
    page:add(input)
    input:add(
        ui.label { text = "User Name" },
        ui.textField { name = "user", value = "world" },
        ui.button("Say hello")
    )

    lu.assertEquals(3, #input.children)
    lu.assertEquals("Say hello", input.children[3].props.text)
    lu.assertIs(input, page.children[1])

    local nested = ui.horizontalLayout {
        ui.label "a",
        ui.button "b",
    }
    lu.assertEquals(2, #nested.children)
    lu.assertEquals("a", nested.children[1].props.text)
    lu.assertEquals("b", nested.children[2].props.text)

    -- add returns the parent so calls can be chained
    local added = page:add(ui.divider()) and true
    lu.assertTrue(added)
end

function Test_webui:Test_unknown_props_raise()
    new_page()
    lu.assertError(function()
        ui.button { text = "x", onCLick = function() end }
    end)
    lu.assertError(function()
        ui.label { text = "x", nope = 1 }
    end)
    lu.assertError(function()
        ui.button { text = "x", onClick = "not a function" }
    end)
    lu.assertError(function()
        ui.image {}
    end)
    lu.assertEquals("/x.png", ui.image { src = "/x.png" }.props.src)
end

function Test_webui:Test_value_and_text_are_separate()
    new_page()
    local label = ui.label { text = "hello" }
    local input = ui.textField { name = "user", value = "world" }

    lu.assertEquals("hello", label:text())
    lu.assertNil(label:value())
    lu.assertEquals("world", input:value())
    lu.assertNil(input:text())

    input:setValue("again")
    lu.assertEquals("again", input:value())
    input:setText("ignored")
    lu.assertEquals("ignored", input:text())
    lu.assertEquals("again", input:value())
end

function Test_webui:Test_names_are_unique_per_page()
    local page = new_page()
    page:add(ui.textField { name = "user" })
    page:add(ui.textField { name = "user" })
    lu.assertError(function()
        component.index(page)
    end)

    local other = ui.page {}
    ui.activate(other)
    other:add(ui.textField { name = "user" })
    local count = 0
    for _ in pairs(component.index(other)) do
        count = count + 1
    end
    lu.assertEquals(1, count)
end

function Test_webui:Test_current_resolves_named_components()
    ui.activate(nil)
    lu.assertError(function()
        return ui.current.user
    end)

    local page = new_page()
    page:add(ui.textField { name = "user", value = "world" })
    page:add(ui.button { text = "go", name = "goButton" })

    lu.assertEquals("world", ui.current.user:value())
    lu.assertIs(page.children[2], ui.current.goButton)

    lu.assertError(function()
        return ui.current.missing
    end)

    page:add(ui.label { name = "id" })
    lu.assertError(function()
        return component.index(page)
    end)
end

function Test_webui:Test_text_and_attributes_are_escaped()
    new_page()
    local page = ui.page { title = '"><script>alert(1)</script>' }
    page:add(ui.label { text = "<b>&\"'</b>" })
    page:add(ui.link { text = "x", href = 'javascript:"x"' })

    local body = render.render_body(page)
    lu.assertNotStrContains(body, "<b>")
    lu.assertStrContains(body, "&lt;b&gt;&amp;&quot;&#39;&lt;/b&gt;")
    lu.assertStrContains(body, "href=\"javascript:&quot;x&quot;\"")

    local document = render.render_document(page, {})
    lu.assertNotStrContains(document, "<script>alert(1)</script>")
    lu.assertStrContains(document, "&lt;script&gt;alert(1)&lt;/script&gt;")
end

function Test_webui:Test_htmx_attributes()
    new_page()
    local page = ui.page {}
    page:add(ui.textField { name = "user", onInput = function() end })
    page:add(ui.button { text = "go", onClick = function() end })
    page:add(ui.checkbox { name = "check", onChange = function() end })
    page:add(ui.select { name = "choice", options = { "a" }, onChange = function() end })

    local body = render.render_body(page)

    -- inputs queue last, clicks queue all
    lu.assertStrContains(body, 'hx-sync="this:queue last"')
    lu.assertStrContains(body, 'hx-sync="#webui-root:queue all"')

    -- inputs let the client derive the kind from the trigger
    lu.assertStrContains(body, 'data-webui-trigger-kind="1"')
    lu.assertStrContains(body, "hx-trigger=\"input changed delay:120ms, change\"")

    -- clicks send a fixed kind
    lu.assertStrContains(body, '"kind":"click"')
    lu.assertStrContains(body, '"kind":"change"')

    -- no inline handlers, no javascript: URLs, no eval based htmx features
    lu.assertNotStrContains(body, "hx-on")
    lu.assertNotStrContains(body, "js:")
    lu.assertNotStrContains(body, "<script")
end

function Test_webui:Test_root_carries_route_and_revision()
    new_page()
    local page = ui.page { title = "x" }
    page:add(ui.label { text = "hi" })

    local root = render.render_root(page, { route = "/b", rev = 7 })
    lu.assertStrContains(root, 'id="webui-root"')
    lu.assertStrContains(root, 'data-route="/b"')
    lu.assertStrContains(root, 'data-rev="7"')
    lu.assertStrContains(root, 'sse-swap="html"')
    lu.assertStrContains(root, 'hx-swap="morph:outerHTML"')

    local document = render.render_document(page, { token = "t0k", route = "/b", rev = 7 })
    lu.assertStrContains(document, 'sse-connect="/__webui/events"')
    lu.assertStrContains(document, 'name="webui-token" content="t0k"')
    lu.assertStrContains(document, "default-src 'self'")
    lu.assertStrContains(document, "/__webui/vendor.js")
    lu.assertStrContains(document, "/__webui/app.js")
    lu.assertStrContains(document, "/__webui/app.css")
end

function Test_webui:Test_ids_are_stable_across_renders()
    new_page()
    local page = ui.page {}
    local button = ui.button { text = "go", onClick = function() end }
    page:add(button)

    local first = render.render_body(page)
    local second = render.render_body(page)
    lu.assertEquals(first, second)
    lu.assertStrContains(first, 'data-id="' .. button.id .. '"')

    -- rendering must not consume ids
    local before = button.id
    render.render_body(page)
    lu.assertEquals(before, button.id)
end

function Test_webui:Test_user_classes_are_merged()
    new_page()
    local page = ui.page {}
    page:add(ui.label { text = "x", class = "custom" })
    page:add(ui.button { text = "go", class = "primary", onClick = function() end })
    page:add(ui.textField { name = "user", class = "wide" })

    local body = render.render_body(page)
    lu.assertStrContains(body, 'class="webui-label custom"')
    lu.assertStrContains(body, 'class="webui-button primary"')
    lu.assertStrContains(body, 'class="webui-input wide"')
    lu.assertNil(body:find('class="webui-label" data%-id[^>]*class=', 1))

    -- malformed class names still raise
    lu.assertError(function()
        render.render_body(ui.page { ui.label { text = "x", class = 'bad"name' } })
    end)
end

function Test_webui:Test_styles_are_validated()
    new_page()
    local page = ui.page {}
    page:add(ui.label { text = "x", style = { color = "red" }, width = 50, grow = 1 })
    local body = render.render_body(page)
    lu.assertStrContains(body, "width:50px")
    lu.assertStrContains(body, "flex:1")
    lu.assertStrContains(body, "color:red")

    lu.assertError(function()
        render.render_body(ui.page { ui.label { text = "x", style = { ["bad name"] = "red" } } })
    end)
    lu.assertError(function()
        render.render_body(ui.page { ui.label { text = "x", style = { color = "red;background:url(x)" } } })
    end)
end

function Test_webui:Test_components_render()
    new_page()
    local page = ui.page {}
    page:add(ui.heading { text = "Title", level = 1 })
    page:add(ui.progress { value = 5, max = 10 })
    page:add(ui.divider())
    page:add(ui.image { src = "/x.png", alt = "x" })
    page:add(ui.markdown { text = "# hi" })
    page:add(ui.html { text = "<em>raw</em>" })
    page:add(ui.panel { title = "card", ui.label { text = "inside" } })
    page:add(ui.list { items = { "one", "two" } })
    page:add(ui.radioGroup { name = "r", options = { "a", "b" }, value = "b", onChange = function() end })
    page:add(ui.tabs { labels = { "one", "two" }, ui.label { text = "first" }, ui.label { text = "second" } })

    local body = render.render_body(page)
    lu.assertStrContains(body, '<h1 data-id=')
    lu.assertStrContains(body, 'class="webui-heading">Title</h1>')
    lu.assertStrContains(body, '<progress max="10" value="5"')
    lu.assertStrContains(body, 'class="webui-progress"')
    lu.assertStrContains(body, '<hr data-id=')
    lu.assertStrContains(body, 'class="webui-divider"')
    lu.assertStrContains(body, 'src="/x.png"')
    lu.assertStrContains(body, "<h1>hi</h1>")
    lu.assertStrContains(body, "<em>raw</em>")
    lu.assertStrContains(body, "webui-panel-title")
    lu.assertStrContains(body, "<li>one</li>")
    lu.assertStrContains(body, 'value="b" checked')
    lu.assertStrContains(body, "webui-tab-active")
    lu.assertStrContains(body, "first")
end

function Test_webui:Test_dialogs_and_notifications()
    local page = new_page()
    local dialog = ui.open(ui.dialog {
        title = "Confirm",
        ui.label { text = "sure?" },
        onClose = function() end,
    })
    lu.assertTrue(dialog:isOpen())
    lu.assertIs(page.children[#page.children], dialog)

    local answered = false
    local confirm = ui.confirm {
        text = "delete?",
        onYes = function()
            answered = true
        end,
    }
    confirm:close()
    -- the second child of the confirm dialog is the button row
    confirm.children[2].children[1].handlers.onClick(confirm.children[2].children[1], { kind = "click" })
    lu.assertTrue(answered)
    lu.assertFalse(confirm:isOpen())

    ui.notify("hello", { kind = "warn", ms = 1000 })
    lu.assertEquals(1, #page.toasts)
    lu.assertEquals("warn", page.toasts[1].kind)
    lu.assertEquals("hello", page.toasts[1].text)

    ui.focus(page.children[1])
    lu.assertEquals(page.children[1].id, page.pending_focus)

    ui.navigate("/b")
    lu.assertEquals("/b", page.pending_navigate)
end

function Test_webui:Test_bad_component_shapes_raise()
    new_page()
    lu.assertError(function()
        ui.verticalLayout():add("not a component")
    end)
    lu.assertError(function()
        ui.verticalLayout():add(nil)
    end)
    lu.assertError(function()
        render.render_body(ui.page { ui.heading { text = "x", level = 9 } })
    end)
end

function Test_webui:Test_component_index_helper()
    local page = ui.page {}
    page:add(ui.verticalLayout { ui.textField { name = "a" }, ui.textField { name = "b" } })
    local names = component.index(page)
    lu.assertEquals(2, (function()
        local count = 0
        for _ in pairs(names) do
            count = count + 1
        end
        return count
    end)())
    lu.assertEquals("textField", names.a.kind)
end

-- ---------------------------------------------------------------------------
-- integration with the real server
-- ---------------------------------------------------------------------------

local TOKEN = "webtoken"

local function page_source()
    return ([[
local ui = require "webui"

local page = ui.page { title = "Hello <World>" }
local echo = ui.label { text = "" }
local field = ui.textField {
    name = "user", value = "world",
    onChange = function(src) echo:setText("saw:" .. tostring(src:value())) end,
}
local button = ui.button {
    text = "Say hello",
    onClick = function()
        ui.current.user:setValue("clicked")
        ui.notify("hello " .. tostring(ui.current.user:value()))
    end,
}
local broken = ui.button { text = "Broken", onClick = function() error("boom") end }
local go = ui.button { text = "Go B", onClick = function() ui.navigate("/b") end }

page:add(ui.horizontalLayout {
    ui.label { text = "User Name" }, field, echo, button, broken, go,
})
page:add(ui.textField { name = "locked", value = "keep", disabled = true })

local second = ui.page { title = "Second" }
second:add(ui.label { text = "this is B" })

ui.serve {
    pages = { ["/"] = page, ["/b"] = second },
    api = { GET = { ["/api"] = function() return { ok = true } end } },
    port = 0,
    token = %q,
    stop_path = "/__stop",
    open_browser = false,
    on_start = function(info)
        print(info.url, button.id, broken.id, go.id, field.id)
    end,
}
print("done")
]]):format(TOKEN)
end

--- Start the demo page and run `fn(url, ids)` against it, then stop it.
local function with_page(fn)
    local script = support.temp_file("webui_page", page_source())
    local handle = support.spawn({ script }, { home = support.temp_dir("webhome") })

    if handle.line == nil then
        local rest, code = support.spawn_finish(handle)
        error("page did not start, exit " .. tostring(code) .. ": " .. rest)
    end
    local line = handle.pipe:read("*l") or ""
    local url, button, broken, go, field = line:match("^(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(%S+)$")
    if url == nil then
        support.spawn_finish(handle)
        error("unexpected ready line: " .. line)
    end

    local function request(method, path, body, headers)
        return http.call(method, url .. (path:gsub("^/", "")), { header = headers or {} }, body)
    end

    local ids = { button = button, broken = broken, go = go, field = field }
    local ok, err = pcall(fn, url, ids, request)
    pcall(request, "POST", "/__stop", nil, { cookie = "webui_session=" .. TOKEN })
    local rest, code = support.spawn_finish(handle)
    if not ok then
        error(err, 0)
    end
    lu.assertEquals(0, code, "server exit status: " .. rest)
    lu.assertStrContains(rest, "done")
end

function Test_webui:Test_serve_renders_the_document()
    with_page(function(_, _, request)
        local response, body = request("GET", "/")
        lu.assertEquals(200, response.status)
        lu.assertStrContains(body, "<title>Hello &lt;World&gt;</title>")
        lu.assertStrContains(body, 'id="webui-root"')
        lu.assertStrContains(body, 'sse-connect="/__webui/events"')
        lu.assertStrContains(body, "Content-Security-Policy")
        lu.assertStrContains(body, 'name="webui-token" content="' .. TOKEN .. '"')

        local fragment, fragment_body = request("GET", "/", nil, { ["hx-request"] = "true" })
        lu.assertEquals(200, fragment.status)
        lu.assertEquals("<main", fragment_body:sub(1, 5))
        lu.assertNotStrContains(fragment_body, "<!DOCTYPE")

        local missing = request("GET", "/nope")
        lu.assertEquals(404, missing.status)

        local api, api_body = request("GET", "/api")
        lu.assertEquals(200, api.status)
        lu.assertEquals(true, require("cjson").decode(api_body).ok)

        local second, second_body = request("GET", "/b")
        lu.assertEquals(200, second.status)
        lu.assertStrContains(second_body, "this is B")
    end)
end

function Test_webui:Test_event_runs_callbacks_and_syncs_values()
    with_page(function(_, ids, request)
        local response, body = request("POST", "/__webui/event",
            "id=" .. ids.button .. "&kind=click&user=alice",
            { cookie = "webui_session=" .. TOKEN })

        lu.assertEquals(200, response.status)
        lu.assertStrContains(body, 'value="clicked"')
        lu.assertStrContains(body, 'data-route="/"')

        -- input events apply the submitted value before any callback runs
        local input, input_body = request("POST", "/__webui/event",
            "id=" .. ids.field .. "&kind=input&user=bob",
            { cookie = "webui_session=" .. TOKEN })
        lu.assertEquals(200, input.status)
        lu.assertStrContains(input_body, 'value="bob"')

        -- commit runs onChange, which rewrites the label text
        local change, change_body = request("POST", "/__webui/event",
            "id=" .. ids.field .. "&kind=change&user=bob",
            { cookie = "webui_session=" .. TOKEN })
        lu.assertEquals(200, change.status)
        lu.assertStrContains(change_body, "saw:bob")
    end)
end

function Test_webui:Test_event_requires_the_session_cookie()
    with_page(function(_, ids, request)
        local response = request("POST", "/__webui/event", "id=" .. ids.button .. "&kind=click")
        lu.assertEquals(403, response.status)
    end)
end

function Test_webui:Test_callback_errors_keep_the_server_working()
    with_page(function(_, ids, request)
        local response, body = request("POST", "/__webui/event",
            "id=" .. ids.broken .. "&kind=click",
            { cookie = "webui_session=" .. TOKEN })
        lu.assertEquals(200, response.status)
        lu.assertStrContains(body, 'id="webui-root"')

        -- the server is still alive and serving
        local alive = request("GET", "/")
        lu.assertEquals(200, alive.status)
    end)
end

function Test_webui:Test_stale_event_id_is_not_swapped()
    with_page(function(_, _, request)
        local response, body = request("POST", "/__webui/event", "id=c999999&kind=click", {
            cookie = "webui_session=" .. TOKEN,
        })
        lu.assertEquals(204, response.status)
        lu.assertEquals("", body)
    end)
end

function Test_webui:Test_disabled_fields_keep_their_value()
    with_page(function(_, ids, request)
        -- the browser does not submit disabled controls; the server must not
        -- clear their value on an unrelated event
        local response, body = request("POST", "/__webui/event",
            "id=" .. ids.button .. "&kind=click&user=alice",
            { cookie = "webui_session=" .. TOKEN })
        lu.assertEquals(200, response.status)
        lu.assertStrContains(body, 'value="keep"')
    end)
end

function Test_webui:Test_navigate_switches_the_page()
    with_page(function(_, ids, request)
        local response, body = request("POST", "/__webui/event",
            "id=" .. ids.go .. "&kind=click",
            { cookie = "webui_session=" .. TOKEN })
        lu.assertEquals(200, response.status)
        lu.assertStrContains(body, 'data-route="/b"')
        lu.assertStrContains(body, "this is B")
    end)
end

function Test_webui:Test_sse_stream_serves_the_page()
    with_page(function(_, _, request)
        -- the event stream is a plain SSE endpoint; ?once=1 keeps the test
        -- single threaded
        local response, body = request("GET", "/__webui/events?once=1&push=hi", nil, {
            cookie = "webui_session=" .. TOKEN,
        })
        lu.assertEquals(200, response.status)
        lu.assertEquals("text/event-stream", response.content_type)
        lu.assertStrContains(body, "event: html")
        lu.assertStrContains(body, "data: hi")
    end)
end

if not RUN_ALL then
    os.exit(lu.LuaUnit.run('-v'))
end
