local grid = require "grid"

local nanotime = os.nanotime

local function no_op(bench, run)
end

local function randomseed()
    math.randomseed(1798722399, 2433055865)
end

local function collect_runs(bench)
    local init = {
        before_all = no_op,
        before_each = no_op,
        after_all = no_op,
        after_each = no_op,
    }
    local runs = {}
    for name, func in pairs(bench) do
        if type(func) == 'function' then
            if name:starts_with("before_") or name:starts_with("after_") then
                init[name] = func
            else
                runs[#runs + 1] = { name = name, func = func, iter = {}, factor = 1 }
            end
        end
    end
    table.sort(runs, function(a, b) return a.name < b.name end)
    return init, runs
end

local function before(bench, run, init)
    randomseed()
    init.before_each(bench, run)
    local before = init["before_" .. run.name] or no_op

    randomseed()
    before(bench, run)
end

local function after(bench, run, init)
    local after = init["after_" .. run.name] or no_op
    after(bench, run)
    init.after_each(bench, run)
end

local function do_run(bench, run, i, grd)
    collectgarbage("collect")
    local start_mem = collectgarbage("count")
    local start_time = nanotime()
    run.func(bench, run)
    local end_time = nanotime()
    local end_mem = collectgarbage("count")

    local time = end_time - start_time
    local mem = end_mem - start_mem

    run.iter[i] = { time = time * run.factor, mem = mem * 1024 }
    grd:print_row(i, time * run.factor, mem * 1024)
end

local function calculate_average(run)
    local avg = { time = 0, mem = 0 }
    for _, stat in ipairs(run.iter) do
        avg.time = avg.time + stat.time
        avg.mem = avg.mem + stat.mem
    end
    avg.time = avg.time / #run.iter
    avg.mem = avg.mem / #run.iter

    run.avg = avg
end

local function benchmark(bench, n)
    local init, runs = collect_runs(bench)
    local iter = bench.iter == nil and 3 or bench.iter
    local summary = grid:new {
        { name = "benchmark", align = "left", },
        { name = "time",      align = "right", fixed_width = 20 },
        { name = "memory",    align = "right", fixed_width = 10 },
    }

    collectgarbage("stop")
    collectgarbage("collect")

    randomseed()
    init.before_all(bench)

    for _, run in ipairs(runs) do
        print("running", run.name, iter .. "x", (bench.n and ("n=" .. bench.n) or ""))
        local grd = grid:new {
            { name = "run",    align = "right", fixed_width = 3 },
            { name = "time",   align = "right", fixed_width = 20 },
            { name = "memory", align = "right", fixed_width = 10 },
        }
        grd:print_header()
        --[[
        for i = 1, 3 do
            before(bench, run, init)
            do_run(bench, run, 0, grd)
            after(bench, run, init)
        end
]]
        for i = 1, iter do
            before(bench, run, init)
            do_run(bench, run, i, grd)
            after(bench, run, init)
        end
        calculate_average(run)
        grd:print_row("avg", run.avg.time, run.avg.mem)
        grd:print_last()
        print()

        summary:add_row(run.name, run.avg.time, run.avg.mem)
    end

    init.after_all(bench)

    collectgarbage("restart")

    print "summary"
    print(summary:tostring())
end

return {
    run = benchmark
}
