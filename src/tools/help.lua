local ok, docs = pcall(require, "docs")
if not ok then
    local message = tostring(docs)
    if not message:find("documentation is not available", 1, true) then
        message = "ZLI documentation is not available in this payload (" .. message .. ")"
    end
    io.stderr:write(message, "\n")
    os.exit(1)
end

local function write_file(path, contents)
    local fh, err = io.open(path, "wb")
    if fh == nil then
        io.stderr:write("could not open '", path, "': ", tostring(err), "\n")
        os.exit(1)
    end
    fh:write(contents)
    fh:close()
end

local function usage()
    print([[
Usage: zli @help [options] [query]

Show the bundled reference documentation.

Options:
  --list              list all documented modules and entries
  --search <query>    force a search instead of an exact lookup
  --markdown          emit the library reference as Markdown
  --output <file>     write the selected output to a file
  -h, --help          show this help

Examples:
  zli @help string.byte
  zli @help --search trim
  zli @help --markdown --output doc/libraries.md]])
end

-- Every output mode is rendered into this buffer first.  That keeps file
-- output byte-identical to stdout output and lets --output work everywhere.
local output = {}
local output_path

local function emit(text)
    output[#output + 1] = tostring(text or "")
end

local function emit_line(text)
    emit(text)
    emit("\n")
end

local function flush_output()
    local text = table.concat(output)
    if output_path then
        write_file(output_path, text)
    else
        io.write(text)
    end
end

local function print_results(results)
    for _, entry in ipairs(results) do
        local summary = docs.render_inline_text(entry.summary or "")
        local label = docs.render_inline_text(
            entry.kind == "section" and (entry.signature or entry.name) or entry.name)
        if summary ~= "" then
            emit_line(string.format("%-32s %s", label, summary))
        else
            emit_line(label)
        end
    end
end

local function list_all()
    for _, group in ipairs(docs.groups) do
        emit_line("\n" .. group.title)
        for _, module in ipairs(group.modules or {}) do
            emit_line("  " .. module.name)
            for _, entry in ipairs(module.entries or {}) do
                emit_line("    " .. entry.name)
            end
        end
    end

    local manual_modules = {}
    for _, entry in ipairs(docs.entries) do
        if entry.source == "lua" and entry.kind ~= "section" and entry.kind ~= "module" then
            local module = entry.module or "basic"
            manual_modules[module] = manual_modules[module] or {}
            manual_modules[module][#manual_modules[module] + 1] = entry.name
        end
    end
    local names = {}
    for name in pairs(manual_modules) do names[#names + 1] = name end
    table.sort(names)
    if #names > 0 then
        emit_line("\nLua standard library")
        for _, name in ipairs(names) do
            emit_line("  " .. name)
            for _, entry_name in ipairs(manual_modules[name]) do
                emit_line("    " .. entry_name)
            end
        end
    end
end

local args = {}
for i = 1, #arg do
    args[#args + 1] = arg[i]
end

local force_search = false
local list_only = false
local as_markdown = false

local i = 1
while i <= #args do
    local value = args[i]
    if value == "-h" or value == "--help" then
        usage()
        os.exit(0)
    elseif value == "--list" then
        list_only = true
        i = i + 1
    elseif value == "--search" then
        force_search = true
        i = i + 1
    elseif value == "--markdown" then
        as_markdown = true
        i = i + 1
    elseif value == "--output" then
        i = i + 1
        output_path = args[i]
        if output_path == nil then
            io.stderr:write("--output requires a file name\n")
            os.exit(2)
        end
        i = i + 1
    else
        break
    end
end

local query = table.concat(args, " ", i)
if force_search and query == "" then
    io.stderr:write("--search requires a query\n")
    os.exit(2)
end

if as_markdown then
    local text = docs.render_libraries_markdown()
    if text:sub(-1) ~= "\n" then text = text .. "\n" end
    emit(text)
    flush_output()
    os.exit(0)
end

if list_only then
    list_all()
    flush_output()
    os.exit(0)
end

if query == "" then
    emit_line("ZLI reference manual")
    emit_line("")
    emit_line("  zli @manual              browse the full manual in a browser")
    emit_line("  zli @help <name>         look up an entry")
    emit_line("  zli @help --search <q>   search all documentation")
    emit_line("  zli @help --list         list documented names")
    emit_line("")
    emit_line("Use ':help <name>' in the REPL.")
    flush_output()
    os.exit(0)
end

if not force_search then
    local entry = docs.find(query)
    if entry then
        emit_line(docs.render_entry(entry, "text", 80))
        flush_output()
        os.exit(0)
    end
end

local results = docs.search(query, { limit = 50 })
if #results == 0 then
    io.stderr:write("no documentation found for '", query, "'\n")
    os.exit(1)
end

if #results == 1 and not force_search then
    emit_line(docs.render_entry(results[1], "text", 80))
    flush_output()
    os.exit(0)
end

emit_line(string.format("%d result(s) for '%s':", #results, query))
print_results(results)
flush_output()
os.exit(0)
