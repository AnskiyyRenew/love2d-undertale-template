local timer = {}

-- 内部函数：创建wait相关功能
local function createWaitFunction(t)
    local wait = function(seconds)
        t.delay = seconds or 0
        t.time = 0
        coroutine.yield()
    end
    
    -- 帧等待（假设60FPS）
    wait.frame = function(frames)
        frames = frames or 1
        t.delay = frames * (1/60)
        t.time = 0
        coroutine.yield()
    end
    
    -- 条件等待（每帧检查条件）
    wait.ntl = function(condition)
        while not condition() do
            t.delay = 0.016
            t.time = 0
            coroutine.yield()
        end
    end
    
    return wait
end

-- 分组存储和性能监控表
timer.groups = {}
timer.lastUpdateTime = 0

---创建可等待的块函数
---@param func function 包含wait调用的函数
---@param name? string 定时器名称（用于调试）
---@param groupName? string 分组名称
---@return table 定时器对象
function timer.CreateBlock(func, name, groupName)
    -- 参数验证
    if type(func) ~= "function" then
        error("timer.CreateBlock: 参数必须是一个函数")
    end

    local t = {
        active = true,
        time = 0,
        delay = 0,
        co = nil,
        name = name or "anonymous",
        originalFunc = func, -- 存储原始函数用于重启
        group = groupName,
        coroutineTime = 0 -- 记录协程执行时间
    }

    local wait = createWaitFunction(t)

    -- 协程包装函数，添加错误处理
    local co_func = function()
        _G.wait = wait
        local ok, err = pcall(func)
        _G.wait = nil
        
        if not ok then
            print(string.format("定时器执行错误 (%s): %s", t.name, tostring(err)))
            t.active = false
        end
    end

    t.co = coroutine.create(co_func)

    -- 定时器执行函数
    t.func = function()
        if not t.active then return end
        
        local coroutineStart = os.clock()
        local success, err = coroutine.resume(t.co)
        t.coroutineTime = os.clock() - coroutineStart
        
        if not success then
            print(string.format("协程错误 (%s): %s", t.name, tostring(err)))
            t.active = false
        elseif coroutine.status(t.co) == "dead" then
            t.active = false
        end
    end

    t.func() -- 立即执行第一次

    setmetatable(t, {__index = timer})
    table.insert(timer, t)
    
    -- 分组管理
    if groupName then
        timer.groups[groupName] = timer.groups[groupName] or {}
        table.insert(timer.groups[groupName], t)
    end
    
    return t
end

---停止定时器
function timer:Stop()
    self.active = false
end

---恢复定时器
function timer:Resume()
    self.active = true
end

---重启定时器（重新开始执行）
function timer:Restart()
    self.active = true
    self.time = 0
    self.delay = 0
    if self.co and coroutine.status(self.co) ~= "dead" then
        local wait = createWaitFunction(self)
        local co_func = function()
            _G.wait = wait
            self.originalFunc()
            _G.wait = nil
        end
        self.co = coroutine.create(co_func)
        self.func()
    end
end

---检查定时器是否活跃
function timer:IsActive()
    return self.active
end

---获取定时器进度（0-1）
function timer:GetProgress()
    if self.delay == 0 then return 1 end
    return math.min(self.time / self.delay, 1)
end

---停止指定分组的所有定时器
function timer.StopGroup(groupName)
    if timer.groups[groupName] then
        for _, t in ipairs(timer.groups[groupName]) do
            t:Stop()
        end
    end
end

---恢复指定分组的所有定时器
function timer.ResumeGroup(groupName)
    if timer.groups[groupName] then
        for _, t in ipairs(timer.groups[groupName]) do
            t:Resume()
        end
    end
end

---清理无效的定时器引用
function timer.Cleanup()
    -- 清理分组中的无效引用
    for groupName, group in pairs(timer.groups) do
        for i = #group, 1, -1 do
            if not group[i].active then
                table.remove(group, i)
            end
        end
        if #group == 0 then
            timer.groups[groupName] = nil
        end
    end
end

---获取调试信息
function timer.GetDebugInfo()
    local activeCount = 0
    for i, t in ipairs(timer) do
        if t.active then
            activeCount = activeCount + 1
        end
    end
    
    return {
        activeTimers = activeCount,
        totalTimers = #timer,
        lastUpdateTime = timer.lastUpdateTime,
        groupCount = table.count(timer.groups) or 0
    }
end

---主更新函数，需要在游戏循环中每帧调用
---@param dt number 帧间隔时间（秒）
function timer.Update(dt)
    local startTime = os.clock()
    
    for i = #timer, 1, -1 do
        local t = timer[i]
        if t.active then
            t.time = t.time + dt
            if t.time >= t.delay then
                t.func()
            end
        else
            table.remove(timer, i)
        end
    end
    
    timer.lastUpdateTime = os.clock() - startTime
    timer.Cleanup() -- 每帧自动清理
end

-- 辅助函数：计算表中元素数量
function table.count(t)
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count
end

return timer