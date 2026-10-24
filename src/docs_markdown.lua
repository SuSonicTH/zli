-- Small Markdown renderer used by the bundled documentation.
--
-- The Lua manual is converted to this Markdown subset at build time, and the
-- authored library documentation in doc/libraries.lua uses the same subset.
-- Keeping the renderer small makes the generated manual, @help and the REPL
-- :help command share exactly the same content.

local markdown = {}

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

local function split_cells(line)
    local cells = {}
    local start = 1
    if line:sub(1, 1) == "|" then
        start = 2
    end
    local pos = start
    while pos <= #line do
        local pipe = line:find("|", pos, true)
        if pipe == nil then
            local cell = line:sub(pos):gsub("%s+$", "")
            if cell ~= "" or #cells > 0 then
                cells[#cells + 1] = cell
            end
            break
        end
        cells[#cells + 1] = line:sub(pos, pipe - 1):gsub("^%s+", ""):gsub("%s+$", "")
        pos = pipe + 1
    end
    if #cells > 0 and cells[#cells] == "" then
        cells[#cells] = nil
    end
    return cells
end

local function is_table_separator(line)
    return line:find("^%s*|?%s*:?%-%-+") ~= nil
end

local function list_item(line)
    local indent, marker, _, text = line:match("^(%s*)([%-%*%+])(%s+)(.*)$")
    if marker then
        return #indent, false, text
    end
    indent, marker, _, text = line:match("^(%s*)(%d+[%.%)])(%s+)(.*)$")
    if marker then
        return #indent, true, text
    end
    return nil
end

local function starts_block(line)
    if line:match("^%s*$") then return true end
    if line:match("^%s*[`~][`~][`~]") then return true end
    if line:match("^%s*#+%s+") then return true end
    if line:match("^%s*%-%-%-+%s*$") then return true end
    if line:match("^%s*>") then return true end
    if list_item(line) then return true end
    return false
end

local function parse_blocks(text)
    local lines = {}
    for line in (text .. "\n"):gmatch("(.-)\n") do
        lines[#lines + 1] = line
    end

    local blocks = {}
    local i = 1
    while i <= #lines do
        local line = lines[i]

        if line:match("^%s*$") then
            i = i + 1
        elseif line:match("^%s*([`~]+)") and #(line:match("^%s*([`~]+)")) >= 3 then
            local fence = line:match("^%s*([`~]+)")
            local char = fence:sub(1, 1)
            local info = line:match("^%s*[`~]+%s*(.-)%s*$")
            local code = {}
            i = i + 1
            while i <= #lines do
                local close = lines[i]:match("^%s*([`~]+)%s*$")
                if close and close:sub(1, 1) == char and #close >= #fence then
                    break
                end
                code[#code + 1] = lines[i]
                i = i + 1
            end
            blocks[#blocks + 1] = { type = "code", text = table.concat(code, "\n"), info = info }
            i = i + 1
        elseif line:match("^%s*#+%s+") then
            local hashes, title = line:match("^%s*(#+)%s+(.*)$")
            blocks[#blocks + 1] = { type = "heading", level = #hashes, text = title }
            i = i + 1
        elseif line:match("^%s*%-%-%-+%s*$") then
            blocks[#blocks + 1] = { type = "hr" }
            i = i + 1
        elseif line:match("^%s*>") then
            local quote = {}
            while i <= #lines and lines[i]:match("^%s*>") do
                quote[#quote + 1] = lines[i]:gsub("^%s*>%s?", "")
                i = i + 1
            end
            blocks[#blocks + 1] = { type = "blockquote", text = table.concat(quote, "\n") }
        elseif list_item(line) then
            local items = {}
            local _, ordered = list_item(line)
            while i <= #lines do
                local indent, is_ordered, item_text = list_item(lines[i])
                if not indent then break end
                if is_ordered ~= ordered then break end
                items[#items + 1] = { indent = indent, ordered = is_ordered, text = item_text }
                i = i + 1
            end
            blocks[#blocks + 1] = { type = "list", ordered = ordered, items = items }
        elseif line:find("|", 1, true) and i < #lines and is_table_separator(lines[i + 1]) then
            local headers = split_cells(line)
            local rows = {}
            i = i + 2
            while i <= #lines and lines[i]:find("|", 1, true) and not lines[i]:match("^%s*$") do
                rows[#rows + 1] = split_cells(lines[i])
                i = i + 1
            end
            blocks[#blocks + 1] = { type = "table", headers = headers, rows = rows }
        else
            local paragraph = { line }
            i = i + 1
            while i <= #lines and not starts_block(lines[i]) do
                paragraph[#paragraph + 1] = lines[i]
                i = i + 1
            end
            blocks[#blocks + 1] = { type = "paragraph", text = table.concat(paragraph, " ") }
        end
    end

    return blocks
end
markdown.parse = parse_blocks

local function render_list_html(block)
    local out = {}
    local stack = {}

    local function close_level()
        local top = stack[#stack]
        out[#out + 1] = "</li></" .. top.tag .. ">"
        stack[#stack] = nil
    end

    for _, item in ipairs(block.items) do
        local tag = item.ordered and "ol" or "ul"
        if #stack == 0 then
            out[#out + 1] = "<" .. tag .. ">"
            stack[#stack + 1] = { indent = item.indent, tag = tag }
        elseif item.indent > stack[#stack].indent then
            out[#out + 1] = "<" .. tag .. ">"
            stack[#stack + 1] = { indent = item.indent, tag = tag }
        elseif item.indent < stack[#stack].indent then
            while #stack > 0 and item.indent < stack[#stack].indent do
                close_level()
            end
            if #stack > 0 and item.indent == stack[#stack].indent then
                out[#out + 1] = "</li>"
            else
                out[#out + 1] = "<" .. tag .. ">"
                stack[#stack + 1] = { indent = item.indent, tag = tag }
            end
        else
            out[#out + 1] = "</li>"
        end
        out[#out + 1] = "<li>" .. render_inline_html(item.text)
    end

    while #stack > 0 do
        close_level()
    end
    return table.concat(out)
end

local function render_blocks_html(blocks)
    local out = {}
    for _, block in ipairs(blocks) do
        if block.type == "paragraph" then
            out[#out + 1] = "<p>" .. render_inline_html(block.text) .. "</p>"
        elseif block.type == "heading" then
            local tag = "h" .. math.min(block.level, 6)
            out[#out + 1] = "<" .. tag .. ">" .. render_inline_html(block.text) .. "</" .. tag .. ">"
        elseif block.type == "code" then
            local class = ""
            if block.info and block.info ~= "" then
                class = ' class="language-' .. escape_html(block.info) .. '"'
            end
            out[#out + 1] = "<pre><code" .. class .. ">" .. escape_html(block.text) .. "</code></pre>"
        elseif block.type == "list" then
            out[#out + 1] = render_list_html(block)
        elseif block.type == "hr" then
            out[#out + 1] = "<hr>"
        elseif block.type == "blockquote" then
            out[#out + 1] = "<blockquote>" .. render_inline_html(block.text) .. "</blockquote>"
        elseif block.type == "table" then
            local rows = { "<table><thead><tr>" }
            for _, cell in ipairs(block.headers) do
                rows[#rows + 1] = "<th>" .. render_inline_html(cell) .. "</th>"
            end
            rows[#rows + 1] = "</tr></thead><tbody>"
            for _, row in ipairs(block.rows) do
                rows[#rows + 1] = "<tr>"
                for _, cell in ipairs(row) do
                    rows[#rows + 1] = "<td>" .. render_inline_html(cell) .. "</td>"
                end
                rows[#rows + 1] = "</tr>"
            end
            rows[#rows + 1] = "</tbody></table>"
            out[#out + 1] = table.concat(rows)
        end
    end
    return table.concat(out)
end

function markdown.to_html(text)
    if text == nil or text == "" then return "" end
    return render_blocks_html(parse_blocks(text))
end

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

local function render_list_text(block, width)
    local out = {}
    for _, item in ipairs(block.items) do
        local marker = item.ordered and "1. " or "- "
        local prefix = string.rep(" ", item.indent) .. marker
        local text = render_inline_text(item.text)
        local available = math.max(20, width - #prefix)
        local wrapped = wrap(text, available)
        out[#out + 1] = prefix .. (wrapped[1] or "")
        for i = 2, #wrapped do
            out[#out + 1] = string.rep(" ", #prefix) .. wrapped[i]
        end
    end
    return table.concat(out, "\n")
end

local function render_blocks_text(blocks, width)
    local out = {}
    for _, block in ipairs(blocks) do
        if block.type == "paragraph" then
            out[#out + 1] = table.concat(wrap(render_inline_text(block.text), width), "\n")
        elseif block.type == "heading" then
            local text = render_inline_text(block.text)
            local underline = block.level == 1 and "=" or (block.level == 2 and "-" or "~")
            out[#out + 1] = text .. "\n" .. string.rep(underline, #text)
        elseif block.type == "code" then
            local code = {}
            for line in (block.text .. "\n"):gmatch("(.-)\n") do
                code[#code + 1] = "    " .. line
            end
            out[#out + 1] = table.concat(code, "\n")
        elseif block.type == "list" then
            out[#out + 1] = render_list_text(block, width)
        elseif block.type == "hr" then
            out[#out + 1] = string.rep("-", math.min(width, 40))
        elseif block.type == "blockquote" then
            local quoted = {}
            for line in (render_inline_text(block.text) .. "\n"):gmatch("(.-)\n") do
                quoted[#quoted + 1] = "> " .. line
            end
            out[#out + 1] = table.concat(quoted, "\n")
        elseif block.type == "table" then
            local widths = {}
            local function prepare(row)
                local cells = {}
                for i, cell in ipairs(row) do
                    cells[i] = render_inline_text(cell)
                    widths[i] = math.max(widths[i] or 0, #cells[i], 1)
                end
                return cells
            end

            local headers = prepare(block.headers)
            local rows = {}
            for _, row in ipairs(block.rows) do
                rows[#rows + 1] = prepare(row)
            end

            local function format_row(cells)
                local out_cells = {}
                for i = 1, #widths do
                    out_cells[i] = string.format("%-" .. widths[i] .. "s", cells[i] or "")
                end
                return "| " .. table.concat(out_cells, " | ") .. " |"
            end

            local out_rows = { format_row(headers) }
            local separator = {}
            for i = 1, #widths do
                separator[i] = string.rep("-", widths[i])
            end
            out_rows[#out_rows + 1] = "| " .. table.concat(separator, " | ") .. " |"
            for _, row in ipairs(rows) do
                out_rows[#out_rows + 1] = format_row(row)
            end
            out[#out + 1] = table.concat(out_rows, "\n")
        end
    end
    return table.concat(out, "\n\n")
end

function markdown.to_text(text, width)
    if text == nil or text == "" then return "" end
    return render_blocks_text(parse_blocks(text), width or 80)
end

return markdown
