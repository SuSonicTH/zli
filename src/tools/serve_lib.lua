local function serve(dir)
    dir = dir or "./"
    local server = require "httpserver"

    print("serving at http://127.0.0.1:8080/")
    print("your browser should automatically open")
    if os.is_windows then
        os.execute("start http://127.0.0.1:8080/")
    elseif os.is_linux then
        os.execute("xdg-open http://127.0.0.1:8080/")
    end

    server.serve {
        web_root = dir,
        cache_web_root = false,
    }
end

return {
    serve = serve,
}
