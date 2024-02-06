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
                runs[#runs + 1] = { name = name, func = func, iter = {} }
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

local function do_run(bench, run, i)
    collectgarbage("collect")
    local start_mem = collectgarbage("count")
    local start_time = nanotime()
    run.func(bench, run)
    local end_time = nanotime()
    local end_mem = collectgarbage("count")

    local time = end_time - start_time
    local mem = end_mem - start_mem

    run.iter[i] = time
    print("", run.name, i, time, mem * 1024)
end

local function print_result(run)
    local sum = 0
    for _, time in ipairs(run.iter) do
        sum = sum + time
    end
    print()
    print("", run.name, "avg", sum / #run.iter)
    print()
end

local function benchmark(bench, n)
    local init, runs = collect_runs(bench)
    local iter = bench.iter == nil and 3 or bench.iter
    collectgarbage("stop")

    randomseed()
    init.before_all(bench)

    for _, run in ipairs(runs) do
        print("running", run.name, iter .. "x", (bench.n and ("n=" .. bench.n) or ""))
        for i = 1, iter do
            before(bench, run, init)
            do_run(bench, run, i)
            after(bench, run, init)
        end
        print_result(run)
    end

    init.after_all(bench)

    collectgarbage("restart")
end

return {
    run = benchmark
}
