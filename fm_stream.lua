local aux = require "aux"

local function new_stream(next)
    local stream = {
        next = next,
        of = function(...)
            return new_stream(table.next { ... })
        end
    }

    function stream:map(func)
        return new_stream(function()
            local value = self:next()
            if (value) then
                return func(value)
            end
        end
        )
    end

    function stream:peek(func)
        return new_stream(function()
            local value = self:next()
            if (value) then
                func(value)
            end
            return value
        end)
    end

    function stream:filter(func)
        return new_stream(function()
            local value
            repeat
                value = self:next()
            until (value == nil or func(value))
            if (value) then
                return value
            end
        end)
    end

    function stream:skip(n)
        for i = 1, n do
            if (self:next() == nil) then
                break
            end
        end
        return self
    end

    function stream:limit(limit)
        local count = 0
        return new_stream(function()
            local value = self:next()
            if (value and count < limit) then
                count = count + 1
                return value
            end
        end)
    end

    function stream:reverse()
        local array = stream:toarray();
        local len = #array
        for i = 1, len / 2 do
            array[i], array[len - i + 1] = array[len - i + 1], array[i]
        end
        return new_stream(table.next(array))
    end

    function stream:sort(func)
        return new_stream(table.next(self:tosortedarray(func)))
    end

    function stream:maptonumber()
        return new_stream(function()
            return tonumber(self:next())
        end)
    end

    function stream:distinct()
        local map = {}
        return new_stream(function()
            local value = self:next()
            while value ~= nil and map[value] ~= nil do
                value = self:next()
            end
            if value ~= nil then
                map[value] = true
            end
            return value
        end)
    end

    function stream:split(func)
        local function split(flag, this, other)
            return function()
                if (this[1] ~= nil) then
                    return table.remove(this, 1)
                else
                    local value = self:next()
                    while (value) do
                        if (func(value) == flag) then
                            return value
                        end
                        other[#other + 1] = value
                        value = self:next()
                    end
                end
            end
        end

        local match = {}
        local nomatch = {}
        return new_stream(split(true, match, nomatch)), new_stream(split(false, nomatch, match))
    end

    function stream:join(...)
        local current = self
        local streams = { ... }
        return new_stream(function()
            local value = current:next()
            while (value == nil and #streams > 0) do
                current = table.remove(streams, 1)
                value = current:next()
            end
            return value
        end)
    end

    --[[ TERMINALS ]]
    function stream:foreach(func)
        local value = self:next()
        while (value) do
            func(value)
            value = self:next()
        end
    end

    function stream:toarray()
        local array = {}
        self:foreach(function(value) array[#array + 1] = value end)
        return array
    end

    function stream:tosortedarray(func)
        local func = func or table.comparator
        local array = {}
        self:foreach(function(value) table.insertsorted(array, value, func) end)
        return array
    end

    function stream:print()
        self:foreach(print)
    end

    function stream:concat(separator)
        return table.concat(self:toarray(), separator)
    end

    function stream:allmatch(func)
        local value = self:next()
        while value do
            if not func(value) then
                return false
            end
            value = self:next()
        end
        return true
    end

    function stream:firstmatch(func)
        return self:filter(func):next()
    end

    function stream:nonmatch(func)
        return self:firstmatch(func) == nil
    end

    function stream:anymatch(func)
        return self:firstmatch(func) ~= nil
    end

    function stream:first()
        return self:next()
    end

    function stream:last()
        local ret
        self:foreach(function(value) ret = value end)
        return ret
    end

    function stream:count()
        return self:reduce(0, function(count) return count + 1 end)
    end

    function stream:sum()
        return self:reduce(0, function(sum, value) return sum + value end)
    end

    function stream:average()
        local sum = 0
        local count = 0
        self:foreach(function(value)
            sum = sum + value
            count = count + 1
        end)
        if (count==0) then return 0 end
        return sum / count
    end

    function stream:median(func)
        local array = self:tosortedarray()
        if #array==0 then
            return 0
        end
        if #array % 2 == 0 then
            return (array[#array / 2] + array[#array / 2 + 1]) / 2
        end
        return array[math.floor(#array / 2) + 1]
    end

    function stream:iterator()
        return self.next
    end

    function stream:collector(func)
        return func(self.next)
    end

    function stream:reduce(state, func)
        local value = self:next()
        while value do
            state = func(state, value)
            value = self:next()
        end
        return state
    end

    function stream:min(func)
        local func = func or aux.comparator
        local ret
        stream:foreach(function(value)
            ret = ret or math.maxdouble
            if func(value, ret) then ret = value end
        end)
        return ret
    end

    function stream:max(func)
        local func = func or aux.comparator
        local ret
        stream:foreach(function(value)
            ret = ret or math.mindouble
            if func(ret, value) then ret = value end
        end)
        return ret
    end

    function stream:groupby(func)
        local ret = {}
        stream:foreach(function(value)
            local key = func(value)
            local values = ret[key]
            if not values then
                values = {}
                ret[key] = values
            end
            values[#values + 1] = value
        end)
        return ret
    end

    return stream
end

local function stream(iterator, state, control, closing)
    if (type(iterator) == "table") then
        if (iterator.next) then
            return new_stream(iterator.next)
        else
            return new_stream(table.next(iterator))
        end
    elseif type(iterator) == "function" then
        return new_stream(function()
            control = iterator(state, control)
            return control
        end)
    else
        return new_stream(function() return iterator end)
    end
end

return stream
