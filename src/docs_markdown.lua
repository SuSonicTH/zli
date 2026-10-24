-- Markdown helpers used by the bundled documentation.
--
-- Block parsing, HTML rendering and inline text extraction use the bundled
-- md4c binding (`markdown`).  The Lua manual is converted to GitHub-flavored
-- Markdown at build time, and the authored library documentation in
-- doc/libraries.lua uses the same dialect.  Raw HTML is disabled so signatures
-- such as `zli @compile <config>` stay literal text.

local md4c = require "markdown"

local markdown = {}

local document_options = {
    dialect = "github",
    flags = { "no_html_blocks", "no_html_spans" },
}

local function escape_html(text)
    return (tostring(text):gsub("[&<>\"']", {
        ["&"] = "&amp;",
        ["<"] = "&lt;",
        [">"] = "&gt;",
        ['"'] = "&quot;",
        ["'"] = "&#39;",
    }))
end
markdown.escape_html = escape_html

local entity_map = {
    amp = "&", lt = "<", gt = ">", quot = '"', apos = "'", nbsp = "\194\160",
    mdash = "\226\128\148", ndash = "\226\128\147", hellip = "\226\128\166",
    copy = "\194\169", reg = "\194\174", trade = "\226\132\162",
}

local function decode_entity(text)
    local name = text:match("^&([^;]+);$")
    if not name then return text end
    local mapped = entity_map[name]
    if mapped then return mapped end

    local value = name:match("^#(%d+)$")
    local base = 10
    if not value then
        value = name:match("^#[xX](%x+)$")
        base = 16
    end
    if value then
        local code = tonumber(value, base)
        if code and code > 0 and code <= 0x10FFFF then
            return utf8.char(code)
        end
    end
    return text
end

-- Build a small block tree from md4c's event stream.  The text renderer only
-- needs blocks and inline text, so spans are flattened and links keep their
-- label.  Nesting (lists, quotes, tables) is preserved by md4c, which avoids
-- the line-oriented subset parser this module used to carry.
local function parse_blocks(text)
    local root = { type = "root", blocks = {} }
    local stack = { root }
    local table_block = nil

    local function top()
        return stack[#stack]
    end

    local function push(node)
        local parent = top()
        if parent.type == "list" and node.type == "li" then
            parent.items[#parent.items + 1] = node
        elseif parent.type == "table_row" then
            parent.cells[#parent.cells + 1] = node
        elseif node.type == "table_row" then
            local rows = parent.type == "table_head" and parent.owner.head or parent.owner.body
            rows[#rows + 1] = node
        elseif parent.type ~= "table_head" and parent.type ~= "table_body" then
            parent.blocks = parent.blocks or {}
            parent.blocks[#parent.blocks + 1] = node
        end
        stack[#stack + 1] = node
        return node
    end

    local function append_text(kind, value)
        for i = #stack, 1, -1 do
            local node = stack[i]
            if node.type == "code_block" then
                node.chunks[#node.chunks + 1] = value
                return
            end
            if node.inline then
                node.inline[#node.inline + 1] = { kind = kind, text = value }
                return
            end
        end
    end

    md4c.parse(text, {
        enter_block = function(kind, detail)
            if kind == "doc" or kind == "blank" then
                return
            elseif kind == "ul" or kind == "ol" then
                push({
                    type = "list",
                    ordered = kind == "ol",
                    start = (detail and detail.start) or 1,
                    items = {},
                })
            elseif kind == "li" then
                push({ type = "li", inline = {}, blocks = {} })
            elseif kind == "p" then
                push({ type = "paragraph", inline = {} })
            elseif kind == "h" then
                push({
                    type = "heading",
                    level = (detail and detail.level) or 1,
                    inline = {},
                })
            elseif kind == "code" then
                push({ type = "code_block", chunks = {} })
            elseif kind == "quote" or kind == "admonition" then
                push({ type = "quote", blocks = {} })
            elseif kind == "hr" then
                push({ type = "hr" })
            elseif kind == "table" then
                table_block = { type = "table", head = {}, body = {} }
                push(table_block)
            elseif kind == "thead" then
                push({ type = "table_head", owner = table_block })
            elseif kind == "tbody" then
                push({ type = "table_body", owner = table_block })
            elseif kind == "tr" then
                push({ type = "table_row", cells = {} })
            elseif kind == "th" or kind == "td" then
                push({
                    type = "table_cell",
                    align = (detail and detail.align) or "default",
                    inline = {},
                })
            elseif kind == "footnote_def_section" or kind == "footnote_def" then
                push({ type = "container", blocks = {} })
            else
                push({ type = kind, blocks = {} })
            end
        end,
        leave_block = function(kind)
            if kind == "doc" or kind == "blank" then return end
            stack[#stack] = nil
        end,
        enter_span = function() end,
        leave_span = function() end,
        text = function(kind, value)
            if kind == "softbr" then
                append_text("text", " ")
            elseif kind == "br" then
                append_text("text", "\n")
            elseif kind == "entity" then
                append_text("text", decode_entity(value))
            elseif kind == "code" then
                append_text("code", value)
            elseif kind == "normal" or kind == "html" or kind == "latexmath" then
                append_text("text", value)
            end
        end,
    }, document_options)

    local function finish(node)
        if node.type == "code_block" then
            node.text = table.concat(node.chunks):gsub("\n$", "")
            node.chunks = nil
        end
        for _, child in ipairs(node.blocks or {}) do finish(child) end
        for _, item in ipairs(node.items or {}) do finish(item) end
        for _, cell in ipairs(node.cells or {}) do finish(cell) end
        for _, row in ipairs(node.head or {}) do
            for _, cell in ipairs(row.cells) do finish(cell) end
        end
        for _, row in ipairs(node.body or {}) do
            for _, cell in ipairs(row.cells) do finish(cell) end
        end
    end
    finish(root)
    return root.blocks
end
markdown.parse = parse_blocks

local function inline_text(nodes)
    local out = {}
    for _, node in ipairs(nodes or {}) do
        out[#out + 1] = node.text
    end
    return table.concat(out)
end

-- Titles, summaries and signatures are single inline fragments.  md4c has no
-- inline-only entry point, and a full parse per fragment costs more than this
-- small formatter, so keep the inline helpers local.
local function count_run(text, pos, char)
    local i = pos
    while i <= #text and text:sub(i, i) == char do
        i = i + 1
    end
    return i - pos
end

local function render_inline_html(text)
    local out = {}
    local i = 1

    local function push(value)
        out[#out + 1] = value
    end

    while i <= #text do
        local c = text:sub(i, i)

        if c == "\\" and i < #text then
            push(escape_html(text:sub(i + 1, i + 1)))
            i = i + 2
        elseif c == "`" then
            local n = count_run(text, i, "`")
            local close = text:find(string.rep("`", n), i + n, true)
            if close then
                local content = text:sub(i + n, close - 1)
                push("<code>" .. escape_html(content) .. "</code>")
                i = close + n
            else
                push(escape_html(string.rep("`", n)))
                i = i + n
            end
        elseif c == "*" then
            local n = count_run(text, i, "*")
            if n >= 3 then
                local close = text:find("***", i + 3, true)
                if close then
                    push("<strong><em>" .. render_inline_html(text:sub(i + 3, close - 1)) .. "</em></strong>")
                    i = close + 3
                else
                    push(escape_html(string.rep("*", n)))
                    i = i + n
                end
            elseif n == 2 then
                local close = text:find("**", i + 2, true)
                if close then
                    push("<strong>" .. render_inline_html(text:sub(i + 2, close - 1)) .. "</strong>")
                    i = close + 2
                else
                    push(escape_html(string.rep("*", n)))
                    i = i + n
                end
            else
                local close = text:find("*", i + 1, true)
                if close then
                    push("<em>" .. render_inline_html(text:sub(i + 1, close - 1)) .. "</em>")
                    i = close + 1
                else
                    push("*")
                    i = i + 1
                end
            end
        elseif c == "[" then
            local close = text:find("]", i + 1, true)
            if close and text:sub(close + 1, close + 1) == "(" then
                local url_end = text:find(")", close + 2, true)
                if url_end then
                    local label = text:sub(i + 1, close - 1)
                    local url = text:sub(close + 2, url_end - 1)
                    push('<a href="' .. escape_html(url) .. '">' .. render_inline_html(label) .. "</a>")
                    i = url_end + 1
                else
                    push("[")
                    i = i + 1
                end
            else
                push("[")
                i = i + 1
            end
        else
            push(escape_html(c))
            i = i + 1
        end
    end

    return table.concat(out)
end
markdown.render_inline_html = render_inline_html

local function render_inline_text(text)
    local out = {}
    local i = 1

    local function push(value)
        out[#out + 1] = value
    end

    while i <= #text do
        local c = text:sub(i, i)

        if c == "\\" and i < #text then
            push(text:sub(i + 1, i + 1))
            i = i + 2
        elseif c == "`" then
            local n = count_run(text, i, "`")
            local close = text:find(string.rep("`", n), i + n, true)
            if close then
                push(text:sub(i + n, close - 1))
                i = close + n
            else
                push(string.rep("`", n))
                i = i + n
            end
        elseif c == "*" then
            local n = count_run(text, i, "*")
            if n >= 3 then
                local close = text:find("***", i + 3, true)
                if close then
                    push(render_inline_text(text:sub(i + 3, close - 1)))
                    i = close + 3
                else
                    push(string.rep("*", n))
                    i = i + n
                end
            elseif n == 2 then
                local close = text:find("**", i + 2, true)
                if close then
                    push(render_inline_text(text:sub(i + 2, close - 1)))
                    i = close + 2
                else
                    push(string.rep("*", n))
                    i = i + n
                end
            else
                local close = text:find("*", i + 1, true)
                if close then
                    push(render_inline_text(text:sub(i + 1, close - 1)))
                    i = close + 1
                else
                    push("*")
                    i = i + 1
                end
            end
        elseif c == "[" then
            local close = text:find("]", i + 1, true)
            if close and text:sub(close + 1, close + 1) == "(" then
                local url_end = text:find(")", close + 2, true)
                if url_end then
                    push(render_inline_text(text:sub(i + 1, close - 1)))
                    i = url_end + 1
                else
                    push("[")
                    i = i + 1
                end
            else
                push("[")
                i = i + 1
            end
        else
            push(c)
            i = i + 1
        end
    end

    return table.concat(out)
end
markdown.render_inline_text = render_inline_text

local function wrap(text, width)
    local lines = {}
    local line = ""
    for word in text:gmatch("%S+") do
        if line == "" then
            line = word
        elseif #line + 1 + #word <= width then
            line = line .. " " .. word
        else
            lines[#lines + 1] = line
            line = word
        end
    end
    if line ~= "" then lines[#lines + 1] = line end
    return lines
end

local function pad(text, width)
    return text .. string.rep(" ", math.max(0, width - #text))
end

local function table_lines(node)
    local rows = {}
    for _, row in ipairs(node.head) do rows[#rows + 1] = row end
    for _, row in ipairs(node.body) do rows[#rows + 1] = row end
    if #rows == 0 then return {} end

    local widths = {}
    local column_count = 0
    for _, row in ipairs(rows) do
        if #row.cells > column_count then column_count = #row.cells end
        for column, cell in ipairs(row.cells) do
            local value = inline_text(cell.inline)
            widths[column] = math.max(widths[column] or 1, #value, 1)
        end
    end
    for column = 1, column_count do
        widths[column] = widths[column] or 1
    end

    local out = {}
    local function format_row(row, separator)
        local cells = {}
        for column = 1, column_count do
            local cell = row.cells[column]
            cells[column] = pad(cell and inline_text(cell.inline) or "", widths[column])
        end
        out[#out + 1] = "| " .. table.concat(cells, " | ") .. " |"
        if separator then
            local rules = {}
            for column = 1, column_count do
                rules[column] = string.rep("-", widths[column])
            end
            out[#out + 1] = "| " .. table.concat(rules, " | ") .. " |"
        end
    end

    for index, row in ipairs(rows) do
        format_row(row, index == #node.head)
    end
    return out
end

local function block_lines(block, width)
    if block.type == "paragraph" then
        return wrap(inline_text(block.inline), width)
    elseif block.type == "heading" then
        local text = inline_text(block.inline)
        local underline = block.level == 1 and "=" or (block.level == 2 and "-" or "~")
        return { text, string.rep(underline, #text) }
    elseif block.type == "code_block" then
        local lines = {}
        for line in (block.text .. "\n"):gmatch("(.-)\n") do
            lines[#lines + 1] = "    " .. line
        end
        return lines
    elseif block.type == "hr" then
        return { string.rep("-", math.min(width, 40)) }
    elseif block.type == "table" then
        return table_lines(block)
    elseif block.type == "list" then
        local out = {}
        local number = block.start or 1
        for _, item in ipairs(block.items) do
            local marker = block.ordered and (tostring(number) .. ". ") or "- "
            number = number + 1
            local started = false
            local item_width = math.max(1, width - #marker)

            local function emit(lines, separator)
                if #lines == 0 then return end
                if started and separator then out[#out + 1] = "" end
                for index, line in ipairs(lines) do
                    if not started and index == 1 then
                        out[#out + 1] = marker .. line
                    else
                        out[#out + 1] = string.rep(" ", #marker) .. line
                    end
                    started = true
                end
            end

            if #item.inline > 0 then
                emit(wrap(inline_text(item.inline), item_width), false)
            end
            for _, child in ipairs(item.blocks) do
                emit(block_lines(child, item_width), child.type ~= "list")
            end
            if not started then out[#out + 1] = marker end
        end
        return out
    elseif block.type == "quote" then
        local inner = {}
        for _, child in ipairs(block.blocks) do
            if #inner > 0 then inner[#inner + 1] = "" end
            for _, line in ipairs(block_lines(child, math.max(1, width - 2))) do
                inner[#inner + 1] = line
            end
        end
        local out = {}
        for _, line in ipairs(inner) do
            out[#out + 1] = line == "" and ">" or ("> " .. line)
        end
        return out
    elseif block.type == "container" then
        local out = {}
        for _, child in ipairs(block.blocks or {}) do
            if #out > 0 then out[#out + 1] = "" end
            for _, line in ipairs(block_lines(child, width)) do
                out[#out + 1] = line
            end
        end
        return out
    end
    return {}
end

local function render_blocks_text(blocks, width)
    local out = {}
    for _, block in ipairs(blocks) do
        local lines = block_lines(block, width)
        if #lines > 0 then
            if #out > 0 then out[#out + 1] = "" end
            for _, line in ipairs(lines) do
                out[#out + 1] = line
            end
        end
    end
    return table.concat(out, "\n")
end

function markdown.to_html(text)
    if text == nil or text == "" then return "" end
    return md4c.html(text, document_options)
end

function markdown.to_text(text, width)
    if text == nil or text == "" then return "" end
    return render_blocks_text(parse_blocks(text), width or 80)
end

return markdown
