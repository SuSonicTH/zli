local ok, docs = pcall(require, "docs")
if not ok then
    local message = tostring(docs)
    if not message:find("documentation is not available", 1, true) then
        message = "ZLI documentation is not available in this payload (" .. message .. ")"
    end
    io.stderr:write(message, "\n")
    os.exit(1)
end

local httpserver = require "httpserver"

local function usage()
    print([[
Usage: zli @manual [options]

Serve the bundled reference manual (Lua 5.5 language and libraries, bundled
ZLI and third-party libraries, tools and ZLI topics) over HTTP.

Options:
  --port <port>      listen on this port (default 8080)
  --address <addr>   bind address (default 127.0.0.1)
  --no-open          do not open the system browser
  --output <file>    write a self-contained HTML manual and exit
  -h, --help         show this help]])
end

local function write_file(path, contents)
    local fh, err = io.open(path, "wb")
    if fh == nil then
        io.stderr:write("could not open '", path, "': ", tostring(err), "\n")
        os.exit(1)
    end
    fh:write(contents)
    fh:close()
end

local function search_redirect_handler(_, header)
    local target = header.target or ""
    local query = target:match("[?&]q=([^&]*)") or ""
    query = query:gsub("[%c]", "")
    return {
        status = httpserver.status.found,
        header = { location = query == "" and "/" or "/?q=" .. query },
    }
end

local port = 8080
local address = "127.0.0.1"
local open_browser = true
local output

local i = 1
while i <= #arg do
    local value = arg[i]
    if value == "-h" or value == "--help" then
        usage()
        os.exit(0)
    elseif value == "--port" then
        i = i + 1
        local raw_port = arg[i]
        if raw_port == nil or not raw_port:match("^%d+$") then
            io.stderr:write("--port requires an integer between 1 and 65535\n")
            os.exit(2)
        end
        port = tonumber(raw_port)
        if port < 1 or port > 65535 then
            io.stderr:write("--port requires an integer between 1 and 65535\n")
            os.exit(2)
        end
        i = i + 1
    elseif value == "--address" then
        i = i + 1
        address = arg[i]
        if address == nil then
            io.stderr:write("--address requires a value\n")
            os.exit(2)
        end
        i = i + 1
    elseif value == "--no-open" then
        open_browser = false
        i = i + 1
    elseif value == "--output" then
        i = i + 1
        output = arg[i]
        if output == nil then
            io.stderr:write("--output requires a file name\n")
            os.exit(2)
        end
        i = i + 1
    else
        io.stderr:write("unknown option: ", value, "\n")
        usage()
        os.exit(2)
    end
end

local html = docs.render_manual_html()

if output then
    write_file(output, html)
    print("wrote " .. output)
    os.exit(0)
end

local function html_response(body)
    return {
        status = httpserver.status.ok,
        body = body,
        header = { content_type = "text/html; charset=utf-8" },
    }
end

local function index_handler()
    return html_response(html)
end

local function favicon_handler()
    return { status = httpserver.status.no_content }
end

local url = string.format("http://%s:%d/", address, port)
print("serving the ZLI reference manual at " .. url)
if open_browser then
    if os.is_windows then
        os.execute("start " .. url)
    elseif os.is_linux then
        os.execute("xdg-open " .. url .. " >/dev/null 2>&1 &")
    elseif os.is_mac then
        os.execute("open " .. url .. " >/dev/null 2>&1 &")
    end
end

httpserver.serve {
    address = address,
    port = port,
    GET = {
        ["/"] = index_handler,
        ["/%?.*"] = index_handler,
        ["/index.html"] = index_handler,
        ["/index%.html%?.*"] = index_handler,
        ["/manual.html"] = index_handler,
        ["/manual%.html%?.*"] = index_handler,
        ["/search.*"] = search_redirect_handler,
        ["/favicon.ico"] = favicon_handler,
    },
}
