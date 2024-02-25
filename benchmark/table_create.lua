local benchmark = { n = 1000000, iter = 5 }
local rnd = math.random

function benchmark:table(run)
    local tbl = {}
    for _ = 0, self.n do
        tbl[#tbl + 1] = rnd(0)
    end
end

function benchmark:table_create(run)
    local tbl = table.create(self.n, 0)
    for _ = 0, self.n do
        tbl[#tbl + 1] = rnd(0)
    end
end

function benchmark:table_hash(run)
    local tbl = {}
    for _ = 0, self.n do
        tbl[rnd(0)] = true
    end
end

function benchmark:table_create_hash(run)
    local tbl = table.create(0, self.n)
    for _ = 0, self.n do
        tbl[rnd(0)] = true
    end
end

require("benchmark").run(benchmark)
