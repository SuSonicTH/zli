local lu = require 'luaunit'
lu.ORDER_ACTUAL_EXPECTED = false

local config = require "prompt.config"
local prompt = require "prompt"
local render = require "prompt.render"
local support = require "test/prompt_support"
local process = require "test/support"

Test_prompt_discover = {}

local function frame_text(frame)
    return support.frame_text(frame)
end

local function all_frames(frames)
    return support.frames_text(frames)
end

local function array(values)
    return table.concat(values, ",")
end

function Test_prompt_discover.Test_text_tab_completes_highlighted_suggestion()
    local result = support.drive({
        support.char("s"), support.char("r"), support.key("down"), support.key("enter"),
    }, function()
        return prompt.text {
            message = "Path",
            suggestions = { "src/", "scripts/", "test/" },
        }
    end)
    lu.assertEquals("src/", result[1])
end

function Test_prompt_discover.Test_text_enter_without_a_selection_submits_typed_value()
    local result = support.drive({ support.char("a"), support.key("enter") }, function()
        return prompt.text { message = "Path", suggestions = { "abc" } }
    end)
    lu.assertEquals("a", result[1])
end

function Test_prompt_discover.Test_text_tab_inserts_common_completion()
    local result = support.drive({
        support.char("t"), support.key("tab"), support.key("enter"),
    }, function()
        return prompt.text {
            message = "Path",
            suggestions = { "test/a.lua", "test/b.lua" },
        }
    end)
    lu.assertEquals("test/", result[1])
end

function Test_prompt_discover.Test_text_tab_does_not_insert_spaces_without_matches()
    local result = support.drive({
        support.char("z"), support.key("tab"), support.key("enter"),
    }, function()
        return prompt.text { message = "Path", suggestions = { "src/" } }
    end)
    lu.assertEquals("z", result[1])
end

function Test_prompt_discover.Test_text_tab_without_a_common_prefix_keeps_the_value()
    local result = support.drive({
        support.char("a"), support.key("tab"), support.key("enter"),
    }, function()
        return prompt.text { message = "Path", suggestions = { "abc", "axx" } }
    end)
    lu.assertEquals("a", result[1])
end

function Test_prompt_discover.Test_text_esc_closes_the_menu_first()
    local result = support.drive({
        support.char("a"), support.key("esc"), support.key("esc"),
    }, function()
        return prompt.text { message = "Path", suggestions = { "abc" } }
    end)
    lu.assertEquals(nil, result[1])
    lu.assertEquals("cancelled", result[2])
end

function Test_prompt_discover.Test_text_suggestion_callback_and_filter_modes()
    local seen = {}
    local result = support.drive({
        support.char("q"), support.key("down"), support.key("enter"),
    }, function()
        return prompt.text {
            message = "Value",
            suggestions = function(query)
                seen[#seen + 1] = query
                return { query .. "-item", "other" }
            end,
        }
    end)
    lu.assertEquals("q-item", result[1])
    lu.assertEquals("q", seen[#seen])

    result = support.drive({
        support.char("p"), support.char("h"), support.key("down"), support.key("enter"),
    }, function()
        return prompt.text {
            message = "Value",
            suggestions = { "alpha", "alphabet" },
            suggestion_filter = "substring",
        }
    end)
    lu.assertEquals("alphabet", result[1])

    result = support.drive({
        support.char("p"), support.char("h"), support.key("down"), support.key("enter"),
    }, function()
        return prompt.text {
            message = "Value",
            suggestions = { "alpha", "alphabet" },
            suggestion_filter = "prefix",
        }
    end)
    lu.assertEquals("ph", result[1])
end

function Test_prompt_discover.Test_text_max_suggestions_limits_the_menu()
    local _, frames = support.drive({ support.key("esc") }, function()
        return prompt.text {
            message = "Value",
            suggestions = { "one", "two", "three", "four", "five", "six", "seven" },
            max_suggestions = 3,
        }
    end)
    local text = frame_text(frames[1])
    lu.assertStrContains(text, "one")
    lu.assertStrContains(text, "three")
    lu.assertNotStrContains(text, "four")
end

function Test_prompt_discover.Test_autocomplete_highlights_first_match()
    local result, frames = support.drive({ support.char("m"), support.key("enter") }, function()
        return prompt.autocomplete {
            message = "Path",
            suggestions = { "main.lua", "makefile" },
        }
    end)
    lu.assertEquals("main.lua", result[1])
    lu.assertStrContains(all_frames(frames), "makefile")
end

function Test_prompt_discover.Test_search_fuzzy_ranking_and_keywords()
    local items = {
        { label = "Open file", value = "open", keywords = "document" },
        { label = "Close file", value = "close" },
        { label = "Reload", value = "reload" },
    }
    local result = support.drive({ support.char("o"), support.key("enter") }, function()
        return prompt.search { message = "Command", items = items }
    end)
    lu.assertEquals("open", result[1])

    result = support.drive({ support.char("z"), support.key("enter") }, function()
        return prompt.search {
            message = "Command",
            items = {
                { label = "Open", value = "open", keywords = "zebra" },
                { label = "Close", value = "close" },
            },
        }
    end)
    lu.assertEquals("open", result[1])

    result = support.drive({ support.char("z"), support.key("enter") }, function()
        return prompt.search {
            message = "Command",
            items = {
                { label = "Open", value = "open", keywords = "zebra" },
                { label = "Close", value = "close" },
            },
            filter = "substring",
        }
    end)
    lu.assertEquals("open", result[1])
end

function Test_prompt_discover.Test_search_default_and_return_index()
    local items = { "alpha", "beta" }
    local result = support.drive({ support.key("enter") }, function()
        return prompt.search { message = "Command", items = items, default = "beta" }
    end)
    lu.assertEquals("beta", result[1])

    result = support.drive({ support.key("enter") }, function()
        return prompt.search {
            message = "Command", items = items, default = "beta", return_index = true,
        }
    end)
    lu.assertEquals(2, result[1])
end

function Test_prompt_discover.Test_search_default_beyond_limit()
    local items = {}
    for index = 1, 20 do items[index] = "item" .. index end
    local result = support.drive({ support.key("enter") }, function()
        return prompt.search {
            message = "Command", items = items, default = "item15", limit = 10,
        }
    end)
    lu.assertEquals("item15", result[1])
end

function Test_prompt_discover.Test_search_set_value_supports_indexes_and_disabled_items()
    local result = support.drive({ support.key("enter") }, function()
        return prompt.form {
            values = { choice = 2 },
            fields = {
                {
                    name = "choice", type = "search", message = "Choice",
                    items = { "Alpha", "Beta" },
                    return_index = true,
                },
            },
        }
    end)
    lu.assertEquals(2, result[1].choice)

    result = support.drive({ support.key("enter"), support.key("esc") }, function()
        return prompt.form {
            values = { choice = "b" },
            fields = {
                {
                    name = "choice", type = "search", message = "Choice",
                    items = {
                        { label = "a", value = "a" },
                        { label = "b", value = "b", disabled = true },
                    },
                    filter = false,
                },
            },
        }
    end)
    lu.assertEquals(nil, result[1])
    lu.assertEquals("cancelled", result[2])
end

function Test_prompt_discover.Test_search_index_restore_wins_over_numeric_values()
    local items = {
        { label = "two", value = 2 },
        { label = "twenty", value = 20 },
        { label = "thirty", value = 30 },
    }
    local result = support.drive({ support.key("enter") }, function()
        return prompt.form {
            values = { choice = 2 },
            fields = {
                {
                    name = "choice", type = "search", message = "Choice",
                    items = items, return_index = true,
                },
            },
        }
    end)
    lu.assertEquals(2, result[1].choice)

    result = support.drive({ support.key("enter") }, function()
        return prompt.search {
            message = "Choice", items = items, default = 2, return_index = true,
        }
    end)
    lu.assertEquals(2, result[1])
end

function Test_prompt_discover.Test_search_down_from_cleared_selection_picks_first()
    local result = support.drive({
        support.key("down"), support.key("enter"),
    }, function()
        return prompt.form {
            values = { choice = "missing" },
            fields = {
                {
                    name = "choice", type = "search", message = "Choice",
                    items = { "Alpha", "Beta", "Gamma" },
                    filter = false,
                },
            },
        }
    end)
    lu.assertEquals("Alpha", result[1].choice)

    result = support.drive({
        support.key("page_down"), support.key("enter"),
    }, function()
        return prompt.form {
            values = { choice = "missing" },
            fields = {
                {
                    name = "choice", type = "search", message = "Choice",
                    items = { "Alpha", "Beta", "Gamma" },
                    filter = false,
                },
            },
        }
    end)
    lu.assertEquals("Alpha", result[1].choice)
end

function Test_prompt_discover.Test_search_numeric_index_restore_does_not_fall_back_to_value()
    local result = support.drive({ support.key("enter"), support.key("esc") }, function()
        return prompt.form {
            values = { choice = 1 },
            fields = {
                {
                    name = "choice", type = "search", message = "Choice",
                    items = {
                        { label = "a", value = 2, disabled = true },
                        { label = "b", value = 1 },
                    },
                    filter = false,
                    return_index = true,
                },
            },
        }
    end)
    lu.assertEquals(nil, result[1])
    lu.assertEquals("cancelled", result[2])
end

function Test_prompt_discover.Test_form_keeps_tall_field_selection_visible()
    local term = require "term"
    local old_size = term.size
    local items = {}
    for index = 1, 40 do items[index] = "item" .. index end
    local events = {}
    for _ = 1, 20 do events[#events + 1] = support.key("down") end
    events[#events + 1] = support.key("enter")
    local result, frames = support.drive(events, function()
        config.configure { symbols = "ascii", color = "never" }
        term.size = function() return { columns = 80, rows = 20 } end
        local ok, value = pcall(function()
            return prompt.form {
                fields = {
                    {
                        name = "pick", type = "select", message = "Pick",
                        items = items, page_size = 40,
                    },
                },
            }
        end)
        term.size = old_size
        if not ok then error(value, 0) end
        return value
    end)
    lu.assertEquals("item21", result[1].pick)
    lu.assertStrContains(all_frames(frames), "> item21")
end

function Test_prompt_discover.Test_form_keeps_tall_search_selection_visible()
    local term = require "term"
    local old_size = term.size
    local items = {}
    for index = 1, 60 do items[index] = "item" .. index end
    local events = {}
    for _ = 1, 30 do events[#events + 1] = support.key("down") end
    events[#events + 1] = support.key("enter")
    local result, frames = support.drive(events, function()
        config.configure { symbols = "ascii", color = "never" }
        term.size = function() return { columns = 80, rows = 20 } end
        local ok, value = pcall(function()
            return prompt.form {
                fields = {
                    { name = "pick", type = "search", message = "Search", items = items, limit = 100 },
                },
            }
        end)
        term.size = old_size
        if not ok then error(value, 0) end
        return value
    end)
    lu.assertEquals("item31", result[1].pick)
    lu.assertStrContains(all_frames(frames), "> item31")
end

function Test_prompt_discover.Test_form_keeps_tall_multiline_cursor_visible()
    local term = require "term"
    local old_size = term.size
    local result, frames = support.drive({ support.key("esc") }, function()
        term.size = function() return { columns = 80, rows = 16 } end
        local ok, value, message = pcall(function()
            return prompt.form {
                fields = {
                    { name = "notes", type = "multiline", message = "Notes", rows = 25 },
                },
            }
        end)
        term.size = old_size
        if not ok then error(value, 0) end
        return value, message
    end)
    lu.assertEquals("cancelled", result[2])
    lu.assertNotNil(frames[1].cursor)
end

function Test_prompt_discover.Test_form_keeps_tall_date_labels_visible()
    local term = require "term"
    local old_size = term.size
    local result, frames = support.drive({ support.key("esc") }, function()
        term.size = function() return { columns = 80, rows = 12 } end
        local ok, value, message = pcall(function()
            return prompt.form {
                title = "Schedule",
                fields = {
                    { name = "when", type = "date", message = "Date", as = "string" },
                    { name = "note", type = "text", message = "Note" },
                },
            }
        end)
        term.size = old_size
        if not ok then error(value, 0) end
        return value, message
    end)
    lu.assertEquals("cancelled", result[2])
    lu.assertStrContains(all_frames(frames), "? Date")

    old_size = term.size
    result, frames = support.drive({ support.key("esc") }, function()
        term.size = function() return { columns = 80, rows = 12 } end
        local ok, value, message = pcall(function()
            return prompt.form {
                title = "Schedule",
                fields = {
                    { name = "when", type = "datetime", message = "When", as = "string" },
                    { name = "note", type = "text", message = "Note" },
                },
            }
        end)
        term.size = old_size
        if not ok then error(value, 0) end
        return value, message
    end)
    lu.assertEquals("cancelled", result[2])
    lu.assertStrContains(all_frames(frames), "? When")
end

function Test_prompt_discover.Test_form_tall_multiline_error_fits_the_budget()
    local term = require "term"
    local old_size = term.size
    local result, frames = support.drive({
        support.key("enter", { control = true }), support.key("esc"),
    }, function()
        term.size = function() return { columns = 80, rows = 24 } end
        local ok, value, message = pcall(function()
            return prompt.form {
                fields = {
                    { name = "notes", type = "multiline", message = "Notes", rows = 25, required = true },
                },
            }
        end)
        term.size = old_size
        if not ok then error(value, 0) end
        return value, message
    end)
    lu.assertEquals("cancelled", result[2])
    local error_frame
    for _, frame in ipairs(frames) do
        if frame_text(frame):find("An answer is required.", 1, true) then
            error_frame = frame
            break
        end
    end
    lu.assertNotNil(error_frame)
    lu.assertStrContains(frame_text(error_frame), "? Notes")
    lu.assertNotNil(error_frame.cursor)
end

function Test_prompt_discover.Test_search_invalid_explicit_default_clears_selection()
    local result = support.drive({ support.key("enter"), support.key("esc") }, function()
        return prompt.search {
            message = "Command",
            items = {
                { label = "A", value = "a" },
                { label = "B", value = "b", disabled = true },
                { label = "C", value = "c" },
            },
            default = "b",
            filter = false,
        }
    end)
    lu.assertEquals(nil, result[1])
    lu.assertEquals("cancelled", result[2])
end

function Test_prompt_discover.Test_search_long_field_keeps_its_prompt_in_a_form()
    local term = require "term"
    local old_size = term.size
    local items = {}
    for index = 1, 60 do items[index] = "item" .. index end
    local result, frames = support.drive({ support.key("esc") }, function()
        term.size = function() return { columns = 80, rows = 24 } end
        local ok, value, message = pcall(function()
            return prompt.form {
                fields = {
                    { name = "pick", type = "search", message = "Search", items = items, limit = 100 },
                    { name = "name", type = "text", message = "Name" },
                },
            }
        end)
        term.size = old_size
        if not ok then error(value, 0) end
        return value, message
    end)
    lu.assertEquals("cancelled", result[2])
    local text = all_frames(frames)
    lu.assertStrContains(text, "? Search")
    lu.assertStrContains(text, "type to search")
    lu.assertNotNil(frames[1].cursor)
end

function Test_prompt_discover.Test_search_selection_stays_visible_while_scrolling()
    local term = require "term"
    local old_size = term.size
    local items = {}
    for index = 1, 20 do items[index] = "item" .. index end
    local events = {}
    for _ = 1, 14 do events[#events + 1] = support.key("down") end
    events[#events + 1] = support.key("enter")
    local result, frames = support.drive(events, function()
        term.size = function() return { columns = 80, rows = 12 } end
        local ok, value = pcall(function()
            return prompt.search { message = "Command", items = items, limit = 20 }
        end)
        term.size = old_size
        if not ok then error(value, 0) end
        return value
    end)
    lu.assertEquals("item15", result[1])
    lu.assertStrContains(all_frames(frames), "item15")
end

function Test_prompt_discover.Test_search_styles_matched_ranges()
    local _, frames = support.drive({ support.char("o"), support.key("enter") }, function()
        return prompt.search {
            message = "Command",
            items = { { label = "Open", value = "open" }, { label = "Close", value = "close" } },
        }
    end)
    local styled = false
    for _, frame in ipairs(frames) do
        for _, line in ipairs(frame.lines or {}) do
            for _, span in ipairs(line) do
                if span.style == "match" or span.style == "selected_match" then styled = true end
            end
        end
    end
    lu.assertTrue(styled)
end

function Test_prompt_discover.Test_search_substring_and_unfiltered_order()
    local result = support.drive({
        support.char("a"), support.key("enter"),
    }, function()
        return prompt.search {
            message = "Command",
            items = { "alpha", "beta", "gamma" },
            filter = "substring",
        }
    end)
    lu.assertEquals("alpha", result[1])

    result = support.drive({ support.key("down"), support.key("enter") }, function()
        return prompt.search {
            message = "Command",
            items = { "zzz", "aaa" },
            filter = false,
        }
    end)
    lu.assertEquals("aaa", result[1])
end

function Test_prompt_discover.Test_search_limit_and_empty_result()
    local result, frames = support.drive({
        support.key("down"), support.key("enter"),
    }, function()
        return prompt.search {
            message = "Command",
            items = { "one", "two", "three" },
            limit = 2,
        }
    end)
    lu.assertEquals("two", result[1])
    lu.assertNotStrContains(all_frames(frames), "three")

    local _, empty_frames = support.drive({ support.char("z") }, function()
        return prompt.search { message = "Command", items = { "one" } }
    end)
    lu.assertStrContains(all_frames(empty_frames), "no matches")
end

function Test_prompt_discover.Test_search_esc_clears_query_first()
    local result = support.drive({
        support.char("o"), support.key("esc"), support.key("esc"),
    }, function()
        return prompt.search { message = "Command", items = { "one", "two" } }
    end)
    lu.assertEquals(nil, result[1])
    lu.assertEquals("cancelled", result[2])
end

function Test_prompt_discover.Test_search_preview_pane_visibility()
    local term = require "term"
    local old_size = term.size
    local result, frames = support.drive({ support.key("enter") }, function()
        term.size = function() return { columns = 60, rows = 24 } end
        local ok, value = pcall(function()
            return prompt.search {
                message = "Command",
                items = { { label = "One", value = "one" } },
                preview = function(item) return { "preview of " .. item.label } end,
            }
        end)
        term.size = old_size
        if not ok then error(value, 0) end
        return value
    end)
    lu.assertEquals("one", result[1])
    lu.assertNotStrContains(all_frames(frames), "preview of")

    old_size = term.size
    result, frames = support.drive({ support.key("enter") }, function()
        term.size = function() return { columns = 100, rows = 24 } end
        local ok, value = pcall(function()
            return prompt.search {
                message = "Command",
                items = { { label = "One", value = "one" } },
                preview = function(item, width, height)
                    return { "preview of " .. item.label, "width " .. width, "height " .. height }
                end,
            }
        end)
        term.size = old_size
        if not ok then error(value, 0) end
        return value
    end)
    lu.assertEquals("one", result[1])
    lu.assertStrContains(all_frames(frames), "preview of One")
end

function Test_prompt_discover.Test_tree_expand_collapse_and_results()
    local items = {
        { label = "src", children = { { label = "main.zig", value = "src/main.zig" } } },
        { label = "docs" },
    }
    local result = support.drive({
        support.key("right"), support.key("down"), support.key("enter"),
    }, function()
        return prompt.tree { message = "File", items = items, filter = false }
    end)
    lu.assertEquals("src/main.zig", result[1])

    result = support.drive({
        support.key("left"), support.key("down"), support.key("enter"),
    }, function()
        return prompt.tree {
            message = "File",
            items = {
                { label = "src", value = "src", children = { { label = "main.zig", value = "m" } } },
                { label = "docs", value = "docs" },
            },
            expanded = true,
            filter = false,
        }
    end)
    lu.assertEquals("docs", result[1])
end

function Test_prompt_discover.Test_tree_space_toggles_branches()
    local result = support.drive({
        support.char(" "), support.key("down"), support.key("enter"),
    }, function()
        return prompt.tree {
            message = "File",
            items = {
                { label = "src", value = "src", children = { { label = "main.zig", value = "m" } } },
                { label = "docs", value = "docs" },
            },
            expanded = true,
            filter = false,
        }
    end)
    lu.assertEquals("docs", result[1])
end

function Test_prompt_discover.Test_tree_path_and_node_results()
    local items = { { label = "src", children = { { label = "main.zig", value = "m" } } } }
    local result = support.drive({
        support.key("right"), support.key("down"), support.key("enter"),
    }, function()
        return prompt.tree { message = "File", items = items, filter = false, as = "path" }
    end)
    lu.assertEquals("src,main.zig", array(result[1]))

    result = support.drive({
        support.key("right"), support.key("down"), support.key("enter"),
    }, function()
        return prompt.tree { message = "File", items = items, filter = false, as = "node" }
    end)
    lu.assertEquals("main.zig", result[1].label)

    result = support.drive({ support.key("enter") }, function()
        return prompt.tree { message = "File", items = { "alpha" }, filter = false, as = "node" }
    end)
    lu.assertEquals("alpha", result[1])
end

function Test_prompt_discover.Test_tree_preserves_false_values()
    local result = support.drive({ support.key("enter") }, function()
        return prompt.tree {
            message = "Flag",
            items = { { label = "off", value = false } },
            filter = false,
        }
    end)
    lu.assertEquals(false, result[1])
end

function Test_prompt_discover.Test_tree_default_selects_a_node()
    local result = support.drive({ support.key("enter") }, function()
        return prompt.tree {
            message = "File",
            items = { { label = "src", children = { { label = "main", value = "m" } } } },
            filter = false,
            default = "m",
        }
    end)
    lu.assertEquals("m", result[1])
end

function Test_prompt_discover.Test_tree_default_compares_table_values()
    local result = support.drive({ support.key("enter") }, function()
        return prompt.tree {
            message = "Pick",
            items = {
                { label = "a", value = { id = "a" } },
                { label = "b", value = { id = "b" } },
            },
            filter = false,
            default = { id = "b" },
        }
    end)
    lu.assertEquals("b", result[1].id)

    result = support.drive({ support.key("enter") }, function()
        return prompt.tree {
            message = "Pick",
            items = {
                { label = "a", value = { id = "a" } },
                { label = "b", value = { id = "b" } },
            },
            filter = false,
            multi = true,
            default = { id = "b" },
        }
    end)
    lu.assertEquals(1, #result[1])
    lu.assertEquals("b", result[1][1].id)
end

function Test_prompt_discover.Test_tree_disabled_nodes_cannot_be_restored()
    local result = support.drive({ support.key("enter") }, function()
        return prompt.form {
            values = { file = "b" },
            fields = {
                {
                    name = "file", type = "tree", message = "File",
                    items = {
                        { label = "a", value = "a" },
                        { label = "b", value = "b", disabled = true },
                    },
                    filter = false,
                },
            },
        }
    end)
    lu.assertEquals("a", result[1].file)
end

function Test_prompt_discover.Test_tree_multi_cascades_with_partial_parent()
    local result, frames = support.drive({
        support.key("down"), support.char(" "), support.key("up"), support.key("enter"),
    }, function()
        config.configure { symbols = "ascii", color = "never" }
        return prompt.tree {
            message = "File",
            items = {
                { label = "src", value = "src", children = {
                    { label = "a", value = "a" }, { label = "b", value = "b" },
                } },
            },
            expanded = true,
            filter = false,
            multi = true,
        }
    end)
    lu.assertEquals("a", result[1][1])
    lu.assertEquals(1, #result[1])
    lu.assertStrContains(all_frames(frames), "[-]")
end

function Test_prompt_discover.Test_tree_partial_glyph_after_unchecking_a_child()
    local _, frames = support.drive({
        support.char(" "), support.key("down"), support.char(" "), support.key("up"),
    }, function()
        config.configure { symbols = "ascii", color = "never" }
        return prompt.tree {
            message = "File",
            items = {
                { label = "src", value = "src", children = {
                    { label = "a", value = "a" }, { label = "b", value = "b" },
                } },
            },
            expanded = true,
            filter = false,
            multi = true,
        }
    end)
    lu.assertStrContains(all_frames(frames), "[-]")
end

function Test_prompt_discover.Test_tree_filter_keeps_ancestors_and_auto_expands()
    local result, frames = support.drive({
        support.char("m"), support.key("enter"),
    }, function()
        config.configure { symbols = "ascii", color = "never" }
        return prompt.tree {
            message = "File",
            items = {
                { label = "src", children = {
                    { label = "main.zig", value = "src/main.zig" },
                    { label = "text.lua", value = "src/text.lua" },
                } },
                { label = "README.md", value = "README.md" },
            },
            filter = true,
        }
    end)
    lu.assertEquals("src/main.zig", result[1])
    local text = all_frames(frames)
    lu.assertStrContains(text, "src")
    lu.assertStrContains(text, "main.zig")
    lu.assertNotStrContains(text, "text.lua")
    lu.assertStrContains(text, "v src")
end

function Test_prompt_discover.Test_tree_selection_stays_visible_while_scrolling()
    local term = require "term"
    local old_size = term.size
    local items = {}
    for index = 1, 20 do items[index] = "node" .. index end
    local result, frames = support.drive({ support.key("end"), support.key("enter") }, function()
        term.size = function() return { columns = 80, rows = 12 } end
        local ok, value = pcall(function()
            return prompt.tree { message = "Tree", items = items, filter = false }
        end)
        term.size = old_size
        if not ok then error(value, 0) end
        return value
    end)
    lu.assertEquals("node20", result[1])
    lu.assertStrContains(all_frames(frames), "node20")
end

function Test_prompt_discover.Test_grid_navigation_and_checked_values()
    local result = support.drive({
        support.key("right"), support.key("down"), support.char(" "), support.key("enter"),
    }, function()
        return prompt.grid {
            message = "Pick",
            items = { "one", "two", "three", "four" },
            columns = 2,
        }
    end)
    lu.assertEquals("four", result[1][1])
end

function Test_prompt_discover.Test_grid_shortcuts_and_auto_columns()
    local result, frames = support.drive({
        support.char("a"), support.char("i"), support.key("enter"),
    }, function()
        return prompt.grid { message = "Pick", items = { "a", "b", "c" } }
    end)
    lu.assertEquals({}, result[1])
    lu.assertStrContains(all_frames(frames), "a")
    lu.assertStrContains(all_frames(frames), "c")

    result = support.drive({
        support.key("enter"), support.char(" "), support.key("enter"),
    }, function()
        return prompt.grid { message = "Pick", items = { "a", "b" }, required = true }
    end)
    lu.assertEquals("a", result[1][1])
end

function Test_prompt_discover.Test_grid_defaults_and_scrolling()
    local result = support.drive({ support.key("enter") }, function()
        return prompt.grid {
            message = "Pick",
            items = { "a", "b", "c" },
            default_indices = { 2 },
        }
    end)
    lu.assertEquals("b", result[1][1])

    local term = require "term"
    local old_size = term.size
    local items = {}
    for index = 1, 20 do items[index] = "item" .. index end
    result, frames = support.drive({ support.key("end"), support.key("enter") }, function()
        term.size = function() return { columns = 80, rows = 12 } end
        local ok, value = pcall(function()
            return prompt.grid { message = "Pick", items = items, columns = 2 }
        end)
        term.size = old_size
        if not ok then error(value, 0) end
        return value
    end)
    lu.assertEquals({}, result[1])
    local text = all_frames(frames)
    lu.assertStrContains(text, "item19")
    lu.assertStrContains(text, "item20")
end

function Test_prompt_discover.Test_reorder_moves_sorts_and_resets()
    local items = { "c", "a", "b" }
    local result = support.drive({ support.char("s"), support.key("enter") }, function()
        return prompt.reorder { message = "Order", items = items }
    end)
    lu.assertEquals("a,b,c", array(result[1]))

    result = support.drive({
        support.char("s"), support.char("s"), support.key("enter"),
    }, function()
        return prompt.reorder { message = "Order", items = items }
    end)
    lu.assertEquals("c,b,a", array(result[1]))

    result = support.drive({
        support.key("down", { alt = true }), support.char("r"), support.key("enter"),
    }, function()
        return prompt.reorder { message = "Order", items = items }
    end)
    lu.assertEquals("c,a,b", array(result[1]))

    result = support.drive({ support.key("enter") }, function()
        return prompt.reorder {
            message = "Order",
            items = { "a", "b", "c" },
            default = { "c", "a" },
        }
    end)
    lu.assertEquals("c,a,b", array(result[1]))
end

function Test_prompt_discover.Test_reorder_alt_up_and_jump_keys()
    local result = support.drive({
        support.key("end"), support.key("up", { alt = true }), support.key("enter"),
    }, function()
        return prompt.reorder { message = "Order", items = { "a", "b", "c" } }
    end)
    lu.assertEquals("a,c,b", array(result[1]))

    result = support.drive({ support.char("G"), support.key("enter") }, function()
        return prompt.reorder { message = "Order", items = { "a", "b", "c" } }
    end)
    lu.assertEquals("a,b,c", array(result[1]))
end

function Test_prompt_discover.Test_reorder_selection_stays_visible_while_scrolling()
    local term = require "term"
    local old_size = term.size
    local items = {}
    for index = 1, 20 do items[index] = "item" .. index end
    local result, frames = support.drive({ support.key("end"), support.key("enter") }, function()
        term.size = function() return { columns = 80, rows = 12 } end
        local ok, value = pcall(function()
            return prompt.reorder { message = "Order", items = items }
        end)
        term.size = old_size
        if not ok then error(value, 0) end
        return value
    end)
    lu.assertEquals("item20", result[1][20])
    lu.assertStrContains(all_frames(frames), "item20")
end

function Test_prompt_discover.Test_form_field_adapters()
    local result, frames = support.drive({
        support.char("o"), support.key("enter"),
        support.key("right"), support.key("down"), support.key("enter"),
        support.char(" "), support.key("enter"),
    }, function()
        return prompt.form {
            fields = {
                {
                    name = "command", type = "search", message = "Command",
                    items = { { label = "Open", value = "open" }, { label = "Close", value = "close" } },
                },
                {
                    name = "file", type = "tree", message = "File",
                    items = { { label = "src", children = { { label = "main.zig", value = "src/main.zig" } } } },
                    filter = false,
                },
                { name = "cols", type = "grid", message = "Columns", items = { "a", "b" } },
            },
        }
    end)
    lu.assertEquals("open", result[1].command)
    lu.assertEquals("src/main.zig", result[1].file)
    lu.assertEquals("a", result[1].cols[1])
    local text = all_frames(frames)
    lu.assertStrContains(text, "? Command")
    lu.assertStrContains(text, "type to search")
    lu.assertNotStrContains(text, "up/down move  enter select")
end

function Test_prompt_discover.Test_form_search_set_value_restores_by_value()
    local result = support.drive({ support.key("enter") }, function()
        return prompt.form {
            values = { command = "close" },
            fields = {
                {
                    name = "command", type = "search", message = "Command",
                    items = { { label = "Open", value = "open" }, { label = "Close", value = "close" } },
                    filter = false,
                },
            },
        }
    end)
    lu.assertEquals("close", result[1].command)
end

function Test_prompt_discover.Test_plain_fallbacks()
    local script = process.temp_file("prompt_discover_fallback", [[
local prompt = require "prompt"
local function line(label, value)
    if type(value) == "table" then value = table.concat(value, ",") end
    print(label .. "=" .. tostring(value))
end
line("search", prompt.search { message = "Search", items = { "alpha", "beta" } })
line("tree", prompt.tree {
    message = "Tree",
    items = { { label = "src", children = { { label = "main", value = "m" } } } },
})
line("tree_multi", prompt.tree {
    message = "Tree",
    items = { { label = "src", value = "s", children = { { label = "main", value = "m" } } } },
    multi = true,
})
line("grid", prompt.grid { message = "Grid", items = { "a", "b" } })
line("reorder", prompt.reorder { message = "Order", items = { "a", "b", "c" } })
]])
    local stdout, status = process.run({ script }, {
        home = process.temp_dir("prompt_discover_home"),
        stdin = "2\n2\n1,2\n1\n3,1,2\n",
    })
    lu.assertEquals(0, status, stdout)
    lu.assertStrContains(stdout, "search=beta")
    lu.assertStrContains(stdout, "tree=m")
    lu.assertStrContains(stdout, "tree_multi=s,m")
    lu.assertStrContains(stdout, "grid=a")
    lu.assertStrContains(stdout, "reorder=c,a,b")
end

function Test_prompt_discover.Test_reorder_fallback_rejects_bad_permutations()
    local script = process.temp_file("prompt_reorder_fallback", [[
local prompt = require "prompt"
print(table.concat(prompt.reorder { message = "Order", items = { "a", "b", "c" } }, ","))
]])
    local stdout, status = process.run({ script }, {
        home = process.temp_dir("prompt_discover_home"),
        stdin = "1,1\n1,2\n3,1,2\n",
    })
    lu.assertEquals(0, status, stdout)
    lu.assertStrContains(stdout, "Enter every item exactly once.")
    lu.assertStrContains(stdout, "c,a,b")
end

function Test_prompt_discover.Test_reorder_fallback_eof_returns_default()
    local script = process.temp_file("prompt_reorder_eof", [[
local prompt = require "prompt"
print(table.concat(prompt.reorder {
    message = "Order",
    items = { "a", "b", "c" },
    default = { "c", "a" },
}, ","))
]])
    local stdout, status = process.run({ script }, {
        home = process.temp_dir("prompt_discover_home"),
        stdin = "",
    })
    lu.assertEquals(0, status, stdout)
    lu.assertStrContains(stdout, "c,a,b")
end

function Test_prompt_discover.Test_plain_form_restores_tree_values()
    local script = process.temp_file("prompt_tree_form_values", [[
local prompt = require "prompt"
local values = assert(prompt.form {
    values = { file = "m" },
    fields = {
        {
            name = "file", type = "tree", message = "File", filter = false,
            items = { { label = "src", children = { { label = "main", value = "m" } } } },
        },
    },
})
print("file=" .. tostring(values.file))
]])
    local stdout, status = process.run({ script }, {
        home = process.temp_dir("prompt_discover_home"),
        stdin = "\n",
    })
    lu.assertEquals(0, status, stdout)
    lu.assertStrContains(stdout, "file=m")
end

function Test_prompt_discover.Test_plain_form_restores_search_index_values()
    local script = process.temp_file("prompt_search_form_index", [[
local prompt = require "prompt"
local values = assert(prompt.form {
    values = { choice = 2 },
    fields = {
        {
            name = "choice", type = "search", message = "Choice",
            items = { "Alpha", "Beta" }, return_index = true,
        },
    },
})
print("choice=" .. tostring(values.choice))
]])
    local stdout, status = process.run({ script }, {
        home = process.temp_dir("prompt_discover_home"),
        stdin = "",
    })
    lu.assertEquals(0, status, stdout)
    lu.assertStrContains(stdout, "choice=2")
end

function Test_prompt_discover.Test_plain_search_invalid_default_is_not_selected()
    local script = process.temp_file("prompt_search_invalid_default", [[
local prompt = require "prompt"
local values = assert(prompt.form {
    values = { s = "b" },
    fields = {
        {
            name = "s", type = "search", message = "Search", required = true,
            items = {
                { label = "A", value = "a" },
                { label = "B", value = "b", disabled = true },
            },
        },
    },
})
print("s=" .. tostring(values.s))
]])
    local stdout, status = process.run({ script }, {
        home = process.temp_dir("prompt_discover_home"),
        stdin = "\n1\n",
    })
    lu.assertEquals(0, status, stdout)
    lu.assertStrContains(stdout, "Please choose one of the listed numbers.")
    lu.assertStrContains(stdout, "s=a")
end

function Test_prompt_discover.Test_plain_tree_blank_selects_first_node()
    local script = process.temp_file("prompt_tree_first", [[
local prompt = require "prompt"
local value = prompt.tree {
    message = "Pick",
    items = { { label = "a", value = "a" }, { label = "b", value = "b" } },
}
print("value=" .. tostring(value))
]])
    local stdout, status = process.run({ script }, {
        home = process.temp_dir("prompt_discover_home"),
        stdin = "\n",
    })
    lu.assertEquals(0, status, stdout)
    lu.assertStrContains(stdout, "value=a")

    local invalid = process.temp_file("prompt_tree_invalid_default", [[
local prompt = require "prompt"
local value = prompt.tree {
    message = "Pick",
    items = { { label = "a", value = "a" }, { label = "b", value = "b" } },
    default = "missing",
}
print("value=" .. tostring(value))
]])
    stdout, status = process.run({ invalid }, {
        home = process.temp_dir("prompt_discover_home"),
        stdin = "\n",
    })
    lu.assertEquals(0, status, stdout)
    lu.assertStrContains(stdout, "value=a")

    local eof = process.temp_file("prompt_tree_eof", [[
local prompt = require "prompt"
local value, message = prompt.tree {
    message = "Pick",
    items = { { label = "a", value = "a" } },
}
print("value=" .. tostring(value))
print("message=" .. tostring(message))
]])
    stdout, status = process.run({ eof }, {
        home = process.temp_dir("prompt_discover_home"),
        stdin = "",
    })
    lu.assertEquals(0, status, stdout)
    lu.assertStrContains(stdout, "value=nil")
    lu.assertStrContains(stdout, "message=eof")
end

function Test_prompt_discover.Test_plain_tree_default_respects_minimum()
    local script = process.temp_file("prompt_tree_default_min", [[
local prompt = require "prompt"
local value, message = prompt.tree {
    message = "Pick",
    items = {
        { label = "a", value = "a" },
        { label = "b", value = "b" },
    },
    multi = true,
    min = 2,
    default = { "a" },
}
print("value=" .. tostring(value))
print("message=" .. tostring(message))
]])
    local stdout, status = process.run({ script }, {
        home = process.temp_dir("prompt_discover_home"),
        stdin = "",
    })
    lu.assertEquals(0, status, stdout)
    lu.assertStrContains(stdout, "value=nil")
    lu.assertStrContains(stdout, "message=Choose at least 2.")
end

if not RUN_ALL then
    os.exit(lu.LuaUnit.run('-v'))
end
