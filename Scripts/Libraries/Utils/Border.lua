local Border = {}

local presets = {
    idle  = "Resources/Sprites/Border/idle.png",
    ruins = "Resources/Sprites/Border/ruins.png",
}

local cache = {}

local currentKey = nil
local currentImg = nil
local target    = 0
local speed     = 0
Border.enabled = true
Border.alpha   = 0

---@param name string
---@param path string
function Border.RegisterImage(name, path)
    if (name and path) then
        presets[name] = path
    end
end

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

---@param on boolean
function Border.SetEnabled(on)
    Border.enabled = (on ~= false)
end

---@param a number
function Border.SetAlpha(a)
    Border.alpha = math.max(0, math.min(1, a or 0))
    target = Border.alpha
    speed = 0
end

---@param dur number|nil
function Border.FadeIn(dur)
    Border.enabled = true
    dur = (dur and dur > 0) and dur or 1
    target = 1
    speed = 1 / dur
end

---@param dur number|nil
function Border.FadeOut(dur)
    dur = (dur and dur > 0) and dur or 1
    target = 0
    speed = 1 / dur
end

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

function Border.Draw()
    if (not Border.enabled or Border.alpha <= 0) then return end

    if (not currentImg) then
        Border.SetImage("ruins")
    end
    if (not currentImg) then return end

    local imgW, imgH = currentImg:getDimensions()
    local s = ScreenScale * math.max(LOGICAL_WIDTH / imgW, LOGICAL_HEIGHT / imgH)

    SE.graphics.push()
    SE.graphics.origin()
    SE.graphics.setColor(1, 1, 1, Border.alpha)
    SE.graphics.draw(currentImg, 0, 0, 0, s, s)
    SE.graphics.pop()
end

return Border
