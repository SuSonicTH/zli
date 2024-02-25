local NIL = {}
local weak_key = { __mode = "k" }
local weak_value = { __mode = "v" }

local function memoize(func)
    local mem = setmetatable({}, weak_key)

    return function(...)
        local args = table.pack(...)
        local results = mem

        for i = 1, args.n do
            local v = args[i]
            local key = type(v) == "nil" and NIL or v

            local last = results
            results = results[key]
            if results == nil then
                results = setmetatable({}, weak_key)
                last[key] = results
            end
        end

        if not results.ret then
            results.ret = setmetatable(table.pack(func(...)), weak_value)
        end
        local ret = results.ret
        return table.unpack(ret, 1, ret.n)
    end
end

return memoize
