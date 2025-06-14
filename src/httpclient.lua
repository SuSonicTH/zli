local http
local json = require "cjson"
local fs = require "filesystem"

local function call(func, url, options, body)
    arg_check_type(func, 1, url, 4, "string")
    arg_check_type(func, 2, options, 4, "table", "nil")
    options = options or {}
    if (func == 'get' or func == 'head' or func == 'delete') and body ~= nil then
        arg_error(func, 4, func .. " does not support sending a body", 3)
    else
        arg_check_type(func, 3, body, 4, "table", "string", "nil")
        body = body or ""
    end

    if options.header == nil then
        options.header = {}
    end

    if options.query then
        if url:sub(-1) ~= '?' then
            url = url .. '?'
        end
        local params = {}
        for key, value in pairs(options.query) do
            params[#params + 1] = key:urlEecode() .. '=' .. value:urlEecode()
        end
        url = url .. table.concat(params, '&')
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
            options.header.authorization = "Basic " .. userpass:base64encode()
        else
            error("unexpected type for basicAuth expecting table with user and password, got " .. type(options.basicAuth))
        end
    end

    local response, body = http.call(func:upper(), url, options, body)

    if response == nil then
        if options.raiseError then
            error(body, 2)
        else
            return nil, body
        end
    end

    if options.parseJson and response.success and body:is_not_empty() then
        return response, json.decode(body)
    end

    if func == 'get' and options.save then
        local path = type(options.save) == 'boolean' and fs.path("./") or fs.ensure_path(options.save)
        if path:exists() and path:is_directory() then
            if response.content_disposition then
                for _, value in ipairs(response.content_disposition:to_table(";")) do
                    if value:trim():starts_with("filename") then
                        local _, filename = value:split("=")
                        path = fs.path(path, filename)
                    end
                end
            end
        end
        local fh = io.open(path.full_path, "w")
        if fh == nil then
            if options.raiseError then
                error("could not write to file '" .. path.full_path .. "'", 2)
            else
                return nil, "could not write to file '" .. path.full_path .. "'"
            end
        end
        fh:write(body)
        fh:close()
        return response, path
    end

    return response, body
end

return function(httpclient)
    http = httpclient
    httpclient.get = function(url, options, body) return call("get", url, options, body) end
    httpclient.head = function(url, options, body) return call("head", url, options, body) end
    httpclient.post = function(url, options, body) return call("post", url, options, body) end
    httpclient.put = function(url, options, body) return call("put", url, options, body) end
    httpclient.patch = function(url, options, body) return call("patch", url, options, body) end
    httpclient.delete = function(url, options, body) return call("delete", url, options, body) end
end
