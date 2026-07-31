local benchmark = { n = 10000000, iter = 5 }
local uuid = require("uuid")

function benchmark:uuidv4(run)
    for _ = 0, self.n do
        local u = uuid.v4()
    end
end

function benchmark:uuidv7(run)
    for _ = 0, self.n do
        local u = uuid.v7()
    end
end

require("benchmark").run(benchmark)
