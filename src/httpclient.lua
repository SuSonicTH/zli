local http
local json = require "cjson"

local function sanitise_args(func, url, options, body)
    arg_check_type(func, 1, url, 5, "string")
    arg_check_type(func, 2, options, 5, "table", "nil")
    options = options or {}
    arg_check_type(func, 3, body, 5, "table", "string", "nil")
    body = body or ""

    if options.header == nil then
        options.header = {}
    end

    if (type(body) == "table") then
        body = json.encode(body)
        if options.header.content_type == nil then
            options.header.content_type = "application/json"
        end
    end
    if options.basicAuth then
        if type(options.basicAuth) == "table" then
            local userpass = options.basicAuth.user .. ':' .. (options.basicAuth.pass or options.basicAuth.password)
            options.header.authorization = "Basic " .. string.base64encode(userpass)
        else
            error("unexpected type for basicAuth expecting table got " .. type(options.basicAuth))
        end
    end
    return url, options, body
end

local function processResult(options, response, body)
    if response == nil then
        if options.raiseError then
            error(body, 2)
        else
            return response, body
        end
    end
    if options.parseJson and response.status >= 200 and response.status < 300 then
        return response, json.decode(body)
    end
    return response, body
end

local function get(url, options, body)
    if (body) then arg_error("get", 1, "get does not support sending a body", 3) end
    local url, options = sanitise_args("get", url, options)
    return processResult(options, http.call("GET", url, options))
end

local function post(url, options, body)
    local url, options, body = sanitise_args("post", url, options, body)
    return processResult(options, http.call("POST", url, options, body))
end


return function(httpclient)
    http = httpclient
    httpclient.get = get
    httpclient.post = post
end
