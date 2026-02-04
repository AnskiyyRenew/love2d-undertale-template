local paths = {}

-- 路径实例管理器
paths.activePaths = {}

-- 路径配置表，存储所有定义的路径
paths.definedPaths = {}

-- 内部用于生成唯一ID（避免用 #table + 1 导致冲突）
paths._nextID = 1

-- 缓动函数库（内置几种常见缓动）
paths.easings = {
    linear = function(t) return t end,
    inQuad = function(t) return t * t end,
    outQuad = function(t) return t * (2 - t) end,
    inOutQuad = function(t)
        t = t * 2
        if t < 1 then return 0.5 * t * t end
        t = t - 1
        return -0.5 * (t * (t - 2) - 1)
    end
}

local function clamp(v, a, b) return math.max(a, math.min(b, v)) end

-- 计算路径点的累积长度查表（用于按进度均匀沿弧长移动）
function paths.BuildLengthLookup(pathPoints)
    if not pathPoints or #pathPoints <= 1 then
        return nil
    end
    if pathPoints.__lengthLookup then
        return pathPoints.__lengthLookup
    end

    local cum = {}
    cum[1] = 0
    local segLengths = {}
    local total = 0
    for i = 1, (#pathPoints - 1) do
        local dx = pathPoints[i + 1].x - pathPoints[i].x
        local dy = pathPoints[i + 1].y - pathPoints[i].y
        local l = math.sqrt(dx * dx + dy * dy)
        segLengths[i] = l
        total = total + l
        cum[i + 1] = total
    end

    local norm = {}
    if total > 0 then
        for i = 1, #cum do
            norm[i] = cum[i] / total
        end
    else
        for i = 1, #cum do norm[i] = 0 end
    end

    local lookup = {
        totalLength = total,
        segLengths = segLengths,
        cum = cum,
        norm = norm
    }
    pathPoints.__lengthLookup = lookup
    return lookup
end

--[[ 创建一条直线路径 ]]
function paths.Line(startPoint, endPoint, pointCount)
    local points = {}
    local dx = endPoint.x - startPoint.x
    local dy = endPoint.y - startPoint.y

    pointCount = pointCount or math.max(math.floor(math.sqrt(dx * dx + dy * dy) / 5), 10)

    for i = 0, pointCount do
        local t = i / pointCount
        local point = {
            x = startPoint.x + dx * t,
            y = startPoint.y + dy * t,
            t = t
        }
        table.insert(points, point)
    end

    paths.BuildLengthLookup(points)
    return points
end

--[[ 贝塞尔生成 ]]
function paths.Bezier(controlPoints, pointCount)
    pointCount = pointCount or 50
    local points = {}

    for i = 0, pointCount do
        local t = i / pointCount
        local point = paths.CalculateBezierPoint(controlPoints, t)
        point.t = t
        table.insert(points, point)
    end

    paths.BuildLengthLookup(points)
    return points
end

function paths.CalculateBezierPoint(controlPoints, t)
    if #controlPoints == 0 then return {x = 0, y = 0} end
    if #controlPoints == 1 then return {x = controlPoints[1].x, y = controlPoints[1].y} end

    local newPoints = {}
    for i = 1, #controlPoints - 1 do
        local x = controlPoints[i].x + (controlPoints[i + 1].x - controlPoints[i].x) * t
        local y = controlPoints[i].y + (controlPoints[i + 1].y - controlPoints[i].y) * t
        table.insert(newPoints, {x = x, y = y})
    end

    return paths.CalculateBezierPoint(newPoints, t)
end

--[[ Catmull-Rom 样条（产生平滑路径） ]]
-- controlPoints: { {x,y}, {x,y}, ... }
-- pointCount: 每段细分数量（总点数大约 = (#controlPoints - (closed?0:2)) * pointCount）
-- closed: 是否闭合（首尾相接）
function paths.CatmullRom(controlPoints, pointCount, closed)
    pointCount = pointCount or 12
    local pts = {}
    local n = #controlPoints
    if n < 2 then return pts end

    local get = function(i)
        if closed then
            local idx = ((i - 1) % n) + 1
            return controlPoints[idx]
        else
            if i < 1 then return controlPoints[1] end
            if i > n then return controlPoints[n] end
            return controlPoints[i]
        end
    end

    -- for each segment between P1->P2 use P0,P1,P2,P3
    local lastSeg = closed and n or (n - 1)
    for i = 1, lastSeg do
        local p0 = get(i - 1)
        local p1 = get(i)
        local p2 = get(i + 1)
        local p3 = get(i + 2)
        for j = 0, pointCount - 1 do
            local t = j / pointCount
            local t2 = t * t
            local t3 = t2 * t
            local x = 0.5 * ((2 * p1.x) + (-p0.x + p2.x) * t + (2*p0.x - 5*p1.x + 4*p2.x - p3.x) * t2 + (-p0.x + 3*p1.x - 3*p2.x + p3.x) * t3)
            local y = 0.5 * ((2 * p1.y) + (-p0.y + p2.y) * t + (2*p0.y - 5*p1.y + 4*p2.y - p3.y) * t2 + (-p0.y + 3*p1.y - 3*p2.y + p3.y) * t3)
            table.insert(pts, {x = x, y = y})
        end
    end

    -- add final point for open curve
    if not closed then
        table.insert(pts, {x = controlPoints[#controlPoints].x, y = controlPoints[#controlPoints].y})
    end

    paths.BuildLengthLookup(pts)
    return pts
end

-- 根据归一化进度（0..1）和查表，返回路径位置（弧长插值）
function paths.GetPathPosition(pathPoints, progress)
    if not pathPoints or #pathPoints == 0 then return nil end
    if #pathPoints == 1 then return {x = pathPoints[1].x, y = pathPoints[1].y} end

    progress = clamp(progress, 0, 1)
    local lookup = pathPoints.__lengthLookup or paths.BuildLengthLookup(pathPoints)

    if not lookup or lookup.totalLength == 0 then
        return {x = pathPoints[1].x, y = pathPoints[1].y}
    end

    local target = progress * lookup.totalLength

    local i = 1
    while i <= #pathPoints - 1 and lookup.cum[i + 1] < target do
        i = i + 1
    end

    if i >= #pathPoints then
        return {x = pathPoints[#pathPoints].x, y = pathPoints[#pathPoints].y}
    end

    local segStart = lookup.cum[i]
    local segLen = lookup.segLengths[i]
    local segT = 0
    if segLen > 0 then
        segT = (target - segStart) / segLen
        segT = clamp(segT, 0, 1)
    end

    local x = pathPoints[i].x + (pathPoints[i + 1].x - pathPoints[i].x) * segT
    local y = pathPoints[i].y + (pathPoints[i + 1].y - pathPoints[i].y) * segT

    return {x = x, y = y}
end

---将对象绑定到路径
-- 兼容旧签名： (object, pathPoints, duration, easing, loop)
-- 新： durationOrOptions 可以是 number（duration），也可以是 table:
--   {
--     duration = number (秒) 或 nil,
--     speed = number (像素/秒) 或 nil,  -- 若提供 speed 则按 speed 驱动（优先）
--     easing = string|function,
--     loop = boolean,
--     pingpong = boolean, -- 循环时是否来回
--     reverse = boolean,  -- 是否从终点往回走
--     offset = number(0..1) -- 起始进度
--   }
function paths.BindPath(object, pathPoints, durationOrOptions, easingOrNil, loopOrNil)
    if type(object) ~= "table" or type(object.x) ~= "number" or type(object.y) ~= "number" then
        error("paths.BindPath: object 必须是包含 number 字段 x 和 y 的表")
    end
    if type(pathPoints) ~= "table" or #pathPoints == 0 then
        error("paths.BindPath: pathPoints 必须为非空表")
    end

    -- 处理兼容参数
    local opts = {}
    if type(durationOrOptions) == "table" then
        for k, v in pairs(durationOrOptions) do opts[k] = v end
        -- 如果 easing 在第二个参数（旧风格），不要覆盖
        if easingOrNil ~= nil and opts.easing == nil then
            opts.easing = easingOrNil
        end
    else
        opts.duration = tonumber(durationOrOptions) or 0
        opts.easing = easingOrNil
        opts.loop = loopOrNil
    end

    -- 处理 easing
    local easingFunc
    if type(opts.easing) == "string" then
        easingFunc = paths.easings[opts.easing] or paths.easings.linear
    elseif type(opts.easing) == "function" then
        easingFunc = opts.easing
    else
        easingFunc = paths.easings.linear
    end

    -- build lookup
    local lookup = paths.BuildLengthLookup(pathPoints)
    local totalLength = lookup and lookup.totalLength or 0

    -- 如果使用速度（px/s）
    local useSpeed = false
    local speed = tonumber(opts.speed)
    if speed and speed > 0 then
        useSpeed = true
    end

    -- 若既无 speed 也无 duration，默认 duration 为 1 秒（防止 0 导致问题）
    local duration = tonumber(opts.duration) or 0
    if not useSpeed and duration <= 0 then
        duration = 1
    end

    -- 如果使用 speed 且路径长度>0，则计算 duration
    if useSpeed then
        if totalLength > 0 then
            duration = totalLength / speed
        else
            -- 长度为 0，立即完成
            duration = 0
        end
    end

    local id = paths._nextID
    paths._nextID = paths._nextID + 1

    local offset = clamp(tonumber(opts.offset) or 0, 0, 1)
    local reverse = opts.reverse and true or false
    local pingpong = opts.pingpong and true or false
    local loop = opts.loop and true or false

    -- direction: 1 正向从0->1, -1 反向从1->0
    local direction = reverse and -1 or 1
    local initialProgress = offset
    if reverse then
        initialProgress = 1 - offset
    end

    local pathInstance = {
        id = id,
        object = object,
        pathPoints = pathPoints,
        duration = duration,
        easing = easingFunc,
        loop = loop,
        pingpong = pingpong,
        direction = direction,
        currentTime = initialProgress * duration,
        progress = initialProgress,
        active = true,
        paused = false,
        onComplete = nil,
        onUpdate = nil,
        useSpeed = useSpeed,
        speed = speed
    }

    -- duration == 0: 立即跳到目标（处理 reverse/offset）
    if duration == 0 then
        local finalP = (direction == 1) and 1 or 0
        local pos = paths.GetPathPosition(pathPoints, finalP)
        if pos then
            object.x = pos.x
            object.y = pos.y
        end
        pathInstance.progress = finalP
        pathInstance.active = false
        paths.activePaths[id] = pathInstance
        if pathInstance.onComplete then
            pcall(pathInstance.onComplete, object, pathInstance)
        end
        paths.activePaths[id] = nil
        return id
    end

    paths.activePaths[id] = pathInstance
    return id
end

-- 启动/重置路径移动
function paths.StartPath(pathID)
    local pathInstance = paths.activePaths[pathID]
    if pathInstance then
        pathInstance.active = true
        pathInstance.paused = false
        -- 不重置进度（若需要完全重置可手动设置 currentTime/progress 或 Stop 再 Bind）
    end
end

function paths.PausePath(pathID)
    local pathInstance = paths.activePaths[pathID]
    if pathInstance then
        pathInstance.paused = true
        pathInstance.active = false
    end
end

function paths.ResumePath(pathID)
    local pathInstance = paths.activePaths[pathID]
    if pathInstance then
        pathInstance.paused = false
        pathInstance.active = true
    end
end

function paths.StopPath(pathID)
    if paths.activePaths[pathID] then
        paths.activePaths[pathID] = nil
    end
end

function paths.SetCompleteCallback(pathID, callback)
    local pathInstance = paths.activePaths[pathID]
    if pathInstance then
        pathInstance.onComplete = callback
    end
end

function paths.SetUpdateCallback(pathID, callback)
    local pathInstance = paths.activePaths[pathID]
    if pathInstance then
        pathInstance.onUpdate = callback
    end
end

-- 反向当前路径（在运行中也可用）
function paths.SetReverse(pathID, rev)
    local p = paths.activePaths[pathID]
    if not p then return end
    rev = rev and true or false
    if rev and p.direction == 1 then
        -- 将 progress 从 x 变为 1-x, 并调整 currentTime
        p.progress = 1 - p.progress
        p.currentTime = p.progress * p.duration
        p.direction = -1
    elseif (not rev) and p.direction == -1 then
        p.progress = 1 - p.progress
        p.currentTime = p.progress * p.duration
        p.direction = 1
    end
end

-- 动态设置 speed（若原来是按 duration 的也可以切换到 speed）
function paths.SetSpeed(pathID, newSpeed)
    local p = paths.activePaths[pathID]
    if not p then return end
    newSpeed = tonumber(newSpeed) or 0
    if newSpeed <= 0 then return end
    local lookup = p.pathPoints.__lengthLookup or paths.BuildLengthLookup(p.pathPoints)
    local total = lookup and lookup.totalLength or 0
    if total <= 0 then
        p.duration = 0
        p.speed = newSpeed
        p.useSpeed = true
        return
    end
    -- 重新计算 duration，保持当前进度位置和 currentTime
    local currentProgress = clamp(p.progress, 0, 1)
    p.useSpeed = true
    p.speed = newSpeed
    p.duration = total / newSpeed
    p.currentTime = currentProgress * p.duration
end

-- 设置起始偏移（0..1），会调整当前 progress 和 currentTime
function paths.SetOffset(pathID, offset)
    local p = paths.activePaths[pathID]
    if not p then return end
    offset = clamp(tonumber(offset) or 0, 0, 1)
    if p.direction == 1 then
        p.progress = offset
    else
        p.progress = 1 - offset
    end
    p.currentTime = p.progress * p.duration
end

-- 暂停所有路径
function paths.PauseAll()
    for id, p in pairs(paths.activePaths) do
        p.paused = true
        p.active = false
    end
end

function paths.ResumeAll()
    for id, p in pairs(paths.activePaths) do
        p.paused = false
        p.active = true
    end
end

function paths.ClearAll()
    paths.activePaths = {}
    paths._nextID = 1
end

-- 更新所有活动路径（在 love.update 中调用）
function paths.update(dt)
    if not dt or dt <= 0 then return end

    local toRemove = {}

    for pathID, pathInstance in pairs(paths.activePaths) do
        if pathInstance and pathInstance.active and (not pathInstance.paused) then
            -- 增加时间（按 direction）
            pathInstance.currentTime = pathInstance.currentTime + dt * pathInstance.direction

            -- 计算进度
            if pathInstance.duration <= 0 then
                pathInstance.progress = pathInstance.direction == 1 and 1 or 0
            else
                pathInstance.progress = pathInstance.currentTime / pathInstance.duration
            end

            local finishedThisFrame = false

            if pathInstance.direction == 1 and pathInstance.progress >= 1 then
                finishedThisFrame = true
            elseif pathInstance.direction == -1 and pathInstance.progress <= 0 then
                finishedThisFrame = true
            end

            if finishedThisFrame then
                if pathInstance.loop then
                    if pathInstance.pingpong then
                        -- 反向继续；将时间夹在合法区间
                        pathInstance.direction = -pathInstance.direction
                        -- clamp currentTime
                        if pathInstance.direction == 1 then
                            if pathInstance.currentTime < 0 then pathInstance.currentTime = 0 end
                        else
                            if pathInstance.currentTime > pathInstance.duration then pathInstance.currentTime = pathInstance.duration end
                        end
                        pathInstance.progress = clamp(pathInstance.currentTime / math.max(0.000001, pathInstance.duration), 0, 1)
                        -- 不移除
                    else
                        -- 循环：从头开始（wrap）
                        -- 将 currentTime 按 duration 修正为在 [0,duration)
                        if pathInstance.duration > 0 then
                            if pathInstance.direction == 1 then
                                pathInstance.currentTime = pathInstance.currentTime - pathInstance.duration
                                if pathInstance.currentTime < 0 then pathInstance.currentTime = 0 end
                            else
                                pathInstance.currentTime = pathInstance.currentTime + pathInstance.duration
                                if pathInstance.currentTime > pathInstance.duration then pathInstance.currentTime = pathInstance.duration end
                            end
                            pathInstance.progress = clamp(pathInstance.currentTime / math.max(0.000001, pathInstance.duration), 0, 1)
                        end
                        -- 继续循环，不触发 onComplete for loop
                    end
                else
                    -- 非循环：结束并移除
                    pathInstance.active = false
                    table.insert(toRemove, pathID)
                end
            end

            -- 应用缓动（注意 progress 必须在0..1）
            local easedProgress = clamp(pathInstance.easing(clamp(pathInstance.progress, 0, 1)) or 0, 0, 1)

            -- 计算当前路径位置
            local pathPos = paths.GetPathPosition(pathInstance.pathPoints, easedProgress)

            -- 更新对象位置
            if pathInstance.object and pathPos then
                pathInstance.object.x = pathPos.x
                pathInstance.object.y = pathPos.y

                if pathInstance.onUpdate then
                    local ok, err = pcall(pathInstance.onUpdate, pathInstance.object, easedProgress)
                    if not ok then
                        print("paths: onUpdate callback error:", err)
                    end
                end
            end

            -- 如果本次结束且非循环，调用 onComplete（延后在清理之前）
            if finishedThisFrame and (not pathInstance.loop) then
                if pathInstance.onComplete then
                    local ok, err = pcall(pathInstance.onComplete, pathInstance.object, pathInstance)
                    if not ok then
                        print("paths: onComplete callback error:", err)
                    end
                end
            end
        end
    end

    for _, id in ipairs(toRemove) do
        paths.activePaths[id] = nil
    end
end

-- 获取路径长度（近似值）
function paths.GetPathLength(pathPoints)
    if not pathPoints or #pathPoints <= 1 then return 0 end
    local lookup = pathPoints.__lengthLookup or paths.BuildLengthLookup(pathPoints)
    return lookup and lookup.totalLength or 0
end

-- 调试绘制路径（在 love.draw 中调用）
function paths.drawPath(pathPoints, color)
    if not pathPoints then return end
    color = color or {1, 0, 0, 1}
    local prevR, prevG, prevB, prevA
    if love.graphics.getColor then
        prevR, prevG, prevB, prevA = love.graphics.getColor()
    end
    love.graphics.setColor(color)
    for i = 1, #pathPoints - 1 do
        love.graphics.line(pathPoints[i].x, pathPoints[i].y, pathPoints[i + 1].x, pathPoints[i + 1].y)
    end
    for i, point in ipairs(pathPoints) do
        love.graphics.circle("fill", point.x, point.y, 1)
    end
    if prevR then love.graphics.setColor(prevR, prevG, prevB, prevA) else love.graphics.setColor(1,1,1,1) end
end

-- 预定义路径（存储在路径库中方便重用）
function paths.DefinePath(name, pathPoints)
    if type(name) ~= "string" then error("DefinePath: name must be string") end
    if pathPoints then
        paths.BuildLengthLookup(pathPoints)
        paths.definedPaths[name] = pathPoints
    end
    return paths.definedPaths[name]
end

return paths