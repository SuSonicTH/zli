local benchmark = { n = 10000, iter = 5 }
local rnd = math.random

function benchmark:table_sort(run)
    local tbl = {}
    for _ = 0, self.n do
        tbl[#tbl + 1] = tostring(rnd(0))
    end
    table.sort(tbl)
end

function benchmark:insert_sorted(run)
    local tbl = {}
    local insert_sorted = table.insert_sorted
    for _ = 0, self.n do
        insert_sorted(tbl, tostring(rnd(0)))
    end
end

require("benchmark").run(benchmark)
