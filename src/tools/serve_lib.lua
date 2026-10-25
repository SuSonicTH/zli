local function open_browser(url)
    if os.is_windows then
        os.execute('start "" ' .. url)
    elseif os.is_linux then
        os.execute("xdg-open " .. url .. " >/dev/null 2>&1 &")
    elseif tostring(os.name):find("mac") then
        os.execute("open " .. url .. " >/dev/null 2>&1 &")
    end
end

local function serve(dir)
    dir = dir or "./"
    local webserver = require "webserver"
    local httpserver = require "httpserver"

    webserver.serve {
        handler = function(request)
            -- httpserver.resolve_web_path/serve_file keep the previous
            -- behaviour: index.html, directory listings, 404s and traversal
            -- protection.
            return httpserver.serve_file(httpserver.resolve_web_path(dir, request.path))
        end,
        on_start = function(info)
            print("serving at " .. info.url)
            print("your browser should automatically open")
            open_browser(info.url)
        end,
    }
end

return {
    serve = serve,
}
