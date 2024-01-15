local function iterate_collection(collection, func)
    if collection._is_collection and collection._type == 'key' then
        for item, _ in pairs(collection._items) do
            if func(item) == nil then
                return false
            end
        end
    elseif collection._is_collection and collection._type == 'index' then
        for _, item in ipairs(collection._items) do
            if func(item) == nil then
                return false
            end
        end
    else
        for _, item in ipairs(collection) do
            if func(item) == nil then
                return false
            end
        end
    end
    return true
end

local function new_set(init)
    local set = {
        _is_collection = true,
        _type = 'key',
        _size = 0
    }

    function set:size()
        return self._size
    end

    function set:is_empty()
        return self._size == 0
    end

    function set:clear()
        self._size = 0
        self.items = {}
        return self
    end

    function set:add(item)
        if self._items[item] == nil then
            self._size = self._size + 1
        end
        self._items[item] = true
        return self
    end

    function set:add_all(collection)
        arg_check_type("set:add_all", 1, collection, 'table')
        iterate_collection(collection, function(item) return self:add(item) end)
        return self
    end

    function set:remove(item)
        if self._items[item] then
            self._size = self._size - 1
            self._items[item] = nil
        end
        return self
    end

    function set:remove_all(collection)
        arg_check_type("set:remove_all", 1, collection, 'table')
        iterate_collection(collection, function(item) return self:remove(item) end)
        return self
    end

    function set:retain_all(collection)
        arg_check_type("set:retain_all", 1, collection, 'table')
        if collection._is_collection and collection._type == 'key' then
            for item, _ in pairs(self._items) do
                if collection:contains(item) == false then
                    self._items[item] = nil
                    self._size = self._size - 1
                end
            end
        else
            local keep = {}
            local size = 0
            iterate_collection(collection, function(item)
                if self._items[item] then
                    keep[item] = true
                    size = size + 1
                end
                return true
            end)
            self._items = keep
            self._size = size
        end
        return self
    end

    function set:contains(item)
        return self._items[item] ~= nil
    end

    function set:contains_all(collection)
        arg_check_type("set:contains_all", 1, collection, 'table')
        local finished = iterate_collection(collection,
            function(item)
                return self._items[item]
            end)
        return finished;
    end

    function set:copy()
        return new_set(self)
    end

    function set:next()
        return function(state)
            state.key = next(state.items, state.key)
            return state.key
        end, { items = self._items }
    end

    function set:union(...)
        local ret = new_set(self);
        for _, collection in ipairs { ... } do
            ret:add_all(collection)
        end
        return ret
    end

    function set:intersection(...)
        local ret = new_set(self);
        for _, collection in ipairs { ... } do
            ret:retain_all(collection)
        end
        return ret
    end

    function set:difference(...)
        local ret = new_set(self);
        for _, collection in ipairs { ... } do
            ret:remove_all(collection)
        end
        return ret
    end

    function set:equals(collection)
        arg_check_type("set:equals", 1, collection, 'table')
        local count = 0
        local finished = iterate_collection(collection,
            function(item)
                count = count + 1
                return self._items[item]
            end
        )
        return finished and count == self._size
    end

    local init_type = type(init)
    if init_type == 'number' then
        set._items = table.create(0, init)
    elseif init_type == 'table' then
        if type(init.size) == 'function' then
            set._items = table.create(0, init:size())
        else
            set._items = table.create(0, #init)
        end
        set:add_all(init)
    end

    return set
end

return {
    new_set = new_set,
    iterate = iterate_collection
}
