local function new(start)
    local nanotime = os.nanotime
    local timer = { laps = {} }

    function timer:start()
        self._start = nanotime()
        return timer
    end

    function timer:lap()
        local time = nanotime()
        local laps = self.laps
        local last_lap = #laps
        local start = last_lap > 0 and laps[last_lap] or self._start
        laps[last_lap + 1] = time
        return time - start
    end

    function timer:stop()
        self._stop = nanotime()
        return self._stop - self._start
    end

    function timer:time()
        if self._time then
            return self._stop - self._start
        end
    end

    function timer:elapsed()
        if self._start then
            return nanotime() - self._start
        end
    end

    function timer:lap_elapsed()
        local last_lap = #self.laps
        local start = last_lap > 0 and self.laps[last_lap] or self._start
        return nanotime() - start
    end

    function timer:reset()
        self._start = nil
        self._end = nil
        self.laps = {}
    end

    timer:reset()
    if start then
        return timer:start()
    end
    return timer
end

return {
    new = new
}
