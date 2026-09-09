-- ============================================================================
-- Border.lua
-- 窗口级装饰边框（Border）管理器。
--
-- 统一处理边框的三件事，避免在 main.lua / 各场景里写重复魔法语句：
--   1. 是否启用
--   2. 用哪张边框图
--   3. 淡入 / 淡出
--
-- 绘制固定到屏幕左上角 (0,0)，并按 LOGICAL 布局（1024x576）等比 cover 适配，
-- 全屏时随 ScreenScale 一起放大，始终与居中的游戏画面对齐。
--
-- 用法：
--     Border = ImportFile("Utils.Border")
--     Border.SetEnabled(true)          -- 总开关（默认 true）
--     Border.SetImage("ruins")         -- 用预设名，或直接传图片路径
--     Border.FadeIn(1.0)               -- 1 秒淡入
--     Border.FadeOut(1.0)              -- 1 秒淡出（完成后自动停用）
--     Border.SetAlpha(0.5)             -- 直接设透明度，跳过动画
--     Border.RegisterImage("name", "Resources/...png")  -- 扩展预设
--
--     -- 每帧（main.lua 已接入）：
--     Border.Update(dt)                -- 推进淡入淡出
--     Border.Draw()                    -- 画完游戏画面后调用（最上层）
-- ============================================================================

local Border = {}

-- 内置预设：key -> 图片路径（16:9，覆盖窗口布局）。
-- idle / ruins 均为 960x540，等比放大正好铺满 1024x576。
local presets = {
    idle  = "Resources/Sprites/Border/idle.png",
    ruins = "Resources/Sprites/Border/ruins.png",
}

-- 已加载图片缓存：key/路径 -> love Image
local cache = {}

-- 当前状态
local currentKey = nil              -- 当前图 key/路径
local currentImg = nil              -- 当前 love Image
local target    = 0                 -- 淡入淡出目标 alpha
local speed     = 0                 -- alpha/秒，0 = 静止

-- 公开状态（可读写）
Border.enabled = true               -- 总开关：false 时 Draw 什么都不画
Border.alpha   = 0                  -- 当前透明度 0..1

--- 注册一张边框图，name 供后续 SetImage 使用。
---@param name string
---@param path string
function Border.RegisterImage(name, path)
    if (name and path) then
        presets[name] = path
    end
end

--- 切换当前边框图：可传预设名（"ruins" / "idle"）或完整图片路径。
--- 图片首次使用时才真正加载（懒加载）。
---@param img string
function Border.SetImage(img)
    if (not img or img == "") then return end
    if (img == currentKey and currentImg) then return end

    local path = presets[img] or img
    local image = cache[path]
    if (not image) then
        image = SE.graphics.newImage(path)
        image:setFilter("linear", "linear")
        cache[path] = image
    end

    currentKey = img
    currentImg = image
end

--- 总开关。
---@param on boolean
function Border.SetEnabled(on)
    Border.enabled = (on ~= false)
end

--- 直接设置透明度（0..1），跳过淡入淡出动画。
---@param a number
function Border.SetAlpha(a)
    Border.alpha = math.max(0, math.min(1, a or 0))
    target = Border.alpha
    speed = 0
end

--- 淡入：在 dur 秒内从当前 alpha 渐显到 1，并自动启用。
---@param dur number 秒（缺省 1）
function Border.FadeIn(dur)
    Border.enabled = true
    dur = (dur and dur > 0) and dur or 1
    target = 1
    speed = 1 / dur
end

--- 淡出：在 dur 秒内从当前 alpha 渐隐到 0，完成后自动停用（不再绘制）。
---@param dur number 秒（缺省 1）
function Border.FadeOut(dur)
    dur = (dur and dur > 0) and dur or 1
    target = 0
    speed = 1 / dur
end

--- 每帧推进淡入淡出（由 main.lua 的 love.update 调用）。
---@param dt number
function Border.Update(dt)
    if (speed == 0) then return end

    if (Border.alpha < target) then
        Border.alpha = math.min(target, Border.alpha + speed * dt)
    elseif (Border.alpha > target) then
        Border.alpha = math.max(target, Border.alpha - speed * dt)
    end

    if (Border.alpha == target) then
        speed = 0
        if (target == 0) then
            Border.enabled = false
        end
    end
end

--- 绘制边框到屏幕 (0,0)。请在画完游戏画面后、最上层调用。
--- 没有启用、透明度为 0 或未设置图时自动跳过。
function Border.Draw()
    if (not Border.enabled or Border.alpha <= 0) then return end

    if (not currentImg) then
        Border.SetImage("ruins")
    end
    if (not currentImg) then return end

    local imgW, imgH = currentImg:getDimensions()
    -- cover：等比放大到至少铺满 LOGICAL 窗口（Border 图都是 16:9，
    -- 因此精确铺满 1024x576），再叠加全屏布局缩放 ScreenScale。
    local s = ScreenScale * math.max(LOGICAL_WIDTH / imgW, LOGICAL_HEIGHT / imgH)

    SE.graphics.push()
    SE.graphics.origin()
    SE.graphics.setColor(1, 1, 1, Border.alpha)
    SE.graphics.draw(currentImg, 0, 0, 0, s, s)
    SE.graphics.pop()
end

return Border
