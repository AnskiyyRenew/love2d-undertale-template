-- 增强版节拍管理库，支持多节拍检测、循环节拍和自定义事件
local beats = {}
beats.bpm = 120
beats.beat = 0.0
beats.last_triggered_beat = -1
beats.cycle_length = 4  -- 默认4拍一个循环
beats.event_handlers = {}  -- 事件回调表

-- 设置BPM值（增加输入验证）
function beats.SetBPM(new_bpm)
    if type(new_bpm) ~= "number" or new_bpm <= 0 then
        error("Invalid BPM: must be a positive number")
    end
    beats.bpm = new_bpm
end

-- 设置节拍循环长度（用于循环检测）
function beats.SetCycleLength(length)
    if type(length) ~= "number" or length <= 0 then
        error("Invalid cycle length: must be a positive number")
    end
    beats.cycle_length = length
end

-- 注册节拍事件处理器
function beats.RegisterEvent(event_type, handler)
    if type(handler) ~= "function" then
        error("Handler must be a function")
    end
    beats.event_handlers[event_type] = handler
end

-- 检查是否到达目标节拍（支持循环节拍检测）
function beats.OnBeat(target_beat)
    -- 计算当前节拍在循环中的位置
    local current_cycle_beat = beats.beat % beats.cycle_length
    local target_cycle_beat = target_beat % beats.cycle_length

    -- 检查是否跨越目标节拍
    if (current_cycle_beat >= target_cycle_beat and
        beats.last_triggered_beat < target_cycle_beat) then

        beats.last_triggered_beat = target_cycle_beat
        return true
    end
    return false
end

-- 获取当前节拍信息（返回整数和小数部分）
function beats.GetBeat()
    local integer_part = math.floor(beats.beat)
    local fractional_part = beats.beat - integer_part
    return integer_part, fractional_part
end

-- 获取当前小节信息
function beats.GetBar()
    local bar = math.floor(beats.beat / beats.cycle_length)
    local bar_beat = beats.beat % beats.cycle_length
    return bar, bar_beat
end

-- 设置当前节拍（增加循环重置功能）
function beats.SetBeat(beat)
    if type(beat) ~= "number" or beat < 0 then
        error("Invalid beat: must be a non-negative number")
    end
    beats.beat = beat
    beats.last_triggered_beat = -1

    -- 触发重置事件
    if beats.event_handlers.reset then
        beats.event_handlers.reset(beat)
    end
end

-- 重置节拍状态（保留BPM设置）
function beats.Reset()
    beats.SetBeat(0)
end

-- 更新节拍状态（增加循环处理和事件触发）
function beats.Update(dt)
    if type(dt) ~= "number" or dt < 0 then
        error("Invalid delta time: must be a non-negative number")
    end

    -- 保存更新前的节拍信息
    local prev_beat = beats.beat
    local prev_int_beat = math.floor(prev_beat)

    -- 计算节拍增量
    beats.beat = beats.beat + (beats.bpm / 60) * dt

    -- 计算当前整数节拍
    local current_int_beat = math.floor(beats.beat)

    -- 检测跨越整数节拍
    if current_int_beat > prev_int_beat then
        -- 触发节拍事件
        if beats.event_handlers.beat then
            beats.event_handlers.beat(current_int_beat)
        end

        -- 重置触发状态（支持循环）
        if (current_int_beat % beats.cycle_length) == 0 then
            beats.last_triggered_beat = -1
        end
    end
end

return beats