local fs
local stream

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

local function path_to_path_and_name(separator, ...)
    separator = separator == nil and fs.separator or separator

    local split = {}
    for _, arg in ipairs({ ... }) do
        for _, itm in ipairs(split_path(get_path(arg))) do
            split[#split + 1] = itm
        end
    end

    if split[1] == "." then
        table.remove(split, 1)
        for i, item in ipairs(split_path(fs.cwd())) do
            table.insert(split, i, item)
        end
    end

    if split[1] == ".." then
        for i, item in ipairs(split_path(fs.cwd())) do
            table.insert(split, i, item)
        end
    end

    --remove /./
    table.remove_if(split, function(item) return item == '.' end)

    --remove /../
    local remove = {}
    for i, item in ipairs(split) do
        if item == '..' then
            remove[#remove + 1] = i - 1
            remove[#remove + 1] = i
        end
    end
    for i, index in ipairs(remove) do
        if index - i + 1 < 1 then error("illegal path, to many parent references i.e.: ../../") end
        table.remove(split, index - i + 1)
    end
    if (split[#split] == "") then
        split[#split] = nil
    end

    local name = split[#split]
    split[#split] = nil
    return table.concat(split, separator), name
end

local function new_path(...)
    local path, name = path_to_path_and_name(nil, ...)
    return fs.create_path(path, name)
end

local function ensure_path(path)
    if (type(path) == 'table') then
        if path.full_path then
            return path
        else
            error("expecting table with 'full_path' key", 2)
        end
    end
    return new_path(path)
end

local function full_path_to_relative(path, base, include_top)
    path = ensure_path(path)
    base = ensure_path(base)
    if (include_top) then
        base = base:parent()
    end

    local path_string = get_path(path):gsub("\\", "/")
    local base_string = get_path(base):gsub("\\", "/") .. '/'

    local relative = path_string:gsub(base_string, ""):gsub("\\", "/")
    if (path:is_directory()) then
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
    if not file then
        return nil, error
    end
    local text = file:read("a")
    file:close()
    return text
end

local function read_lines(path, mode)
    local file, error = io.open(get_path(path))
    if not file then
        return nil, error
    end
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
    if not file then
        error(err, 2)
    end
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

local function walk_sub(path, func, dir_first)
    if dir_first then
        func(path)
    end

    for _, file in fs.iterate(path) do
        if file:is_directory() then
            walk_sub(file, func, dir_first)
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
        path = new_path(fs.absolute(path))
    end

    if dir_first == nil then
        dir_first = false
    end

    walk_sub(path, func, dir_first)
end

local function delete_tree(path)
    walk(path, function(file) file:delete() end)
end

local function parent(path)
    local split = split_path(get_path(path))
    if #split == 1 then
        return nil
    elseif #split == 2 then
        return fs.create_path(split[1], "")
    end

    split[#split] = nil
    local parent = split[#split]
    split[#split] = nil

    return fs.create_path(concat_path(split), parent)
end

local function child(path, name)
    if name == nil or name == "" then
        error("missing name argument", 2)
    end
    return new_path(get_path(path), name)
end

local function sibling(path, name)
    local split = split_path(get_path(path))
    if #split == 1 then
        return fs.create_path(name, "")
    end
    split[#split] = nil
    return fs.create_path(concat_path(split), name)
end

local function tree(path, dir_first)
    if dir_first == nil then
        dir_first = false
    end
    local ret = {}
    walk(path, function(file) ret[#ret + 1] = file end, dir_first)
    return ret;
end

local function stream_tree(path, dir_first)
    if stream == nil then
        stream = require "stream"
    end
    return stream(tree(path, dir_first))
end

local function create_tree_sub(path)
    if (not path:exists()) then
        create_tree_sub(path:parent())
        path:create_directory()
    end
end

local function create_tree(path)
    path = type(path) == 'string' and new_path(path) or path
    create_tree_sub(path)
end

local function chmod(path, mode)
    if os.is_linux then
        local success, ret, status = os.execute("chmod " .. mode .. " '" .. get_path(path) .. "'")
        if success and ret == "exit" and status == 0 then
            return true
        end
    end
    return false
end

local function chown(path, owner)
    if os.is_linux then
        local success, ret, status = os.execute("chown " .. owner .. " '" .. get_path(path) .. "'")
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
    fs.split_path = split_path
    fs.path = new_path
    fs.concat_path = concat_path
    fs.stream = stream_dir
    fs.stream_tree = stream_tree
    fs.tree = tree
    fs.read_all = read_all
    fs.read_lines = read_lines
    fs.lines = lines
    fs.iterate = iterate
    fs.delete_tree = delete_tree
    fs.walk = walk
    fs.parent = parent
    fs.child = child
    fs.sibling = sibling
    fs.chmod = chmod
    fs.chown = chown
    fs.get_path = get_path
    fs.ensure_path = ensure_path
    fs.create_tree = create_tree
    fs.path_to_path_and_name = path_to_path_and_name
    fs.to_relative = full_path_to_relative
    fs.is_empty = is_empty

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
    }
end
