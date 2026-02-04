---@class Forge.Timeline.Builder
local Builder = {}

---@alias Forge.Timeline.Builder.Actions "sleep" | "sleep_frame" | "stop"
---@alias Forge.Timeline.Builder.Action {type: Forge.Timeline.Builder.Actions, props: table<string, any>}

-- 休眠指定时间
---@param time number 指定休眠时间
---@return number dt 实际休眠时间与指定休眠时间的差
function Builder.sleep(time)
    assert(type(time) == "number", "bad argument #1 to 'sleep' (number expected, got " .. type(time) .. ")")
    assert(time >= 0, "bad argument #1 to 'sleep' (value must be non-negative)")
    return coroutine.yield{ type = "sleep", props = {time = time} }
end

-- 休眠指定帧数, 会导致 remain_time 重置为 0
---@param frame number 指定休眠帧数
---@return number dt 理想状态下的当前时刻和休眠后的间隔时间
function Builder.sleep_frame(frame)
    assert(type(frame) == "number", "bad argument #1 to 'sleep_frame' (number expected, got " .. type(frame) .. ")")
    assert(frame >= 0, "bad argument #1 to 'sleep_frame' (value must be non-negative)")
    if frame == 0 then
        return 0.0
    end
    return coroutine.yield{ type = "sleep_frame", props = {frame = frame} }
end

-- 立即停止时间线
---@return nil
function Builder.stop()
    return coroutine.yield{ type = "stop", props = {} }
end

return Builder