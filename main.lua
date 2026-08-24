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
Keyboard = ImportFile("Controller.Keyboard")
Joystick = ImportFile("Controller.Joystick")
VirtualKeyboard = ImportFile("Controller.VirtualKeyboard")
Controller = ImportFile("Controller.Controller")
Scenes = ImportFile("SceneManager")
Layers = ImportFile("Layers")
Sprites = ImportFile("Sprites")
Typers = ImportFile("Typers")
Debugger = ImportFile("Engine.Debugger")
Gamejolt = ImportFile("GamejoltAPI")
Discord = ImportFile("DiscordRPC")
ImportFile("Engine.PureConf")
Localize = ImportFile("Localize")
Localize.setFile(Global.GetVariable("Language"))

-- Controller simulation (see Engine/PureConf.lua "ControllerSimulation").
-- Lets you test the virtual keyboard / gamepad on desktop without real hardware.
local _controllerSim = Global.GetVariable("ControllerSimulation")
if (_controllerSim) then
    if (_controllerSim.virtualKeyboard) then
        VirtualKeyboard.SetEnabled(true)
    end
    if (_controllerSim.joystick) then
        Joystick.SimulateConnection(true)
    end
end

local frameTime = 1 / Global.GetVariable("FPS")
local startTime = SE.timer.getTime()

local scene_
Scenes.switchTo(Global.GetVariable("FirstRoom"))

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
    -- Load the initial (deferred) scene synchronously so scene_ is set before
    -- any love.* event (e.g. love.resize) can fire ahead of the first update.
    Scenes.flushPendingSwitch()
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

    Discord.init()
end

function love.update(dt)
    -- Process any scene switch queued during the previous frame's callbacks
    -- (prevents re-entrant switchTo from overflowing the stack).
    Scenes.flushPendingSwitch()

    -- Libraries
    Guard.Update(dt)
    -- Order matters: poll the gamepad, mirror it onto Keyboard's simulated
    -- keys, then let Keyboard.Update() finalize all key states before the
    -- scene reads them. This makes the gamepad act exactly like the keyboard.
    Joystick.Update()
    Controller.Update()
    Keyboard.Update()
    VirtualKeyboard.Update()
    Tween.Update(dt)
    Sprites.Update(dt)
    Typers.Update(dt)
    Audio.Update(dt)
    Debugger.Update()
    Gamejolt.update(dt)
    Discord.update(dt)

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

    -- On-screen virtual keyboard overlay (drawn in screen space)
    VirtualKeyboard.Draw()
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
        package.loaded["Scripts.Libraries.Engine.PureConf"] = nil
        ImportFile("Engine.PureConf")
        Scenes.switchTo(Global.GetVariable("F2Room"))
    end
    if (not _RELEASED) then
        if (key == "f5") then
            Localize.reload()
            local sceneName = Scenes.name_current
            package.loaded["Scripts.Scenes." .. sceneName] = nil
            Scenes.switchTo(sceneName)
            --Scenes.switchTo("scene_logo")
            return
        elseif (key == "f6") then
            print("=== Debug Info ===")
            print("FPS:", Global.GetVariable("FPS"))
            print("Screen:", love.graphics.getDimensions())
            print("Scale:", ScreenScale)
            print("Scene:", Scenes.name_current)
            local _dev = Controller.GetDevices()
            print("Input: VK=" .. tostring(_dev.virtualKeyboard) .. " Gamepads=" .. tostring(_dev.joystickCount))
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
    local consumed = false
    if (button == 1 and not istouch) then
        -- Desktop simulation: clicking the virtual keyboard acts like touch
        consumed = VirtualKeyboard.MousePressed(x, y)
    end
    if (not consumed and scene_.mousepressed and not scene_.pausing) then scene_.mousepressed(x, y, button, istouch, presses) end
end

function love.mousereleased(x, y, button, istouch, presses)
    local consumed = false
    if (button == 1 and not istouch) then
        consumed = VirtualKeyboard.MouseReleased(x, y)
    end
    if (not consumed and scene_.mousereleased and not scene_.pausing) then scene_.mousereleased(x, y, button, istouch, presses) end
end

function love.mousemoved(x, y, dx, dy, istouch)
    if (scene_.mousemoved and not scene_.pausing) then scene_.mousemoved(x, y, dx, dy, istouch) end
end

-- Touchscreen input (mobile). Feed the Keyboard touch tracker and the virtual
-- keyboard; also forward to the current scene if the virtual keyboard didn't consume it.
function love.touchpressed(id, x, y, dx, dy, pressure)
    Keyboard.TouchPressed(id, x, y)
    local consumed = VirtualKeyboard.TouchPressed(id, x, y)
    if (not consumed and scene_.touchpressed and not scene_.pausing) then
        scene_.touchpressed(id, x, y, dx, dy, pressure)
    end
end

function love.touchmoved(id, x, y, dx, dy, pressure)
    Keyboard.TouchMoved(id, x, y)
    VirtualKeyboard.TouchMoved(id, x, y)
    if (scene_.touchmoved and not scene_.pausing) then
        scene_.touchmoved(id, x, y, dx, dy, pressure)
    end
end

function love.touchreleased(id, x, y, dx, dy, pressure)
    Keyboard.TouchReleased(id, x, y)
    local consumed = VirtualKeyboard.TouchReleased(id, x, y)
    if (not consumed and scene_.touchreleased and not scene_.pausing) then
        scene_.touchreleased(id, x, y, dx, dy, pressure)
    end
end

-- External gamepad connection events
function love.joystickadded(joystick)
    Joystick.Connect(joystick)
end

function love.joystickremoved(joystick)
    Joystick.Disconnect(joystick)
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
    Discord.shutdown()
    if (scene_.quit) then scene_.quit() end
end