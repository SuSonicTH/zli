-- Line diff used by the prompt diff viewer.
--
-- The engine keeps memory bounded by trimming the common prefix and suffix,
-- then computing an LCS for the remaining lines.  Very large changed regions
-- fall back to a delete-then-insert block instead of allocating a huge matrix.

local M = {}

local max_cells = 250000

function M.split_lines(text)
    text = tostring(text or "")
    if text == "" then return {} end
    local lines = {}
    local start = 1
    while start <= #text do
        local newline = text:find("\n", start, true)
        if newline == nil then
            lines[#lines + 1] = text:sub(start)
            break
        end
        lines[#lines + 1] = text:sub(start, newline - 1)
        start = newline + 1
    end
    return lines
end

local function push(result, tag, old_index, new_index, text)
    result[#result + 1] = {
        tag = tag,
        old_index = old_index,
        new_index = new_index,
        text = text,
    }
end

local function fallback(old_lines, new_lines, old_start, new_start, result)
    for offset, line in ipairs(old_lines) do
        push(result, "delete", old_start + offset - 1, nil, line)
    end
    for offset, line in ipairs(new_lines) do
        push(result, "insert", nil, new_start + offset - 1, line)
    end
end

--- Build a line-aware operation list.
-- Each operation is `{ tag, old_index, new_index, text }` where `tag` is
-- "equal", "insert" or "delete" and absent indices are nil.
function M.diff(old_text, new_text)
    local old_lines = type(old_text) == "table" and old_text or M.split_lines(old_text)
    local new_lines = type(new_text) == "table" and new_text or M.split_lines(new_text)

    local prefix = 0
    while prefix < #old_lines and prefix < #new_lines
        and old_lines[prefix + 1] == new_lines[prefix + 1] do
        prefix = prefix + 1
    end

    local suffix = 0
    while suffix < #old_lines - prefix and suffix < #new_lines - prefix
        and old_lines[#old_lines - suffix] == new_lines[#new_lines - suffix] do
        suffix = suffix + 1
    end

    local result = {}
    for index = 1, prefix do
        push(result, "equal", index, index, old_lines[index])
    end

    local old_middle = {}
    for index = prefix + 1, #old_lines - suffix do
        old_middle[#old_middle + 1] = old_lines[index]
    end
    local new_middle = {}
    for index = prefix + 1, #new_lines - suffix do
        new_middle[#new_middle + 1] = new_lines[index]
    end

    local old_count, new_count = #old_middle, #new_middle
    if old_count == 0 or new_count == 0 then
        fallback(old_middle, new_middle, prefix + 1, prefix + 1, result)
    elseif (old_count + 1) * (new_count + 1) > max_cells then
        fallback(old_middle, new_middle, prefix + 1, prefix + 1, result)
    else
        local table_lcs = {}
        for row = 0, old_count do
            table_lcs[row] = {}
            for column = 0, new_count do
                table_lcs[row][column] = 0
            end
        end
        for row = 1, old_count do
            for column = 1, new_count do
                if old_middle[row] == new_middle[column] then
                    table_lcs[row][column] = table_lcs[row - 1][column - 1] + 1
                else
                    table_lcs[row][column] = math.max(
                        table_lcs[row - 1][column],
                        table_lcs[row][column - 1]
                    )
                end
            end
        end

        local reversed = {}
        local row, column = old_count, new_count
        while row > 0 or column > 0 do
            if row > 0 and column > 0 and old_middle[row] == new_middle[column] then
                reversed[#reversed + 1] = {
                    tag = "equal",
                    old_index = prefix + row,
                    new_index = prefix + column,
                    text = old_middle[row],
                }
                row, column = row - 1, column - 1
            elseif column > 0 and (row == 0 or table_lcs[row][column - 1] >= table_lcs[row - 1][column]) then
                reversed[#reversed + 1] = {
                    tag = "insert",
                    new_index = prefix + column,
                    text = new_middle[column],
                }
                column = column - 1
            else
                reversed[#reversed + 1] = {
                    tag = "delete",
                    old_index = prefix + row,
                    text = old_middle[row],
                }
                row = row - 1
            end
        end
        for index = #reversed, 1, -1 do
            result[#result + 1] = reversed[index]
        end
    end

    for index = 1, suffix do
        local old_index = #old_lines - suffix + index
        local new_index = #new_lines - suffix + index
        push(result, "equal", old_index, new_index, old_lines[old_index])
    end
    return result
end

--- Group changed operations with surrounding context lines.
function M.hunks(ops, context)
    if type(context) ~= "number" or context < 0 then context = 3 end
    context = math.floor(context)
    if #ops == 0 then return {} end

    local keep = {}
    local changed = false
    for index, op in ipairs(ops) do
        if op.tag ~= "equal" then
            changed = true
            for position = math.max(1, index - context), math.min(#ops, index + context) do
                keep[position] = true
            end
        end
    end
    if not changed then return {} end

    local hunks = {}
    local index = 1
    while index <= #ops do
        if not keep[index] then
            index = index + 1
        else
            local first = index
            while index <= #ops and keep[index] do index = index + 1 end
            local last = index - 1
            local lines = {}
            for position = first, last do lines[#lines + 1] = ops[position] end

            local old_index, new_index
            for _, op in ipairs(lines) do
                if op.old_index and old_index == nil then old_index = op.old_index end
                if op.new_index and new_index == nil then new_index = op.new_index end
            end
            -- An inserted-only hunk has no old line of its own; anchor it
            -- immediately after the preceding old line.
            if old_index == nil then
                old_index = 0
                for position = first - 1, 1, -1 do
                    if ops[position].old_index then
                        old_index = ops[position].old_index + 1
                        break
                    end
                end
            end
            if new_index == nil then
                new_index = 0
                for position = first - 1, 1, -1 do
                    if ops[position].new_index then
                        new_index = ops[position].new_index + 1
                        break
                    end
                end
            end

            local old_count, new_count = 0, 0
            for _, op in ipairs(lines) do
                if op.old_index then old_count = old_count + 1 end
                if op.new_index then new_count = new_count + 1 end
            end
            hunks[#hunks + 1] = {
                old_start = old_index,
                old_count = old_count,
                new_start = new_index,
                new_count = new_count,
                lines = lines,
            }
        end
    end
    return hunks
end

function M.stats(ops)
    local added, removed = 0, 0
    for _, op in ipairs(ops) do
        if op.tag == "insert" then added = added + 1 end
        if op.tag == "delete" then removed = removed + 1 end
    end
    return added, removed
end

--- Render a conventional unified diff.
function M.unified(old_text, new_text, options)
    options = options or {}
    local context = options.context or 3
    local old_label = options.old_label or "old"
    local new_label = options.new_label or "new"
    local ops = M.diff(old_text, new_text)
    local hunks = M.hunks(ops, context)
    if #hunks == 0 then return "" end

    local lines = {
        "--- " .. old_label,
        "+++ " .. new_label,
    }
    for _, hunk in ipairs(hunks) do
        lines[#lines + 1] = string.format(
            "@@ -%d,%d +%d,%d @@",
            hunk.old_start, hunk.old_count, hunk.new_start, hunk.new_count
        )
        for _, op in ipairs(hunk.lines) do
            local prefix = op.tag == "insert" and "+" or op.tag == "delete" and "-" or " "
            lines[#lines + 1] = prefix .. op.text
        end
    end
    return table.concat(lines, "\n") .. "\n"
end

return M
