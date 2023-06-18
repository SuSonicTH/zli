local cl

local function print_centered_at(row, text)
    local dim = cl.screen.dimentions()
    cl.cursor.set(math.floor((dim.x - #text) / 2), row)
    print(text)
end

local function print_centered(text)
    local dim = cl.screen.dimentions()
    local pos = cl.cursor.get()
    cl.cursor.set(math.floor((dim.x - #text) / 2), pos.y)
    print(text)
end

return function(crossline)
    cl = crossline
    crossline.print_centered_at = print_centered_at
    crossline.print_centered = print_centered
end
