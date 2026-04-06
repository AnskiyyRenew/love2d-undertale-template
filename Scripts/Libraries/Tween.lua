-- Tween.lua
-- 用法：
--   local anim = tween.CreateTween(setter, "quad", "out", 0, 100, 60)
--   tween.Update(dt)  -- 每帧调用
--
-- 参数说明：
--   setter      : function(value)，每帧接收插值结果
--   easingType  : 缓动曲线名称，如 "quad"、"sine"、"bounce" 等
--   direction   : "in" | "out" | "inout"（linear 无需 direction，填 "" 即可）
--   begin       : 起始值
--   final       : 目标值
--   duration    : 动画持续 tick 数
--   delay       : （可选）延迟多少 tick 后开始，默认 0
--   destroyAfter: （可选）延迟结束后，动画跑多少 tick 就强制销毁，默认 = duration

local tween = {
    animations = {},
    customEasings = {},   -- 通过 CreateCustomTween 注册的自定义缓动
}

--------------------------------------------------------------------------------
-- 内置缓动函数表
-- 每个函数接收 progress（0~1），返回 eased progress（0~1）
--------------------------------------------------------------------------------

local function bounceOutRaw(t)
    local n1, d1 = 7.5625, 2.75
    if t < 1 / d1 then
        return n1 * t * t
    elseif t < 2 / d1 then
        t = t - 1.5 / d1
        return n1 * t * t + 0.75
    elseif t < 2.5 / d1 then
        t = t - 2.25 / d1
        return n1 * t * t + 0.9375
    else
        t = t - 2.625 / d1
        return n1 * t * t + 0.984375
    end
end

local builtinEasings = {
    -- Linear（direction 参数忽略，统一用 "linear"）
    ["linear"] = function(t) return t end,

    -- Quad
    ["quadin"] = function(t) return t * t end,
    ["quadout"] = function(t) return 1 - (1 - t) * (1 - t) end,
    ["quadinout"] = function(t)
        t = t * 2
        if t < 1 then return 0.5 * t * t end
        t = t - 1
        return -0.5 * (t * (t - 2) - 1)
    end,

    -- Sine
    ["sinein"] = function(t) return 1 - math.cos(t * math.pi / 2) end,
    ["sineout"] = function(t) return math.sin(t * math.pi / 2) end,
    ["sineinout"] = function(t) return -0.5 * (math.cos(math.pi * t) - 1) end,

    -- Cubic
    ["cubicin"] = function(t) return t ^ 3 end,
    ["cubicout"] = function(t) t = t - 1; return t ^ 3 + 1 end,
    ["cubicinout"] = function(t)
        t = t * 2
        if t < 1 then return 0.5 * t ^ 3 end
        t = t - 2
        return 0.5 * (t ^ 3 + 2)
    end,

    -- Quart
    ["quartin"] = function(t) return t ^ 4 end,
    ["quartout"] = function(t) t = t - 1; return 1 - t ^ 4 end,
    ["quartinout"] = function(t)
        t = t * 2
        if t < 1 then return 0.5 * t ^ 4 end
        t = t - 2
        return -0.5 * (t ^ 4 - 2)
    end,

    -- Quint
    ["quintin"] = function(t) return t ^ 5 end,
    ["quintout"] = function(t) t = t - 1; return t ^ 5 + 1 end,
    ["quintinout"] = function(t)
        t = t * 2
        if t < 1 then return 0.5 * t ^ 5 end
        t = t - 2
        return 0.5 * (t ^ 5 + 2)
    end,

    -- Expo
    ["expoin"] = function(t) return 2 ^ (10 * (t - 1)) end,
    ["expoout"] = function(t) return 1 - 2 ^ (-10 * t) end,
    ["expoinout"] = function(t)
        t = t * 2
        if t < 1 then return 0.5 * 2 ^ (10 * (t - 1)) end
        t = t - 1
        return 0.5 * (2 - 2 ^ (-10 * t))
    end,

    -- Circ
    ["circin"] = function(t) return 1 - math.sqrt(1 - t * t) end,
    ["circout"] = function(t) t = t - 1; return math.sqrt(1 - t * t) end,
    ["circinout"] = function(t)
        t = t * 2
        if t < 1 then return -0.5 * (math.sqrt(1 - t * t) - 1) end
        t = t - 2
        return 0.5 * (math.sqrt(1 - t * t) + 1)
    end,

    -- Back
    ["backin"] = function(t)
        local s = 1.70158
        return t * t * ((s + 1) * t - s)
    end,
    ["backout"] = function(t)
        local s = 1.70158
        t = t - 1
        return t * t * ((s + 1) * t + s) + 1
    end,
    ["backinout"] = function(t)
        local s = 1.70158 * 1.525
        t = t * 2
        if t < 1 then return 0.5 * t * t * ((s + 1) * t - s) end
        t = t - 2
        return 0.5 * (t * t * ((s + 1) * t + s) + 2)
    end,

    -- Elastic
    ["elasticin"] = function(t)
        local p, s = 0.3, 0.075
        t = t - 1
        return -(2 ^ (10 * t)) * math.sin((t - s) * (2 * math.pi) / p)
    end,
    ["elasticout"] = function(t)
        local p, s = 0.3, 0.075
        return 2 ^ (-10 * t) * math.sin((t - s) * (2 * math.pi) / p) + 1
    end,
    ["elasticinout"] = function(t)
        local p, s = 0.45, 0.1125
        t = t * 2
        if t < 1 then
            t = t - 1
            return -0.5 * 2 ^ (10 * t) * math.sin((t - s) * (2 * math.pi) / p)
        end
        t = t - 1
        return 0.5 * 2 ^ (-10 * t) * math.sin((t - s) * (2 * math.pi) / p) + 1
    end,

    -- Bounce
    ["bounceout"] = bounceOutRaw,
    ["bouncein"] = function(t) return 1 - bounceOutRaw(1 - t) end,
    ["bounceinout"] = function(t)
        if t < 0.5 then return (1 - bounceOutRaw(1 - t * 2)) * 0.5 end
        return bounceOutRaw((t - 0.5) * 2) * 0.5 + 0.5
    end,
}

--------------------------------------------------------------------------------
-- 公共 API
--------------------------------------------------------------------------------

---创建一个补间动画
---@param variableSetter  function(value)  每帧回调，接收当前插值
---@param easingType      string           缓动类型，如 "quad"、"bounce"、"linear"
---@param direction       string           方向："in"、"out"、"inout"（linear 填 "" 或任意）
---@param begin           number           起始值
---@param final           number           目标值
---@param duration        number           动画持续 tick 数
---@param delay           number?          延迟多少 tick 后开始（默认 0）
---@param destroyAfter    number?          动画开始后多少 tick 强制销毁（默认 = duration）
function tween.CreateTween(variableSetter, easingType, direction, begin, final, duration, delay, destroyAfter)
    local animation = {
        variableSetter = variableSetter,
        easingName     = (easingType .. direction):lower(),
        begin          = begin,
        final          = final,
        duration       = duration,
        delay          = delay or 0,         -- 剩余延迟 tick（每帧递减）
        destroyAfter   = destroyAfter or duration, -- 动画开始后多少 tick 销毁
        time           = 0,                  -- 动画已运行 tick 数（延迟期间不计）
    }
    table.insert(tween.animations, animation)
    return animation
end

---注册自定义缓动函数
---@param name       string    缓动名称（调用时 easingType+direction 需能拼出此名）
---@param easingFunc function  接收 progress(0~1)，返回 eased progress(0~1)
function tween.CreateCustomTween(name, easingFunc)
    assert(type(name) == "string",     "Custom tween name must be a string")
    assert(type(easingFunc) == "function", "Custom tween easing function must be a function")
    tween.customEasings[name:lower()] = easingFunc
end

---每帧调用，推进所有动画
function tween.Update(dt)
    for i = #tween.animations, 1, -1 do
        local animation = tween.animations[i]

        -- 延迟阶段：delay 还没耗尽，只递减不计时
        if animation.delay > 0 then
            animation.delay = animation.delay - 1
            goto continue
        end

        -- 动画完成（time 超出 destroyAfter）：将最终值写入并移除
        if animation.time > animation.destroyAfter then
            local ok, err = pcall(animation.variableSetter, animation.final)
            if not ok then
                print("[Tween] variableSetter error on finish: " .. tostring(err))
            end
            table.remove(tween.animations, i)
            goto continue
        end

        -- 正常播放阶段
        do
            local progress = animation.time / animation.duration
            local easingFunc = builtinEasings[animation.easingName]
                            or tween.customEasings[animation.easingName]

            if not easingFunc then
                print("[Tween] Unknown easing: '" .. animation.easingName .. "', removing animation.")
                table.remove(tween.animations, i)
                goto continue
            end

            local easedProgress = easingFunc(progress)
            local current = animation.begin + (animation.final - animation.begin) * easedProgress

            local ok, err = pcall(animation.variableSetter, current)
            if not ok then
                print("[Tween] variableSetter error: " .. tostring(err) .. " — animation removed.")
                table.remove(tween.animations, i)
                goto continue
            end

            animation.time = animation.time + 1
        end

        ::continue::
    end
end

---清除所有动画
function tween.Clear()
    tween.animations = {}
end

return tween