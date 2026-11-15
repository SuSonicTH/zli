-- Multi-step form built from `prompt.form` pages.
--
-- Steps are form pages with optional `validate(values)` and `skip(values)`
-- callbacks.  Values are merged across steps and survive moving backwards.
-- `review = true` adds an automatically generated summary page before the
-- final submit.

local config = require "prompt.config"
local form = require "prompt.form"
local input = require "prompt.input"
local render = require "prompt.render"
local scroll = require "prompt.scroll"
local steps_mod = require "prompt.steps"
local theme_mod = require "prompt.theme"

local M = {}

local function is_ctrl_enter(event)
    if not event or event.type ~= "key" then return false end
    if event.code == "enter" and event.control then return true end
    if event.code == "char" and event.control then
        return event.char == "\r" or event.char == "\n"
    end
    return false
end

local function is_alt_left(event)
    return event and event.type == "key" and event.code == "left" and event.alt == true
end

local function copy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local result = {}
    seen[value] = result
    for key, item in pairs(value) do result[copy(key, seen)] = copy(item, seen) end
    return result
end

local function equal(left, right, seen)
    if left == right then return true end
    if type(left) ~= "table" or type(right) ~= "table" then return false end
    seen = seen or {}
    if seen[left] == right then return true end
    seen[left] = right
    for key, value in pairs(left) do
        if not equal(value, right[key], seen) then return false end
    end
    for key in pairs(right) do
        if left[key] == nil then return false end
    end
    return true
end

local function display(spec, value, seen)
    if spec.type == "password" then
        return require("prompt.text").summary_value(nil, tostring(value or ""), "*")
    end
    if type(value) == "table" then
        seen = seen or {}
        if seen[value] then return "{...}" end
        seen[value] = true
        if #value > 0 then
            local parts = {}
            for index, item in ipairs(value) do
                parts[index] = display({}, item, seen)
            end
            return table.concat(parts, ", ")
        end
        local dates = require "prompt.dates"
        local function number(name)
            local item = value[name]
            if type(item) == "number" and item % 1 == 0 then return item end
            return nil
        end
        local year, month, day = number("year"), number("month"), number("day")
        local hour, min, sec = number("hour"), number("min"), number("sec")
        if year and month and day and dates.valid(year, month, day) then
            if hour and min then
                return dates.format_datetime({
                    year = year, month = month, day = day, hour = hour, min = min, sec = sec,
                }, sec ~= nil)
            end
            return dates.format_date(value)
        end
        if hour and min and sec == nil then
            return dates.format_time({ hour = hour, min = min }, false)
        end
        if hour and min and sec then
            return dates.format_time({ hour = hour, min = min, sec = sec }, true)
        end
        local parts = {}
        for key, item in pairs(value) do
            if type(key) == "string" then
                parts[#parts + 1] = key .. "=" .. display({}, item, seen)
            end
        end
        table.sort(parts)
        return "{" .. table.concat(parts, ", ") .. "}"
    end
    if value == nil then return "" end
    return tostring(value)
end

local function validate_options(options)
    if type(options) ~= "table" then
        error("prompt.wizard: expecting an options table", 3)
    end
    if type(options.steps) ~= "table" or #options.steps == 0 then
        error("prompt.wizard: steps must be a non-empty table", 3)
    end
    if options.title ~= nil and type(options.title) ~= "string" then
        error("prompt.wizard: title must be a string", 3)
    end
    if options.values ~= nil and type(options.values) ~= "table" then
        error("prompt.wizard: values must be a table", 3)
    end
    if options.review ~= nil and type(options.review) ~= "boolean" then
        error("prompt.wizard: review must be a boolean", 3)
    end
    if options.submit ~= nil and type(options.submit) ~= "string" then
        error("prompt.wizard: submit must be a string", 3)
    end
    local seen_fields = {}
    for index, step in ipairs(options.steps) do
        if type(step) ~= "table" then
            error("prompt.wizard: step " .. index .. " must be a table", 3)
        end
        if type(step.fields) ~= "table" or #step.fields == 0 then
            error("prompt.wizard: step " .. index .. " needs fields", 3)
        end
        if step.title ~= nil and type(step.title) ~= "string" then
            error("prompt.wizard: step " .. index .. " title must be a string", 3)
        end
        if step.validate ~= nil and type(step.validate) ~= "function" then
            error("prompt.wizard: step " .. index .. " validate must be a function", 3)
        end
        if step.skip ~= nil and type(step.skip) ~= "function" then
            error("prompt.wizard: step " .. index .. " skip must be a function", 3)
        end
        for _, spec in ipairs(form._normalize_fields(step.fields)) do
            if seen_fields[spec.name] then
                error("prompt.wizard: duplicate field name '" .. spec.name
                    .. "' across steps", 3)
            end
            seen_fields[spec.name] = true
        end
    end
end

local function step_title(step, index)
    return step.title or ("Step " .. index)
end

function M.__call(_, options)
    validate_options(options)
    local steps = options.steps
    local titles = {}
    for index, step in ipairs(steps) do titles[index] = step_title(step, index) end

    local start_values = copy(options.values or {})

    if not config.is_interactive() then
        local values = copy(start_values)
        local collected = {}
        for index, step in ipairs(steps) do
            if not (step.skip and step.skip(copy(values))) then
                io.write(titles[index] .. "\n")
                local answers, message = form._prompt_fields(step.fields, values)
                if answers == nil then return nil, message end
                collected[index] = answers
                for name, value in pairs(answers) do values[name] = value end
                if step.validate then
                    local ok, problem = step.validate(values)
                    if ok == false or (ok == nil and problem ~= nil) then
                        problem = tostring(problem or "Invalid values.")
                        io.write(problem .. "\n")
                        return nil, problem
                    end
                end
            end
        end

        -- Re-evaluate the visible steps from the collected answers so the
        -- review block and returned table match the interactive result: a step
        -- skipped by a later answer is not shown and its fields are dropped.
        local progressive = copy(start_values)
        local result = copy(start_values)
        local visible = {}
        for index, step in ipairs(steps) do
            if not (step.skip and step.skip(copy(progressive))) then
                visible[index] = true
                local answers = collected[index]
                for _, spec in ipairs(form._normalize_fields(step.fields)) do
                    local value = answers and answers[spec.name]
                    if value ~= nil then
                        progressive[spec.name] = value
                        result[spec.name] = value
                    end
                end
            end
        end

        if options.review then
            io.write("Review\n")
            for index, step in ipairs(steps) do
                if visible[index] then
                    for _, spec in ipairs(form._normalize_fields(step.fields)) do
                        io.write(string.format("%s: %s\n",
                            spec.message, display(spec, result[spec.name])))
                    end
                end
            end
        end
        return result
    end

    -- Pages are built on demand so an initially skipped step never constructs
    -- components whose options would only matter when the step is shown.
    local pages = {}
    local function ensure_page(index)
        local page = pages[index]
        if page then return page end
        local step = steps[index]
        page = form.new_page {
            title = step_title(step, index),
            fields = step.fields,
            values = start_values,
        }
        pages[index] = page
        return page
    end

    local state = {
        current = 1,
        review = false,
        footer = nil,
        confirm_cancel = false,
        review_scroll = scroll.new { rows = 1, height = 1 },
    }
    local theme = theme_mod.build()
    local baseline

    --- Evaluate skip callbacks in step order.
    -- Each callback sees the values collected from earlier non-skipped steps,
    -- which is the same snapshot the plain-text path provides.  The second
    -- return value is the merged table for the visible steps.
    local function skip_map()
        local map = {}
        local values = copy(start_values)
        for index = 1, #steps do
            local step = steps[index]
            local skip = step.skip ~= nil and step.skip(copy(values)) and true or false
            map[index] = skip
            if not skip then
                local page = ensure_page(index)
                for name, value in pairs(page:values()) do values[name] = value end
            end
        end
        return map, values
    end

    --- Values collected through `index`, matching the plain-text path.
    local function merged_until(index)
        local values = copy(start_values)
        for position = 1, math.min(index, #steps) do
            local step = steps[position]
            local skip = step.skip ~= nil and step.skip(copy(values)) and true or false
            if not skip then
                local page = ensure_page(position)
                for name, value in pairs(page:values()) do values[name] = value end
            end
        end
        return values
    end

    local function merged()
        local _, values = skip_map()
        return values
    end

    local function commit_fields(skip_password)
        local ok = true
        for index = 1, #steps do
            local page = pages[index]
            if page then
                if not page:commit_fields(skip_password) then ok = false end
            end
        end
        return ok
    end

    local function clear_errors()
        for index = 1, #steps do
            local page = pages[index]
            if page then
                for _, entry in ipairs(page.entries) do entry.field.error = nil end
            end
        end
    end

    -- Build the visible pages, normalize their defaults, then take the
    -- baseline without showing errors for untouched fields.
    skip_map()
    commit_fields(true)
    clear_errors()
    baseline = copy(merged())

    local function next_visible(from)
        local map = skip_map()
        for index = from + 1, #steps do
            if not map[index] then return index end
        end
        return nil
    end

    local function previous_visible(from)
        local map = skip_map()
        for index = from - 1, 1, -1 do
            if not map[index] then return index end
        end
        return nil
    end

    local function last_visible()
        local map = skip_map()
        for index = #steps, 1, -1 do
            if not map[index] then return index end
        end
        return nil
    end

    local first_visible = next_visible(0)
    if first_visible then
        state.current = first_visible
    elseif options.review then
        state.review = true
    else
        for index = 1, #steps do
            if pages[index] then pages[index]:close() end
        end
        return merged()
    end

    local function validate_all()
        for index = 1, #steps do
            -- Commit the page first: a new value can change later skip results.
            local map = skip_map()
            if not map[index] then
                local page = ensure_page(index)
                if not page:validate() then
                    state.current = index
                    state.review = false
                    state.footer = nil
                    return false
                end
                map = skip_map()
                if not map[index] then
                    local step = steps[index]
                    if step.validate then
                        local ok, problem = step.validate(merged_until(index))
                        if ok == false or (ok == nil and problem ~= nil) then
                            state.current = index
                            state.review = false
                            state.footer = tostring(problem or "Invalid values.")
                            return false
                        end
                    end
                end
            end
        end
        return true
    end

    local function enter_review()
        state.review = true
        state.footer = nil
        state.review_scroll:reset()
    end

    local function submit()
        if not validate_all() then return "continue" end
        state.footer = nil
        return "submit", merged()
    end

    local function advance()
        local map = skip_map()
        if not map[state.current] then
            local page = ensure_page(state.current)
            if not page:validate() then
                state.footer = nil
                return "continue"
            end
            local step = steps[state.current]
            if step.validate then
                local ok, problem = step.validate(merged_until(state.current))
                if ok == false or (ok == nil and problem ~= nil) then
                    state.footer = tostring(problem or "Invalid values.")
                    return "continue"
                end
            end
        end
        state.footer = nil
        local next_index = next_visible(state.current)
        if next_index then
            state.current = next_index
            return "continue"
        end
        if options.review then
            enter_review()
            return "continue"
        end
        return submit()
    end

    local function go_back()
        state.footer = nil
        state.confirm_cancel = false
        if state.review then
            local previous = last_visible()
            if previous then
                state.review = false
                state.current = previous
            end
            return "continue"
        end
        local previous = previous_visible(state.current)
        if previous then state.current = previous end
        return "continue"
    end

    local function dirty()
        commit_fields(true)
        return not equal(merged(), baseline)
    end

    local function enter_ctrl()
        if not validate_all() then return "continue" end
        if options.review and not state.review then
            enter_review()
            return "continue"
        end
        state.footer = nil
        return "submit", merged()
    end

    local function review_lines()
        local body = {}
        body[#body + 1] = render.line(render.span("Review", "title"))
        local map = skip_map()
        for index = 1, #steps do
            if not map[index] then
                local page = ensure_page(index)
                body[#body + 1] = render.line(render.span(titles[index], "muted"))
                for _, line in ipairs(page:summary_lines(theme)) do body[#body + 1] = line end
            end
        end
        return body
    end

    local function draw()
        local size = require("term").size() or { columns = 80, rows = 24 }
        local header
        if state.review then
            header = options.title
        else
            local map = skip_map()
            local visible_titles = {}
            local current_position
            for index = 1, #steps do
                if not map[index] then
                    visible_titles[#visible_titles + 1] = titles[index]
                    if index == state.current then current_position = #visible_titles end
                end
            end
            local steps_line = ""
            if #visible_titles > 0 then
                steps_line = steps_mod {
                    steps = visible_titles,
                    current = current_position or 1,
                    width = size.columns,
                }
            end
            if options.title and options.title ~= "" then
                header = options.title .. "  " .. steps_line
            else
                header = steps_line
            end
        end

        local submit = options.submit or "submit"
        local help = "Enter next  Alt+Left back  Ctrl+Enter " .. submit .. "  Esc cancel"
        if state.review then
            help = "Enter " .. submit .. "  Alt+Left back  Up/Down scroll  Esc cancel"
            local body = review_lines()
            local fixed = (header and 1 or 0) + (state.footer and 1 or 0) + 1
            local available = math.max(1, size.rows - fixed - 1)
            local lines = {}
            if header then lines[#lines + 1] = render.line(render.span(header, "title")) end
            state.review_scroll:set_rows(#body)
            state.review_scroll:set_height(available)
            state.review_scroll:clamp()
            local first, last = state.review_scroll:visible()
            for index = first, last do lines[#lines + 1] = body[index] end
            if state.footer then lines[#lines + 1] = require("prompt.field").error_line(state.footer) end
            lines[#lines + 1] = require("prompt.field").help_line(help)
            return render.frame(lines)
        end

        return ensure_page(state.current):draw(nil, theme, {
            header = header,
            footer = state.footer,
            help = help,
        })
    end

    local function handle(event)
        if not event or event.type == "resize" then return "continue" end

        if state.confirm_cancel then
            if input.key(event, "esc") or input.ctrl(event, "c") then return "cancel" end
            state.confirm_cancel = false
            state.footer = nil
            return "continue"
        end

        if input.ctrl(event, "c") then return "cancel" end

        if input.key(event, "esc") then
            if not dirty() then return "cancel" end
            state.confirm_cancel = true
            state.footer = "Discard changes? Press Esc again to cancel."
            return "continue"
        end

        if is_ctrl_enter(event) then return enter_ctrl() end
        if is_alt_left(event) or input.alt_char(event, "b") then return go_back() end

        state.footer = nil

        if state.review then
            if input.key(event, "up") then state.review_scroll:move(-1) return "continue" end
            if input.key(event, "down") then state.review_scroll:move(1) return "continue" end
            if input.key(event, "page_up") then state.review_scroll:page(-1) return "continue" end
            if input.key(event, "page_down") then state.review_scroll:page(1) return "continue" end
            local char = input.printable(event)
            if char == "b" then return go_back() end
            if input.enter(event) then return submit() end
            return "continue"
        end

        local page = ensure_page(state.current)
        local char = input.printable(event)
        if char == "b" and not page:accepts_text() then return go_back() end

        local action = page:handle(event)
        if action == "submit" then return advance() end
        if action == "cancel" then return "cancel" end
        if action == "eof" then return "eof" end
        return "continue"
    end

    local packed = table.pack(xpcall(function()
        return input.run {
            screen = options.screen,
            commit = options.commit,
            frame = draw,
            on_event = handle,
            summary = function()
                return render.status(theme, "success", options.title or options.submit or "done")
            end,
            final_frame = draw,
        }
    end, debug.traceback))
    for index = 1, #steps do
        if pages[index] then pages[index]:close() end
    end
    if not packed[1] then error(packed[2], 0) end
    return table.unpack(packed, 2, packed.n)
end

return setmetatable(M, { __call = function(_, options) return M.__call(M, options) end })
