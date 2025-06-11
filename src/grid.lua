local grid = {}

local border = {
    top = { left = '┌', center = '┬', right = '┐' },
    center = { left = '├', center = '┼', right = '┤' },
    bottom = { left = '└', center = '┴', right = '┘' },
    horizontal = '─',
    vertical = '│',
}

local config_default = {
    show_header = true,
    padding = true,
}

local column_default = {
    align = 'left',
    min_width = 1,
    max_width = 30,
}

local grid_mt

local function update_with(widths, max_widths, i, value)
    local len = #value
    if len > widths[i] then
        if len < max_widths[i] then
            widths[i] = len
        else
            widths[i] = max_widths[i]
        end
    end
end

function grid:new(config, rows)
    config = table.default(config, config_default)
    local obj = setmetatable({
        show_header = config.show_header,
        padding = config.padding,
        align = {},
        name_map = {},
        header = {},
        widths = {},
        max_width = {},
        rows = {}
    }, grid_mt)

    for i, col in ipairs(config) do
        col = table.default(col, column_default)
        if col.fixed_width then
            obj.widths[i] = col.fixed_width
            obj.max_width[i] = col.fixed_width
        else
            obj.widths[i] = col.min_width
            obj.max_width[i] = col.max_width
        end

        obj.align[i] = col.align

        if col.name then
            obj.header[i] = col.name
            obj.name_map[col.name] = i
            if obj.show_header then
                update_with(obj.widths, obj.max_width, i, col.name)
            end
        end
    end

    if rows then
        obj:add_rows(rows)
    end

    return obj
end

function grid:add_rows(rows)
    for _, row in ipairs(rows) do
        self:add_row(row)
    end
end

local function columns_from_arg(...)
    local row = { ... }
    if type(row[1]) == 'table' then
        row = row[1]
    end
    local columns = {}
    for i, value in ipairs(row) do
        columns[i] = tostring(value)
    end
    return columns
end

function grid:add_row(...)
    local columns = columns_from_arg(...)
    for i, value in ipairs(columns) do
        update_with(self.widths, self.max_width, i, value)
    end
    self.rows[#self.rows + 1] = columns
end

local function borders(self, border)
    return table.concat { border.left, table.concat(self.lines, border.center), border.right }
end

local function padd(self, align, values)
    local row = {}
    for i, value in ipairs(values) do
        if align[i] == nil or align[i] == 'left' then
            row[i] = (value .. self.spaces[i]):sub(1, self.widths[i])
        else
            row[i] = (self.spaces[i] .. value):sub(-self.widths[i])
        end
    end
    return table.concat { border.vertical, self.padd, table.concat(row, self.vertical), self.padd, border.vertical }
end

local function calculate_templates(self)
    local spaces = {}
    local lines = {}
    local extra_padd = self.padding and 2 or 0

    for i, width in ipairs(self.widths) do
        spaces[i] = string.rep(" ", width)
        lines[i] = string.rep(border.horizontal, width + extra_padd)
    end

    self.spaces = spaces
    self.lines = lines
    self.padd = (self.padding and ' ' or '')
    self.vertical = self.padd .. border.vertical .. self.padd
end


function grid:get_header()
    local tbl = {}
    calculate_templates(self)
    tbl[1] = borders(self, border.top)
    if self.show_header then
        tbl[2] = padd(self, {}, self.header)
    end
    return tbl
end

function grid:row(...)
    local row = columns_from_arg(...)
    local tbl = {}
    if not self.spaces then
        table.add_all(tbl, self:get_header())
    end
    tbl[#tbl + 1] = borders(self, border.center)
    tbl[#tbl + 1] = padd(self, self.align, row)
    return tbl
end

function grid:header_string()
    return table.concat(self:get_header(), "\n")
end

function grid:row_string(...)
    return table.concat(self:row(...), "\n")
end

function grid:last_string()
    return borders(self, border.bottom)
end

function grid:print_header()
    print(self:header_string())
end

function grid:print_row(...)
    print(self:row_string(...))
end

function grid:print_last()
    return print(self:last_string())
end

function grid:tostring()
    local tbl = {}
    for _, row in ipairs(self.rows) do
        table.add_all(tbl, self:row(row, self.align))
    end
    tbl[#tbl + 1] = self:last_string()
    return table.concat(tbl, "\n")
end

grid_mt = {
    __index = grid,
    __tostring = grid.toString,
}

return {
    new = grid.new
}
