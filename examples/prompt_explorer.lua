-- Explore a directory with prompt.file, prompt.table, prompt.keyvalue and
-- prompt.diff.
--
-- Run it with:
--   ./zig-out/bin/zli examples/prompt_explorer.lua
--
-- When stdin is a pipe every step uses its plain-text fallback.

local prompt = require "prompt"
local filesystem = require "filesystem"

local function need(value, message)
    if value == nil then
        print("cancelled: " .. tostring(message or "cancelled"))
        os.exit(0)
    end
    return value
end

local selected = need(prompt.file {
    message = "Choose a Lua or Markdown file",
    start = ".",
    mode = "file",
    filter = { "*.lua", "*.md" },
    preview = true,
    absolute = true,
}, "file selection cancelled")

local parent = filesystem.parent(selected)
local rows = {}
local ok, entries = pcall(filesystem.list, parent.full_path)
if ok and entries then
    for _, entry in ipairs(entries) do
        local name = entry.name or ""
        if name ~= "" and name:sub(1, 1) ~= "." then
            local is_directory = entry:is_directory()
            local size = ""
            if not is_directory then
                local size_ok, bytes = pcall(function() return entry:size() end)
                if size_ok then size = tostring(bytes) end
            end
            rows[#rows + 1] = {
                name = name,
                kind = is_directory and "directory" or "file",
                size = size,
                path = entry.full_path,
            }
        end
    end
end
table.sort(rows, function(left, right)
    return left.name:lower() < right.name:lower()
end)

local row = need(prompt.table {
    message = "Entries in " .. tostring(parent.name or parent.full_path),
    columns = {
        { name = "name", title = "Name", width = 24 },
        { name = "kind", title = "Kind", width = 9 },
        { name = "size", title = "Size", width = 10, align = "right" },
    },
    rows = rows,
    sort = "name",
    page_size = 12,
}, "table selection cancelled")

prompt.keyvalue {
    message = "Selected entry",
    data = {
        name = row.name,
        kind = row.kind,
        size = row.size ~= "" and row.size or "-",
        path = row.path,
    },
    order = { "name", "kind", "size", "path" },
}

prompt.diff {
    message = "What a small edit looks like",
    old = "local function greet(name)\n    return 'hello ' .. name\nend\n",
    new = "local function greet(name)\n    return 'hello ' .. name .. '!'\nend\n\nprint(greet('world'))\n",
    mode = "unified",
    labels = { "before", "after" },
}

print(string.format("selected=%s kind=%s size=%s", row.name, row.kind,
    row.size ~= "" and row.size or "-"))
