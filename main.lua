-- Init
love = require("love")
if (not _RELEASED) then
    if (love.system.getOS() == "Windows") then
        local handle = io.popen("chcp 65001", "r")
        if (handle) then
            handle:close()
        end
    end
end
require("Scripts.Libraries.Engine.PathDefiner")
SE = ImportFile("Engine.FuncProtector")
print("Configuration loaded, engine version: " .. _VER)
print("配置已加载成功，引擎版本:             " .. _VER .. "\n")

-- Libraries
LuaEX = ImportFile("Utils.LuaExtended")
Global = ImportFile("Global")
Collisions = ImportFile("Collisions")
Tween = ImportFile("Tween")
Masks = ImportFile("Masks")
Camera = ImportFile("Camera"):New()
Audio = ImportFile("Audio")
Keyboard = ImportFile("Keyboard")
Scenes = ImportFile("SceneManager")
Layers = ImportFile("Layers")
Sprites = ImportFile("Sprites")
Typers = ImportFile("Typers")
Debugger = ImportFile("Engine.Debugger")
Localize = ImportFile("Localize")
Localize.setFile("zh_CN")
Gamejolt = ImportFile("GamejoltAPI")

-- Limits
--[[
    The following are foolproof design measures: 
    if the number of images/typewriter entries/audio files you create exceeds this limit,
    you will be automatically notified.
    If it exceeds twice the limit, creation will begin to be blocked.

    Under normal circumstances, we do not need this many resources,
    so if you are blocked, please check whether the recycling function
    has any vulnerabilities.
]]
Global.SetVariable("SE_MEMORY_SAFETY", true)    -- DANGEROUS
Global.SetVariable("OPT_COUNT_SPRITES", 2000)
Global.SetVariable("OPT_COUNT_TYPERS", 300)
Global.SetVariable("OPT_MEMORY_MAXSIZE", 0.8)
Global.SetVariable("OPT_LRU_SPRITES", {true, 180})      -- Unit: seconds. If this time is exceeded without using the texture, it will be removed from the cache according to the LRU algorithm to free up space.
local guard = ImportFile("Engine.MemorySafety")

-- Initialize
Global.SetVariable("UseRealTime(dt)", true)
--Global.SetVariable("MainColor", SE.tools.hexColor("#6B0684"))
Global.SetVariable("MainColor", {1, 1, 1})
Global.SetVariable("ScreenShaders", {})
Global.SetVariable("FPS", 60)
Global.SetVariable("F2Room", "scene_logo")
Global.SetVariable("Volume", {
    Master = 1,
    Music  = 1,
    Sounds = 1
})

local frameTime = 1 / Global.GetVariable("FPS")
local startTime = SE.timer.getTime()

local scene_
Scenes.switchTo("Overworld.scene_ow_main_0")
--Scenes.switchTo("TEST.scene_cc")
--Scenes.switchTo("scene_end")

ScreenScale = 1
DrawX, DrawY = 0, 0
local MAIN_CANVAS, INTERMEDIATE_CANVAS
local function updateScreenScale()
    local screen_w, screen_h = SE.graphics.getDimensions()
    ScreenScale = math.min(screen_w / CANVAS_WIDTH, screen_h / CANVAS_HEIGHT)
    DrawX = math.floor((screen_w - CANVAS_WIDTH * ScreenScale) * 0.5 + 0.5)
    DrawY = math.floor((screen_h - CANVAS_HEIGHT * ScreenScale) * 0.5 + 0.5)
end

function love.load()
    scene_ = Scenes.current

    MAIN_CANVAS = SE.graphics.newCanvas(CANVAS_WIDTH, CANVAS_HEIGHT, nil, {
        format = "stencil",
        readable = true
    })
    MAIN_CANVAS:setFilter("nearest", "nearest")

    INTERMEDIATE_CANVAS = SE.graphics.newCanvas(CANVAS_WIDTH, CANVAS_HEIGHT, nil, {
        format = "stencil",
        readable = true
    })
    INTERMEDIATE_CANVAS:setFilter("nearest", "nearest")

    updateScreenScale()
end

function love.update(dt)
    -- Libraries
    guard.Update(dt)
    Keyboard.Update()
    Tween.Update(dt)
    Sprites.Update(dt)
    Typers.Update(dt)
    Audio.Update(dt)
    Debugger.Update()
    Gamejolt.update(dt)

    scene_ = Scenes.current
    if (scene_.update and not scene_.pausing) then scene_.update(dt) end
    Camera:Update(dt)

    -- Frame Rate Control
    frameTime = 1 / Global.GetVariable("FPS")
    local endTime = SE.timer.getTime()
    local elapsedTime = endTime - startTime
    if (elapsedTime < frameTime) then
        local sleepTime = frameTime - elapsedTime
        SE.timer.sleep(sleepTime - 0.001)
        while (SE.timer.getTime() - startTime < frameTime) do end
    end
    startTime = SE.timer.getTime()
end

function love.draw()
    SE.graphics.setCanvas({MAIN_CANVAS, stencil = true})
    SE.graphics.clear(0, 0, 0, 1)

    Camera:apply()
    Layers.draw()
    if (scene_.draw) then
        scene_.draw()
    end
    Camera:unload()

    local shaders = Global.GetVariable("ScreenShaders") or {}
    local source = MAIN_CANVAS
    local target = INTERMEDIATE_CANVAS

    if (#shaders > 0) then
        for i, shader in ipairs(shaders) do
            SE.graphics.setCanvas(target)
            SE.graphics.clear(0, 0, 0, 0)
            SE.graphics.setShader(shader)
            SE.graphics.draw(source)
            SE.graphics.setShader()
            source, target = target, source
        end
    end

    SE.graphics.setCanvas()
    SE.graphics.clear(0, 0, 0, 1)

    SE.graphics.push()
    SE.graphics.translate(DrawX, DrawY)
    SE.graphics.scale(ScreenScale, ScreenScale)

    SE.graphics.setColor(1, 1, 1, 1)
    SE.graphics.draw(source)

    SE.graphics.pop()

    Debugger.Draw()
end

function love.keypressed(key, scancode, isrepeat)
    if (key == "f4") then
        local fullscreen = SE.window.getFullscreen()
        SE.window.setFullscreen(not fullscreen, "desktop")

        updateScreenScale()
        if (scene_.resize) then
            local w, h = SE.graphics.getDimensions()
            scene_.resize(w, h)
        end
        return
    elseif (key == "f2") then
        Localize.reload()
        Scenes.switchTo(Global.GetVariable("F2Room"))
    end
    if (not _RELEASED) then
        if (key == "f5") then
            Localize.reload()
            local sceneName = Scenes.name_current
            package.loaded["Scripts.Scenes." .. sceneName] = nil
            Scenes.switchTo(sceneName)
            return
        elseif (key == "f6") then
            print("=== Debug Info ===")
            print("FPS:", Global.GetVariable("FPS"))
            print("Screen:", love.graphics.getDimensions())
            print("Scale:", ScreenScale)
            print("Scene:", Scenes.name_current)
            print("Sprites:", #Sprites.images)
            print("Layers objects:", Layers.count())
            print("==================")
            return
        end
    end

    if (scene_.keypressed and not scene_.pausing) then scene_.keypressed(key, scancode, isrepeat) end
end

function love.keyreleased(key, scancode)
    if (scene_.keyreleased and not scene_.pausing) then scene_.keyreleased(key, scancode) end
end

function love.textinput(text)
    if (scene_.textinput and not scene_.pausing) then scene_.textinput(text) end
end

function love.mousepressed(x, y, button, istouch, presses)
    if (scene_.mousepressed and not scene_.pausing) then scene_.mousepressed(x, y, button, istouch, presses) end
end

function love.mousereleased(x, y, button, istouch, presses)
    if (scene_.mousereleased and not scene_.pausing) then scene_.mousereleased(x, y, button, istouch, presses) end
end

function love.mousemoved(x, y, dx, dy, istouch)
    if (scene_.mousemoved and not scene_.pausing) then scene_.mousemoved(x, y, dx, dy, istouch) end
end

function love.wheelmoved(x, y)
    if (scene_.wheelmoved and not scene_.pausing) then scene_.wheelmoved(x, y) end
end

function love.focus(f)
    if (scene_.focus and not scene_.pausing) then scene_.focus(f) end
end

function love.resize(w, h)
    updateScreenScale()
    if (scene_.resize and not scene_.pausing) then scene_.resize(w, h) end
end

function love.visible(v)
    if (scene_.visible and not scene_.pausing) then scene_.visible(v) end
end

function love.filedropped(file)
    if (scene_.filedropped and not scene_.pausing) then scene_.filedropped(file) end
end

function love.directorydropped(dir)
    if (scene_.directorydropped and not scene_.pausing) then scene_.directorydropped(dir) end
end

function love.quit()
    print("quitting")
    if (scene_.quit) then scene_.quit() end
end