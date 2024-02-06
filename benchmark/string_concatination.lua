local benchmark = { n = 1000, iter = 5 }
local words = io.read_lines("benchmark/wordlist.10000.txt")

function benchmark:plus(run)
    local str = ""
    for _, word in ipairs(words) do
        str = str .. word .. ","
    end
end

function benchmark:concat(run)
    local tbl = {}
    for i = 0, self.n do
        for _, word in ipairs(words) do
            tbl[#tbl + 1] = word
        end
    end
    return table.concat(tbl, ",")
end

function benchmark:builder(run)
    local builder = string.builder(75956431)
    for i = 0, self.n do
        for _, word in ipairs(words) do
            builder:add(word, ",")
        end
    end
    return builder:tostring()
end

function benchmark:joiner(run)
    local joiner = string.joiner { delimiter = ',', size = 75956431 }
    for i = 0, self.n do
        for _, word in ipairs(words) do
            joiner:add(word)
        end
    end
    return joiner:tostring()
end

require("benchmark").run(benchmark)
