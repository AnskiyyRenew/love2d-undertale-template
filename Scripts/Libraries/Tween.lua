--- Tween.lua - CreateTween(...) builds a tween, Update(dt) runs once per frame; durations are counted in ticks.

local tween = {
    animations = {},
    customEasings = {},
}

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
    ["linear"] = function(t) return t end,

    ["quadin"] = function(t) return t * t end,
    ["quadout"] = function(t) return 1 - (1 - t) * (1 - t) end,
    ["quadinout"] = function(t)
        t = t * 2
        if t < 1 then return 0.5 * t * t end
        t = t - 1
        return -0.5 * (t * (t - 2) - 1)
    end,

    ["sinein"] = function(t) return 1 - math.cos(t * math.pi / 2) end,
    ["sineout"] = function(t) return math.sin(t * math.pi / 2) end,
    ["sineinout"] = function(t) return -0.5 * (math.cos(math.pi * t) - 1) end,

    ["cubicin"] = function(t) return t ^ 3 end,
    ["cubicout"] = function(t) t = t - 1; return t ^ 3 + 1 end,
    ["cubicinout"] = function(t)
        t = t * 2
        if t < 1 then return 0.5 * t ^ 3 end
        t = t - 2
        return 0.5 * (t ^ 3 + 2)
    end,

    ["quartin"] = function(t) return t ^ 4 end,
    ["quartout"] = function(t) t = t - 1; return 1 - t ^ 4 end,
    ["quartinout"] = function(t)
        t = t * 2
        if t < 1 then return 0.5 * t ^ 4 end
        t = t - 2
        return -0.5 * (t ^ 4 - 2)
    end,

    ["quintin"] = function(t) return t ^ 5 end,
    ["quintout"] = function(t) t = t - 1; return t ^ 5 + 1 end,
    ["quintinout"] = function(t)
        t = t * 2
        if t < 1 then return 0.5 * t ^ 5 end
        t = t - 2
        return 0.5 * (t ^ 5 + 2)
    end,

    ["expoin"] = function(t) return 2 ^ (10 * (t - 1)) end,
    ["expoout"] = function(t) return 1 - 2 ^ (-10 * t) end,
    ["expoinout"] = function(t)
        t = t * 2
        if t < 1 then return 0.5 * 2 ^ (10 * (t - 1)) end
        t = t - 1
        return 0.5 * (2 - 2 ^ (-10 * t))
    end,

    ["circin"] = function(t) return 1 - math.sqrt(1 - t * t) end,
    ["circout"] = function(t) t = t - 1; return math.sqrt(1 - t * t) end,
    ["circinout"] = function(t)
        t = t * 2
        if t < 1 then return -0.5 * (math.sqrt(1 - t * t) - 1) end
        t = t - 2
        return 0.5 * (math.sqrt(1 - t * t) + 1)
    end,

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

    ["bounceout"] = bounceOutRaw,
    ["bouncein"] = function(t) return 1 - bounceOutRaw(1 - t) end,
    ["bounceinout"] = function(t)
        if t < 0.5 then return (1 - bounceOutRaw(1 - t * 2)) * 0.5 end
        return bounceOutRaw((t - 0.5) * 2) * 0.5 + 0.5
    end,
}

---Creates a tween animation
---@param variableSetter  function(value)  called every frame with the interpolated value
---@param easingType      string           easing type, e.g. "quad", "bounce", "linear"
---@param direction       string           "in", "out", "inout" ("" for linear)
---@param begin           number           starting value
---@param final           number           target value
---@param duration        number           number of ticks the animation lasts
---@param delay           number?          number of ticks to wait before starting (default 0)
---@param destroyAfter    number?          ticks after start before destroy (default duration)
function tween.CreateTween(variableSetter, easingType, direction, begin, final, duration, delay, destroyAfter)
    local animation = {
        variableSetter = variableSetter,
        easingName     = (easingType .. direction):lower(),
        begin          = begin,
        final          = final,
        duration       = duration,
        delay          = delay or 0,
        destroyAfter   = destroyAfter or duration,
        time           = 0,
    }
    table.insert(tween.animations, animation)
    return animation
end

---Registers a custom easing function
---@param name       string    easing name; must equal easingType..direction at call time
---@param easingFunc function  receives progress (0~1), returns eased progress (0~1)
function tween.CreateCustomTween(name, easingFunc)
    assert(type(name) == "string",     "Custom tween name must be a string")
    assert(type(easingFunc) == "function", "Custom tween easing function must be a function")
    tween.customEasings[name:lower()] = easingFunc
end

---Called every frame, advances all animations
---@param dt number
function tween.Update(dt)
    for i = #tween.animations, 1, -1 do
        local animation = tween.animations[i]

        if animation.delay > 0 then
            animation.delay = animation.delay - 1

        elseif animation.time > animation.destroyAfter then
            local ok, err = pcall(animation.variableSetter, animation.final)
            if not ok then
                print("[Tween] variableSetter error on finish: " .. tostring(err))
            end
            table.remove(tween.animations, i)

        else
            local progress = animation.time / animation.duration
            local easingFunc = builtinEasings[animation.easingName]
                            or tween.customEasings[animation.easingName]

            if not easingFunc then
                print("[Tween] Unknown easing: '" .. animation.easingName .. "', removing animation.")
                table.remove(tween.animations, i)
            else
                local easedProgress = easingFunc(progress)
                local current = animation.begin + (animation.final - animation.begin) * easedProgress

                local ok, err = pcall(animation.variableSetter, current)
                if not ok then
                    print("[Tween] variableSetter error: " .. tostring(err) .. " - animation removed.")
                    table.remove(tween.animations, i)
                else
                    animation.time = animation.time + 1
                end
            end
        end
    end
end

---Creates a Bezier easing curve and registers it in the custom easing table
---@param name   string    easing name
---@param points table    control point list, format: {{x=0,y=0}, {x=...,y=...}, ..., {x=1,y=1}}
---                        any number of control points, via the De Casteljau algorithm
function tween.CreateBezierEasing(name, points)
    assert(type(name) == "string", "Bezier easing name must be a string")
    assert(type(points) == "table" and #points >= 2, "Bezier easing needs at least 2 control points")
    tween.customEasings[name:lower()] = function(t)
        local n = #points
        local px, py = {}, {}
        for i = 1, n do
            px[i] = points[i].x
            py[i] = points[i].y
        end
        for level = n, 2, -1 do
            for i = 1, level - 1 do
                px[i] = px[i] * (1 - t) + px[i + 1] * t
                py[i] = py[i] * (1 - t) + py[i + 1] * t
            end
        end
        return py[1]
    end
end

---Clears all animations
function tween.Clear()
    tween.animations = {}
end

return tween
