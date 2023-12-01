local fs
local stream

local function concat_path(path, file)
    file = file == nil and "" or file
    if type(path) == "table" then
        path = table.concat(path, fs.separator)
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

local function path(path, file)
    if path == "" or path == '.' or path == './' or path == '.\\' then
        path = fs.cwd();
    elseif file == nil then
        local split = split_path(path)
        file = split[#split]
        split[#split] = nil
        path = concat_path(split)
    end
    print("path:" .. path .. "," .. file)
    return fs.create_path(path, file)
end

local KB = 1024
local MB = KB * 1024
local GB = MB * 1024
local TB = GB * 1024

local function size_hr(size)
    local unit = "B"
    local size_hr = size

    if size >= TB then
        unit = "TB"
        size_hr = size / TB
    elseif size >= GB then
        unit = "GB"
        size_hr = size / GB
    elseif size >= MB then
        unit = "MB"
        size_hr = size / MB
    elseif size >= KB then
        unit = "KB"
        size_hr = size / KB
    end
    size_hr = (size_hr .. ""):gsub("(%d+%.%d?).*", "%1")
    return size_hr .. " " .. unit
end

local function stream_dir(path)
    if stream == nil then
        stream = require "stream"
    end
    return stream(fs.list(path))
end

return function(filesystem)
    fs = filesystem
    fs.split_path = split_path
    fs.path = path
    fs.concat_path = concat_path
    fs.size_hr = size_hr
    fs.stream = stream_dir
end
