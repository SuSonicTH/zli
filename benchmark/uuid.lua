local benchmark = { n = 1000000, iter = 5 }
local uuid = require("uuid")

function benchmark:uuidv4(run)
    local u = uuid.v4()
end

function benchmark:uuidv7(run)
    local u = uuid.v7()
end

require("benchmark").run(benchmark)
