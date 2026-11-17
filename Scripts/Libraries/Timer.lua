--[[
计时器模块：以帧或以秒为单位触发回调。主循环需每帧调用 timers.Update(dt)。

running 是暂停开关（暂停期间不累计、不触发，实例仍存活）；active 是生存
标记，置 false 后当帧末尾从列表移除（stop 或自然完成都会置它）。
]]

local timers = {
    insts = {}
}

-- 实例方法均返回 self，可链式调用（如 t:pause():restart()）。
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

-- immediate 为 true 时，创建当刻先调用一次 func（计入 count），再进入正常时序。
-- 例：runFrame(func, 60, 3, true) → 立即 1 次，第 60、120 帧各 1 次，共 3 次。

-- 按帧计时：每 interval 帧触发一次，累计 count 次后自动结束（默认 60 帧 / 1 次）。
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

-- 按秒计时：每 interval 秒触发一次，累计 count 次后自动结束（默认 1 秒 / 1 次）。
-- 走 dt 累计，受帧率波动影响比 runFrame 小。
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

-- 按帧的「持续段」计时器：先空等 delay 帧，随后在 during 帧内每帧调用 func，
-- 结束时调用一次 afterfunc（可省略）并自动停止。
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

-- 按秒的「持续段」计时器：语义同 duringFrame，delay / during 以秒为单位并按 dt 累计。
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

-- 推进所有计时器。倒序遍历，这样移除已结束的实例不会打乱尚未处理的下标。
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
