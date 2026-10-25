-- Shared helpers for tests that exercise the payload commandline tools.
-- This file is intentionally not named test_* so the test runner will not
-- execute it as a test suite.

local fs = require "filesystem"

local support = {}

local sequence = 0

function support.temp_path(name)
    sequence = sequence + 1
    return string.format("test/temp/%s_%d", name, sequence)
end

function support.temp_dir(name)
    local path = support.temp_path(name)
    fs.create_tree(path)
    return path
end

function support.temp_file(name, contents)
    local path = support.temp_path(name)
    io.write_file(path, contents)
    return path
end

function support.quote(value)
    value = tostring(value)
    if os.is_windows then
        return '"' .. value:gsub('"', '""') .. '"'
    end
    return "'" .. value:gsub("'", "'\\''") .. "'"
end

--- Run a command and capture its combined stdout and stderr.
-- options:
--   exe:      executable to run, defaults to the running zli binary
--   home:     value for the HOME environment variable
--   stdin:    string written to the process its standard input
-- returns: output, exit status
function support.run(args, options)
    options = options or {}
    local exe = options.exe or ZLI.exe_path or arg[0]

    local command = {}

    if options.home then
        if os.is_windows then
            command[#command + 1] = "set \"HOME=" .. options.home .. "\" &&"
        else
            command[#command + 1] = "HOME=" .. support.quote(options.home)
        end
    end

    command[#command + 1] = support.quote(exe)
    for _, value in ipairs(args or {}) do
        command[#command + 1] = support.quote(value)
    end

    if options.stdin then
        local input = support.temp_file("stdin", options.stdin)
        command[#command + 1] = "< " .. support.quote(input)
    end

    command[#command + 1] = "2>&1"

    local pipe = assert(io.popen(table.concat(command, " "), "r"))
    local output = pipe:read("a") or ""
    local ok, _, code = pipe:close()
    if code == nil then
        code = ok and 0 or 1
    end
    return output, code
end


--- Start a long lived child process and return as soon as it prints its first
-- line. The child is expected to signal readiness by printing a line (for
-- example the URL of a server it just started).
--
-- options: exe, home (see support.run)
-- returns: handle with `line`, `pipe`; finish with support.spawn_finish
function support.spawn(args, options)
    options = options or {}
    local exe = options.exe or ZLI.exe_path or arg[0]

    local command = {}
    if options.home then
        if os.is_windows then
            command[#command + 1] = "set \"HOME=" .. options.home .. "\" &&"
        else
            command[#command + 1] = "HOME=" .. support.quote(options.home)
        end
    end

    command[#command + 1] = support.quote(exe)
    for _, value in ipairs(args or {}) do
        command[#command + 1] = support.quote(value)
    end
    command[#command + 1] = "2>&1"

    local pipe = assert(io.popen(table.concat(command, " "), "r"))
    local line = pipe:read("*l")
    return { line = line, pipe = pipe }
end

--- Read the remaining output of a spawned process and return it with its exit
-- status.
function support.spawn_finish(handle)
    local rest = handle.pipe:read("a") or ""
    local ok, _, code = handle.pipe:close()
    if code == nil then
        code = ok and 0 or 1
    end
    return rest, code
end

return support
