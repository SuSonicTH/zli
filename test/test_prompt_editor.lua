local lu = require 'luaunit'
lu.ORDER_ACTUAL_EXPECTED = false

local editor = require "prompt_editor"

local function text(value)
    local rows = value:render()
    local parts = {}
    for _, span in ipairs(rows[1] or {}) do parts[#parts + 1] = span.text end
    return table.concat(parts)
end

Test_prompt_editor = {}

function Test_prompt_editor.Test_initial_render_and_cursor()
    local e = editor.new(10, 1, { initial = "abc", single_line = true })
    local rows, cursor = e:render()
    lu.assertEquals("abc", text(e))
    lu.assertEquals(0, cursor.row)
    lu.assertEquals(3, cursor.column)
    lu.assertEquals("abc", e:value())
    e:close()
end

function Test_prompt_editor.Test_typing_and_enter()
    local e = editor.new(10, 1, { single_line = true, submit_on_enter = true })
    lu.assertEquals("continue", e:feed { type = "key", code = "char", char = "h" })
    lu.assertEquals("continue", e:feed { type = "key", code = "char", char = "i" })
    lu.assertEquals("hi", e:value())
    lu.assertEquals("submit", e:feed { type = "key", code = "enter" })
    e:close()
end

function Test_prompt_editor.Test_backspace_and_control_keys()
    local e = editor.new(10, 1, { initial = "abc" })
    e:feed { type = "key", code = "backspace" }
    lu.assertEquals("ab", e:value())
    e:feed { type = "key", code = "char", char = "a", control = true }
    local _, cursor = e:render()
    lu.assertEquals(0, cursor.column)
    e:feed { type = "key", code = "char", char = "e", control = true }
    _, cursor = e:render()
    lu.assertEquals(2, cursor.column)
    lu.assertEquals("abort", e:feed { type = "key", code = "char", char = "c", control = true })
    e:close()
end

function Test_prompt_editor.Test_mask_hides_text()
    local e = editor.new(10, 1, { initial = "abc", mask = "*" })
    local rows, cursor = e:render()
    lu.assertEquals("***", text(e))
    lu.assertEquals(3, cursor.column)
    e:feed { type = "key", code = "char", char = "d" }
    lu.assertEquals("****", text(e))
    lu.assertEquals("abcd", e:value())
    e:close()
end

function Test_prompt_editor.Test_max_length_and_single_line_paste()
    local e = editor.new(10, 1, { single_line = true, max_length = 3 })
    e:feed { type = "paste", text = "a\nbcdef" }
    lu.assertEquals("a b", e:value())
    e:close()
end

function Test_prompt_editor.Test_multiline_enter_and_alt_enter()
    local e = editor.new(20, 3, {
        initial = "one",
        single_line = false,
        submit_on_enter = true,
        alt_enter_newline = true,
    })
    lu.assertEquals("continue", e:feed { type = "key", code = "enter", alt = true })
    lu.assertEquals("continue", e:feed { type = "key", code = "char", char = "t" })
    lu.assertEquals("one\nt", e:value())
    lu.assertEquals("submit", e:feed { type = "key", code = "enter" })
    e:close()
end

function Test_prompt_editor.Test_set_text_and_resize()
    local e = editor.new(5, 1, { initial = "old" })
    e:set_text("new")
    lu.assertEquals("new", e:value())
    e:resize(3, 2)
    local rows, cursor = e:render()
    lu.assertEquals("new", text(e))
    lu.assertEquals(0, cursor.row)
    e:close()
end

function Test_prompt_editor.Test_wide_characters_layout()
    local e = editor.new(3, 2, { initial = "a界b" })
    local rows, cursor = e:render()
    local parts = {}
    for _, span in ipairs(rows[1]) do parts[#parts + 1] = span.text end
    lu.assertEquals("a界", table.concat(parts))
    lu.assertEquals(1, cursor.row)
    lu.assertEquals(1, cursor.column)
    e:close()

    e = editor.new(4, 1, { initial = "a界b" })
    lu.assertEquals("a界b", text(e))
    e:close()
end

if not RUN_ALL then
    os.exit(lu.LuaUnit.run('-v'))
end
