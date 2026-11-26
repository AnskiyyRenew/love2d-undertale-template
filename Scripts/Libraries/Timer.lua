--- Timer module: fires callbacks per frame or per second. The main loop must call timers.Update(dt) every frame.

local timers = {
    insts = {}
}

--- Instance methods return self, so calls chain (e.g. t:pause():restart()).
---@param updateFunc function Per-frame advance of this timer.
---@param completeCheck function|nil Returns true once the timer has run its course.
---@return table
local function createTimer(updateFunc, completeCheck)
    local timer = {
        time = 0,
        count = 0,

        running = true,
        active = true,

        pause = function(self)
            self.running = false
            return self
        end,

        unpause = function(self)
            self.running = true
            return self
        end,

        togglePause = function(self)
            self.running = not self.running
            return self
        end,

        isPaused = function(self)
            return not self.running
        end,

        stop = function(self)
            self.active = false
            return self
        end,

        restart = function(self)
            self.time = 0
            self.count = 0
            self.running = true
            self.active = true
            return self
        end,

        update = updateFunc,

        checkComplete = completeCheck
    }

    return timer
end

--- Frame-based timer: fires every `interval` frames, `count` times in total, then stops.
---@param func function
---@param interval number|nil Frames between two calls; 60 when omitted.
---@param count number|nil Total number of calls; 1 when omitted.
---@param immediate boolean|nil Fire once on creation and count it against `count`.
---@return table
function timers.runFrame(func, interval, count, immediate)
    local timer = createTimer(
        function(self, dt)
            self.time = self.time + 1
            if (self.time >= self.interval and self.count < self.target) then
                func()
                self.count = self.count + 1
                self.time = 0
            end
        end,
        function(self)
            return self.count >= self.target
        end
    )

    timer.interval = (interval or 60)
    timer.target = (count or 1)

    if immediate and timer.count < timer.target then
        func()
        timer.count = timer.count + 1
    end

    table.insert(timers.insts, timer)
    return timer
end

--- Second-based timer: fires every `interval` seconds, `count` times in total, then stops.
--- Counts with dt, so frame-rate spikes disturb it less than runFrame.
---@param func function
---@param interval number|nil Seconds between two calls; 1.0 when omitted.
---@param count number|nil Total number of calls; 1 when omitted.
---@param immediate boolean|nil Fire once on creation and count it against `count`.
---@return table
function timers.runSecond(func, interval, count, immediate)
    local timer = createTimer(
        function(self, dt)
            self.time = self.time + dt
            if (self.time >= self.interval and self.count < self.target) then
                func()
                self.count = self.count + 1
                self.time = 0
            end
        end,
        function(self)
            return self.count >= self.target
        end
    )

    timer.interval = (interval or 1.0)
    timer.target = (count or 1)

    if immediate and timer.count < timer.target then
        func()
        timer.count = timer.count + 1
    end

    table.insert(timers.insts, timer)
    return timer
end

--- Frame-based span timer: idles for `delay` frames, calls func every frame for `during` frames,
--- then calls afterfunc once (optional) and stops.
---@param func function
---@param delay number|nil Idle frames before the span starts.
---@param during number|nil Length of the span in frames.
---@param afterfunc function|nil Called once when the span ends.
---@return table
function timers.duringFrame(func, delay, during, afterfunc)
    local timer = createTimer(
        function(self, dt)
            if self.isFinished then
                return
            end

            self.time = self.time + 1

            if self.time >= delay and not self.isDuring then
                self.isDuring = true
                self.time = 0
            end

            if self.isDuring and self.time <= during then
                func()
                self.count = self.count + 1
            end

            if self.isDuring and self.time >= during then
                self.isFinished = true
                if afterfunc then
                    afterfunc()
                end
                self.running = false
                self.active = false
            end
        end,
        function(self)
            return self.isFinished
        end
    )

    timer.delay = delay or 0
    timer.during = during or 1
    timer.isDuring = false
    timer.isFinished = false

    table.insert(timers.insts, timer)
    return timer
end

--- Second-based span timer: same semantics as duringFrame, with delay / during in seconds and counted by dt.
---@param func function
---@param delay number|nil Idle seconds before the span starts.
---@param during number|nil Length of the span in seconds.
---@param afterfunc function|nil Called once when the span ends.
---@return table
function timers.duringSecond(func, delay, during, afterfunc)
    local timer = createTimer(
        function(self, dt)
            if self.isFinished then
                return
            end

            self.time = self.time + dt

            if self.time >= delay and not self.isDuring then
                self.isDuring = true
                self.time = 0
            end

            if self.isDuring and self.time <= during then
                func()
                self.count = self.count + 1
            end

            if self.isDuring and self.time >= during then
                self.isFinished = true
                if afterfunc then
                    afterfunc()
                end
                self.running = false
                self.active = false
            end
        end,
        function(self)
            return self.isFinished
        end
    )

    timer.delay = delay or 0
    timer.during = during or 1
    timer.isDuring = false
    timer.isFinished = false

    table.insert(timers.insts, timer)
    return timer
end

--- Advances every timer. Iterates backwards so removing a finished instance
--- cannot shift the indices that are still to come.
---@param dt number
function timers.Update(dt)
    for i = #timers.insts, 1, -1
    do
        local t = timers.insts[i]

        if t.checkComplete and t:checkComplete() then
            t.active = false
        end

        if (t.running and t.active) then
            t:update(dt)
        end

        if not t.active then
            table.remove(timers.insts, i)
        end
    end
end

return timers
