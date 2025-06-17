local http

local function handle_request(opt, header)
    --table.print(header, "header")
    local paths = opt[header.method]
    if paths then
        local path = paths[header.target]
        if path then
            local path_type = type(path)
            if path_type == 'string' then
                return path
            elseif path_type == "function" then
                return path(opt, header)
            else
                return "500"
            end
        else
            return "404"
        end
    else
        return "405"
    end
end

local function serve(opt)
    if type(opt) ~= "table" then
        arg_error("http.serve", 1, "expecting a table with options", 2)
    end
    local address = opt.address or "127.0.0.1"
    local port = opt.port or 8080
    http.listen(address, port, handle_request, opt)
end

return function(httpserver)
    http = httpserver
    httpserver.serve = serve
end
