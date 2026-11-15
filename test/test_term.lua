local lu = require 'luaunit'
lu.ORDER_ACTUAL_EXPECTED = false

local support = require "test/support"

Test_term = {}

function Test_term.Test_non_terminal_helpers_are_safe()
    local script = support.temp_file("term_non_tty", [[
local term = require "term"
print("tty", term.is_tty())
local size, message = term.size()
print("size", size == nil, type(message))
term.clear("all")
term.style { fg = "red", bold = true }
term.reset_style()
term.move_to(1, 1)
term.restore()
print("ok")
]])
    local stdout, status = support.run({ script }, { home = support.temp_dir("term_home") })

    lu.assertEquals(0, status, stdout)
    lu.assertStrContains(stdout, "tty\tfalse")
    lu.assertStrContains(stdout, "size\ttrue\tstring")
    lu.assertStrContains(stdout, "ok")
    lu.assertNotStrContains(stdout, "\27[")
end

function Test_term.Test_display_width_helpers()
    local script = support.temp_file("term_width", [[
local term = require "term"
print(term.width("abc"), term.width("a界b"))
print(term.truncate("abcdef", 4))
print(term.truncate("abcdef", 4, "…"))
print(term.wrap("abcdef", 3))
print(string.format("%q", term.truncate("\27[31mabcdef\27[0m", 5)))
print(string.format("%q", term.truncate("a\tb", 2)))
print(pcall(term.wrap, "abcdef", 0))
print("tabbed=" .. term.width("abc\ndef\tg"))
]])
    local stdout, status = support.run({ script }, { home = support.temp_dir("term_home") })

    lu.assertEquals(0, status, stdout)
    lu.assertStrContains(stdout, "3\t4")
    lu.assertStrContains(stdout, "a...")
    lu.assertStrContains(stdout, "abc…")
    lu.assertStrContains(stdout, "abc\ndef")
    lu.assertStrContains(stdout, "\\27[31mab...\\27[0m")
    lu.assertStrContains(stdout, '"a "')
    lu.assertStrContains(stdout, "false")
    lu.assertStrContains(stdout, "tabbed=9")
end

function Test_term.Test_colour_constructors()
    local script = support.temp_file("term_colours", [[
local term = require "term"
print(term.color.ansi(42))
print(term.color.rgb(1, 2, 3).g)
print(term.color.fg.bright_cyan)
]])
    local stdout, status = support.run({ script }, { home = support.temp_dir("term_home") })

    lu.assertEquals(0, status, stdout)
    lu.assertStrContains(stdout, "42\n")
    lu.assertStrContains(stdout, "2\n")
    lu.assertStrContains(stdout, "bright_cyan\n")
end


function Test_term.Test_timed_read_drains_closed_pipe()
    if os.is_windows then return end
    local script = support.temp_file("term_pipe", [[
local term = require "term"
print("poll=" .. tostring(term.poll(0)))
local event, message = term.read_event(100)
print("first=" .. tostring(event and event.char) .. " " .. tostring(message))
local event2, message2 = term.read_event(100)
print("second=" .. tostring(event2 and event2.char) .. " " .. tostring(message2))
]])
    local exe = ZLI.exe_path or arg[0]
    local home = support.temp_dir("term_home")
    local command = "HOME=" .. support.quote(home)
        .. " printf a | " .. support.quote(exe) .. " " .. support.quote(script)
    local pipe = assert(io.popen(command, "r"))
    local stdout = pipe:read("a") or ""
    pipe:close()
    lu.assertStrContains(stdout, "first=a nil")
    lu.assertStrContains(stdout, "second=nil eof")
end


function Test_term.Test_blocking_read_reports_eof()
    local script = support.temp_file("term_block", [[
local term = require "term"
local chars = {}
while true do
    local event, message = term.read_event()
    if event == nil then
        print("end=" .. tostring(message))
        break
    end
    chars[#chars + 1] = event.char
end
print("chars=" .. table.concat(chars))
]])
    local stdout, status = support.run({ script }, {
        home = support.temp_dir("term_home"),
        stdin = "abc",
    })
    lu.assertEquals(0, status, stdout)
    lu.assertStrContains(stdout, "end=eof")
    lu.assertStrContains(stdout, "chars=abc")
end


function Test_term.Test_batch_defers_and_flushes()
    local script = support.temp_file("term_batch", [[
local term = require "term"
term.batch(function()
    term.write("a")
    term.write("b")
end)
print("c")
]])
    local stdout, status = support.run({ script }, { home = support.temp_dir("term_home") })
    lu.assertEquals(0, status, stdout)
    lu.assertStrContains(stdout, "abc")
end

if not RUN_ALL then
    os.exit(lu.LuaUnit.run('-v'))
end
