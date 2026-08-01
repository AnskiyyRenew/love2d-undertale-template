local timers = {
    insts = {}
}

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

function timers.runFrame(func, interval, count)
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

    table.insert(timers.insts, timer)
    return timer
end

function timers.runSecond(func, interval, count)
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

    table.insert(timers.insts, timer)
    return timer
end

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