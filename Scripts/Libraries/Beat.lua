local beats = {}
beats.bpm = 120
beats.time = -0.01
beats.cycle_length = 4    -- 默认4拍一个循环
beats.event_handlers = {} -- 事件回调表
beats._triggered = {}     -- 记录每个目标节拍上次触发时所在的小节编号

-- 设置BPM值
function beats.SetBPM(new_bpm)
    assert(type(new_bpm) == "number" and new_bpm > 0,
        "Invalid BPM: must be a positive number")
    beats.bpm = new_bpm
end

-- 设置节拍循环长度
function beats.SetCycleLength(length)
    assert(type(length) == "number" and length > 0,
        "Invalid cycle length: must be a positive number")
    beats.cycle_length = length
    beats._triggered = {} -- 循环长度变化时清空触发记录
end

-- 注册节拍事件处理器
function beats.RegisterEvent(event_type, handler)
    assert(type(handler) == "function", "Handler must be a function")
    beats.event_handlers[event_type] = handler
end

-- 检查是否到达目标节拍（支持循环 + 容差检测）
-- target_beat: 目标节拍位置（在循环内，例如 0、1、2、3）
-- tolerance:   允许的误差范围，默认 0.1 拍
-- 每个 target_beat 在同一小节内只触发一次
function beats.OnBeat(target_beat, tolerance)
    tolerance              = tolerance or 0.1

    local target_in_cycle  = target_beat % beats.cycle_length
    local current_bar      = math.floor(beats.time / beats.cycle_length)
    local current_in_cycle = beats.time % beats.cycle_length

    -- 计算与目标节拍的距离，处理循环边界的环绕情况
    local diff             = math.abs(current_in_cycle - target_in_cycle)
    if diff > beats.cycle_length * 0.5 then
        diff = beats.cycle_length - diff
    end

    if diff <= tolerance then
        -- 用目标节拍位置作为 key，避免多个不同目标互相干扰
        local key = target_in_cycle
        if beats._triggered[key] ~= current_bar then
            beats._triggered[key] = current_bar
            return true
        end
    end

    return false
end

-- 获取当前节拍（返回整数部分、小数部分）
function beats.GetBeat()
    local integer_part    = math.floor(beats.time)
    local fractional_part = beats.time - integer_part
    return integer_part + 1, fractional_part
end

-- 获取当前小节信息（返回小节编号、小节内拍位）
function beats.GetBar()
    local t               = beats.time + 1
    local bar             = math.floor(t / beats.cycle_length)
    local bar_beat        = t % beats.cycle_length + 1

    local integer_part    = math.floor(bar_beat)
    local fractional_part = bar_beat - integer_part
    return bar, integer_part, fractional_part
end

-- 设置当前节拍
function beats.SetBeat(beat)
    assert(type(beat) == "number" and beat >= 0,
        "Invalid beat: must be a non-negative number")
    beats.time       = beat
    beats._triggered = {} -- 重置所有触发记录

    if beats.event_handlers.reset then
        beats.event_handlers.reset(beat)
    end
end

-- 重置节拍状态（保留BPM和循环长度设置）
function beats.Reset()
    beats.SetBeat(0)
end

-- 更新节拍状态
-- 修复：遍历所有跨越的整数节拍，避免大 dt 时丢失事件
function beats.Update(dt)
    assert(type(dt) == "number" and dt >= 0,
        "Invalid delta time: must be a non-negative number")

    local prev_beat = math.floor(beats.time)
    beats.time      = beats.time + (beats.bpm / 60) * dt
    local curr_beat = math.floor(beats.time)

    -- 触发本帧内所有跨越的整数节拍事件
    for b = prev_beat + 1, curr_beat do
        if beats.event_handlers.beat then
            beats.event_handlers.beat(b + 1)
        end
    end
end

return beats
