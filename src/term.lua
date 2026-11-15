-- Thin Lua surface for the low level `term` binding.
--
-- Output helpers flush Lua's own stdout first so buffered `print`/`io.write`
-- calls cannot be reordered with terminal control sequences.

return function(term)
    local output = {
        "clear", "write", "style", "reset_style",
        "move_to", "move_by", "move_to_column", "move_to_row",
        "save_cursor", "restore_cursor", "hide_cursor", "show_cursor",
        "cursor_shape", "alternate_screen", "mouse_capture", "focus_events",
        "keyboard_enhancements", "bracketed_paste", "title", "line_wrap",
        "raw", "restore",
    }

    for _, name in ipairs(output) do
        local original = term[name]
        if original then
            term[name] = function(...)
                io.flush()
                return original(...)
            end
        end
    end

    local names = {
        "default", "black", "bright_black", "red", "bright_red",
        "green", "bright_green", "yellow", "bright_yellow",
        "blue", "bright_blue", "magenta", "bright_magenta",
        "cyan", "bright_cyan", "white", "bright_white",
    }

    local colors = {}
    for _, name in ipairs(names) do
        colors[name] = name
    end

    term.color = {
        fg = colors,
        bg = colors,
        ansi = function(number) return number end,
        rgb = function(r, g, b) return { r = r, g = g, b = b } end,
    }

    term.enhancements = {
        disambiguate = 0x01,
        report_events = 0x02,
        alternate_keys = 0x04,
        all_keys = 0x08,
    }
end
