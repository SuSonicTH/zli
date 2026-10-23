local fs
local stream

local function raise_or_return_error(message, level)
    if fs.error_handling == "raise" then
        error(message, level)
    else
        return nil, message
    end
end

local function concat_path(path, file)
    if type(path) == "table" then
        path = table.concat(path, fs.separator)
    end
    if file == nil or file == "" then
        return path
    end

    local last_char = path:sub(-1);
    if (last_char ~= '/' and last_char ~= '\\') then
        path = path .. fs.separator
    end
    return path .. file
end

local function split_path(path)
    local ret = {}
    for item in string.gmatch(path, "([^/\\]+)") do
        table.insert(ret, item)
    end
    return ret
end

local function get_path(path)
    return type(path) == "table" and path.full_path or path;
end

local function is_absolute(path)
    return path:sub(1, 1) == "/" or path:sub(1, 1) == "\\" or path:match("^%a:[/\\]") ~= nil
end

local function path_to_path_and_name(separator, ...)
    separator = separator == nil and fs.separator or separator

    local split = {}
    local absolute = false
    local unc = false
    local drive = nil

    for _, arg in ipairs({ ... }) do
        local path = get_path(arg)
        if type(path) ~= "string" then
            return raise_or_return_error("expecting a path string or path object", 4)
        end

        if path:sub(1, 2) == "\\\\" then
            unc = true
            absolute = true
        elseif path:match("^%a:[/\\]") then
            drive = path:sub(1, 2)
            absolute = true
        elseif path:sub(1, 1) == "/" or path:sub(1, 1) == "\\" then
            absolute = true
        end

        for item in path:gmatch("[^/\\]+") do
            split[#split + 1] = item
        end
    end

    -- A leading "." or ".." means the path is relative to the current
    -- directory. Resolve those against the cwd so that ".." can be applied.
    if not absolute and (split[1] == "." or split[1] == "..") then
        absolute = true
        local cwd = {}
        for item in fs.cwd():gmatch("[^/\\]+") do
            cwd[#cwd + 1] = item
        end
        for i = #cwd, 1, -1 do
            table.insert(split, 1, cwd[i])
        end
    end

    local resolved = {}
    for _, item in ipairs(split) do
        if item == "." then
            -- current directory marker, nothing to do
        elseif item == ".." then
            if #resolved > 0 and resolved[#resolved] ~= ".." then
                table.remove(resolved)
            elseif absolute then
                return raise_or_return_error("illegal path, to many parent references i.e.: ../../", 4)
            else
                resolved[#resolved + 1] = item
            end
        else
            resolved[#resolved + 1] = item
        end
    end

    local name = table.remove(resolved) or ""
    local path = table.concat(resolved, separator)

    if absolute then
        if unc then
            path = separator .. separator .. path
        elseif drive then
            path = drive .. separator .. path
        else
            path = separator .. path
        end
    end

    return path, name
end

local function new_path(...)
    local path, name_or_error = path_to_path_and_name(nil, ...)
    if not path then return nil, name_or_error end
    return fs.create_path(path, name_or_error)
end

local function ensure_path(path)
    if (type(path) == 'table') then
        if path.full_path then
            return path
        else
            error("expecting string representing a path or a path object (table with 'full_path' key)", 2)
        end
    end
    return new_path(path)
end

local function full_path_to_relative(path, base, include_top)
    path = ensure_path(path)
    base = ensure_path(base)

    -- relative paths have to be anchored before they can be compared with the
    -- absolute paths returned by list()/walk()
    if not is_absolute(get_path(path)) then
        local absolute = fs.absolute(get_path(path))
        if absolute == nil then
            return raise_or_return_error("path does not exist: " .. get_path(path), 3)
        end
        path = fs.path(absolute)
    end
    if not is_absolute(get_path(base)) then
        local absolute = fs.absolute(get_path(base))
        if absolute == nil then
            return raise_or_return_error("path does not exist: " .. get_path(base), 3)
        end
        base = fs.path(absolute)
    end

    if (include_top) then
        base = base:parent()
    end

    local path_string = get_path(path):gsub("\\", "/")
    local base_string = get_path(base):gsub("\\", "/")
    if base_string:sub(-1) ~= "/" then
        base_string = base_string .. "/"
    end

    local relative
    if path_string == base_string:sub(1, -2) then
        relative = ""
    elseif path_string:sub(1, #base_string) == base_string then
        relative = path_string:sub(#base_string + 1)
    else
        relative = path_string
    end

    if (path:is_directory() and relative ~= "" and relative:sub(-1) ~= "/") then
        relative = relative .. "/"
    end
    return relative
end

local function stream_dir(path)
    if stream == nil then
        stream = require "stream"
    end
    return stream(fs.list(path))
end

local function read_all(path)
    local file, error = io.open(get_path(path))
    if not file then return raise_or_return_error(error) end
    local text = file:read("a")
    file:close()
    return text
end

local function read_lines(path, mode)
    local file, error = io.open(get_path(path))
    if not file then return raise_or_return_error(error) end

    mode = mode or 'l'

    local ret = {}
    for line in file:lines(mode) do
        ret[#ret + 1] = line
    end
    file:close()
    return ret
end

local function lines(path, mode)
    local file, err = io.open(get_path(path))
    if not file then return raise_or_return_error(err, 2) end
    mode = mode or 'l'
    return function(file, idx)
        local line, err = file:read(mode)
        if not line then
            if err then
                error(err, 2)
            end
            return nil
        end
        return idx + 1, line
    end, file, 0, file
end

local function iterate(path, sorted)
    if sorted then
        return sorted_pairs(fs.dir(path))
    else
        return pairs(fs.dir(path))
    end
end

local function walk_sub(path, func, dir_first, visited)
    -- Resolve symlinks so that cyclic links cannot recurse forever.
    local real = fs.absolute(get_path(path))
    if real ~= nil then
        if visited[real] then
            return
        end
        visited[real] = true
    end

    if dir_first then
        func(path)
    end

    for _, file in fs.iterate(path) do
        if file:is_directory() then
            walk_sub(file, func, dir_first, visited)
        else
            func(file)
        end
    end

    if not dir_first then
        func(path)
    end
end

local function walk(path, func, dir_first)
    if type(path) == "string" then
        local absolute = fs.absolute(path)
        if absolute == nil then
            return raise_or_return_error("path does not exist: " .. path, 2)
        end
        path = new_path(absolute)
    end

    if path == nil then
        return raise_or_return_error("missing path", 2)
    end

    if dir_first == nil then
        dir_first = false
    end

    walk_sub(path, func, dir_first, {})
end

local function delete_tree(path)
    walk(path, function(file) file:delete() end)
end

local function parent(path)
    local full = get_path(path)
    if type(full) ~= "string" or full == "" then
        return nil
    end

    full = full:gsub("[/\\]+$", "")
    if full == "" or full:match("^%a:$") then
        return nil
    end

    local base = full:match("^(.*)[/\\][^/\\]+$")
    if base == nil then
        if is_absolute(full) then
            return nil
        end
        return fs.path(".")
    elseif base == "" then
        return fs.path(fs.separator)
    elseif base:match("^%a:$") then
        return fs.path(base .. fs.separator)
    end

    return fs.path(base)
end

local function child(path, name)
    if name == nil or name == "" then
        error("missing name argument", 2)
    end
    return new_path(get_path(path), name)
end

local function sibling(path, name)
    if name == nil or name == "" then
        error("missing name argument", 2)
    end

    local full = get_path(path):gsub("[/\\]+$", "")
    local base = full:match("^(.*)[/\\][^/\\]*$")
    if base == nil then
        return fs.path(name)
    elseif base == "" then
        return fs.path(fs.separator, name)
    end
    return fs.path(base, name)
end

local function tree(path, dir_first)
    if dir_first == nil then
        dir_first = false
    end
    local ret = {}
    walk(path, function(file) ret[#ret + 1] = file end, dir_first)
    return ret;
end

local function tree_size(path)
    local size = 0
    walk(path, function(file)
        if file:is_file() then
            size = size + file:size()
        end
    end)
    return size;
end

local function tree_size_hr(path)
    return fs.size_to_hr(tree_size(path));
end


local function stream_tree(path, dir_first)
    if stream == nil then
        stream = require "stream"
    end
    return stream(tree(path, dir_first))
end

local function create_tree_sub(path)
    if path == nil then
        return
    end
    if (not path:exists()) then
        local parent_path = path:parent()
        if parent_path ~= nil then
            create_tree_sub(parent_path)
        end
        path:create_directory()
    end
end

local function create_tree(path)
    path = type(path) == 'string' and new_path(path) or path
    create_tree_sub(path)
end

local function shell_quote(value)
    return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

local function chmod(path, mode)
    if os.is_linux then
        local mode_string = tostring(mode)
        if not mode_string:match("^[0-7]+$") then
            return false
        end
        local success, ret, status = os.execute("chmod " .. mode_string .. " " .. shell_quote(get_path(path)))
        if success and ret == "exit" and status == 0 then
            return true
        end
    end
    return false
end

local function chown(path, owner)
    if os.is_linux then
        local owner_string = tostring(owner)
        if not owner_string:match("^[%w_.:-]+$") then
            return false
        end
        local success, ret, status = os.execute("chown " .. owner_string .. " " .. shell_quote(get_path(path)))
        if success and ret == "exit" and status == 0 then
            return true
        end
    end
    return false
end

local function is_empty(path)
    return #ensure_path(path):list() == 0
end

return function(filesystem)
    fs = filesystem
    fs.child = child
    fs.chmod = chmod
    fs.chown = chown
    fs.concat_path = concat_path
    fs.create_tree = create_tree
    fs.delete_tree = delete_tree
    fs.ensure_path = ensure_path
    fs.get_path = get_path
    fs.is_empty = is_empty
    fs.iterate = iterate
    fs.lines = lines
    fs.parent = parent
    fs.path = new_path
    fs.path_to_path_and_name = path_to_path_and_name
    fs.read_all = read_all
    fs.read_lines = read_lines
    fs.sibling = sibling
    fs.split_path = split_path
    fs.stream = stream_dir
    fs.stream_tree = stream_tree
    fs.to_relative = full_path_to_relative
    fs.tree = tree
    fs.tree_size = tree_size
    fs.tree_size_hr = tree_size_hr
    fs.walk = walk

    return {
        read_all    = read_all,
        read_lines  = read_lines,
        lines       = lines,
        iterate     = iterate,
        delete_tree = delete_tree,
        walk        = walk,
        parent      = parent,
        child       = child,
        sibling     = sibling,
        stream      = stream_dir,
        stream_tree = stream_tree,
        tree        = tree,
        to_relative = full_path_to_relative,
        is_empty    = is_empty,
        chmod       = chmod,
        chown       = chown,
    }
end
