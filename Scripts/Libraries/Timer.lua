--[[

计时器模块：以帧或以秒为单位触发回调。

需要在主循环里每帧调用一次 timers.Update(dt) 来推进所有实例。

每个计时器有两个彼此独立的开关：
  running —— 暂停开关（pause / unpause / togglePause）。暂停期间不累计也不触发，但实例仍然存活。
  active  —— 生存标记。置为 false 后，实例会在当帧末尾从列表里移除并被丢弃
             （手动 stop、或触发次数达到目标而自然结束，都会置它）。

]]

local timers = {
    insts = {}
}

-- 构造一个计时器实例：updateFunc 是每帧推进逻辑，completeCheck 返回 true 表示已经完成。
-- 下面这些实例方法都返回 self，可以链式调用（例如 t:pause():restart()）。
local function createTimer(updateFunc, completeCheck)
    local timer = {
        time = 0,
        count = 0,

        running = true,
        active = true,

        -- 暂停：停止推进，已累计的 time / count 保持不动
        pause = function(self)
            self.running = false
            return self
        end,

        -- 恢复：从暂停处继续，不重置计数
        unpause = function(self)
            self.running = true
            return self
        end,

        -- 在暂停与运行之间切换
        togglePause = function(self)
            self.running = not self.running
            return self
        end,

        isPaused = function(self)
            return not self.running
        end,

        -- 停止并丢弃：置 active = false，当帧末尾被移出列表
        stop = function(self)
            self.active = false
            return self
        end,

        -- 重启：清零进度并重新激活
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

-- 说明：runFrame / runSecond 的第 4 个参数 immediate 为 true 时，
-- 创建计时器的那一刻先调用一次 func（并计入 count），随后才进入正常时序。
-- 例：runFrame(func, 60, 3, true) → 立即触发 1 次，第 60、120 帧各 1 次，共 3 次。

-- 按帧计时：每 interval 帧触发一次 func，累计触发 count 次后自动结束。
-- 默认 60 帧一次、总共 1 次。
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

-- 按秒计时：每 interval 秒触发一次 func，累计触发 count 次后自动结束。
-- 默认 1 秒一次、总共 1 次。走 dt 累计，因此受帧率波动影响比 runFrame 小。
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

-- 按帧的「持续段」计时器：先空等 delay 帧，随后在一段长 during 帧的区间里每帧调用 func，
-- 区间结束时调用一次 afterfunc（可省略）并自动停止。
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

-- 按秒的「持续段」计时器：语义同 duringFrame，只是 delay / during 以秒为单位、按 dt 累计。
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
