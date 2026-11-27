-- Main entry point. Bootstraps the engine globals, then forwards LOVE's
-- callbacks to whichever scene is currently active.

-- Console and input bootstrap: the engine feeds characters itself, so LOVE's own
-- text input stays off; on Windows the console switches to UTF-8 for CJK logs.
love = require("love")
love.keyboard.setTextInput(false)
if (not _RELEASED) then
    if (love.system.getOS() == "Windows") then
        local handle = io.popen("chcp 65001", "r")
        if (handle) then
            handle:close()
        end
    end
end

-- Path resolution first, so ImportFile knows where to look; FuncProtector wraps
-- love.* and becomes the SE global used by everything below.
require("Scripts.Libraries.Engine.PathDefiner")
SE = ImportFile("Engine.FuncProtector")
print("Configuration loaded, engine version: " .. _VER)
print("配置已加载成功，引擎版本:             " .. _VER .. "\n")

-- Engine libraries, exposed as globals so scenes and hacks can use them without
-- requiring anything. Order matters: later entries depend on earlier ones.
LuaEX = ImportFile("Utils.LuaExtended")
Global = ImportFile("Global")
Fonts = ImportFile("Fonts")
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
GUI = ImportFile("GUI")

-- Development-only tools; they are dropped to nil in released builds, along with
-- the hotkeys that open them.
if (not _RELEASED) then
    Debugger = ImportFile("Engine.Debugger")
    DevTool = ImportFile("Engine.DevTool")
    DevMode = ImportFile("Engine.DevMode")
else
    Debugger = nil
    DevTool = nil
    DevMode = nil
end
Gamejolt = ImportFile("GamejoltAPI")
Discord = ImportFile("DiscordRPC")

-- Runtime setup that needs the libraries above: game config, the 2.0 compat
-- layer, localization, the window border and the RNG seed.
Conf = ImportFile("Engine.GameConf")
Conf.Load()
ImportFile("Engine.2_0")
Localize = ImportFile("Localize")
Localize.setFile(Global.GetVariable("Language"))
Border = ImportFile("Utils.Border")
Border.SetEnabled(true)
Border.FadeIn(0)
math.randomseed()

-- Controller options from the game config: fake input devices for testing, and
-- the analog deadzone applied to real ones.
local _controllerSim = Global.GetVariable("ControllerSimulation")
if (_controllerSim) then
    if (_controllerSim.virtualKeyboard) then
        VirtualKeyboard.SetEnabled(true)
    end
    if (_controllerSim.joystick) then
        Joystick.SimulateConnection(true)
    end
end
local _deadzone = Global.GetVariable("ControllerDeadzone")
if (_deadzone ~= nil) then
    Controller.SetDeadzone(_deadzone)
end

-- Hacks are applied before the first scene loads, so a patch can already replace
-- gameplay code from the very first frame.
Hack = ImportFile("Engine.HackLoader")
Hack.Load()

-- Frame pacing clock; frameTime is refreshed every frame because the FPS setting
-- can change at runtime. Then the startup scene.
local frameTime = 1 / Global.GetVariable("FPS")
local startTime = SE.timer.getTime()

local scene_
Scenes.switchTo(Global.GetVariable("FirstRoom"))

-- Canvas-to-window transform. ScreenScale, DrawX and DrawY are globals because
-- scenes, GUI and mouse conversion read them directly.
ScreenScale = 1
DrawX, DrawY = 0, 0
local MAIN_CANVAS, INTERMEDIATE_CANVAS

local screenScaleMode = SCREEN_SCALE
if (screenScaleMode == nil) then
    screenScaleMode = FILL_SCREEN and "auto" or false
end

-- Recomputes the scale and the canvas offset for the current window size.
-- With BORDER_MODE the whole border is fitted first, then the offset is pushed
-- inwards by the opening inside the border art.
local function updateScreenScale()
    local screen_w, screen_h = SE.graphics.getDimensions()

    if (BORDER_MODE) then
        local bw = BORDER_WIDTH or CANVAS_WIDTH
        local bh = BORDER_HEIGHT or CANVAS_HEIGHT
        local borderFit = math.min(screen_w / bw, screen_h / bh)
        if (borderFit <= 0 or borderFit ~= borderFit) then borderFit = 1 end

        if (screenScaleMode == "integer") then
            local whole = math.floor(borderFit)
            ScreenScale = (whole >= 1) and whole or borderFit
        else
            ScreenScale = borderFit
        end

        local ox, oy = Border.GetOpening(bw, bh)
        local borderDrawX = math.floor((screen_w - bw * ScreenScale) * 0.5 + 0.5)
        local borderDrawY = math.floor((screen_h - bh * ScreenScale) * 0.5 + 0.5)
        DrawX = borderDrawX + math.floor(ox * ScreenScale + 0.5)
        DrawY = borderDrawY + math.floor(oy * ScreenScale + 0.5)
        return
    end

    local fit = math.min(screen_w / CANVAS_WIDTH, screen_h / CANVAS_HEIGHT)
    if (fit <= 0 or fit ~= fit) then fit = 1 end

    if (screenScaleMode == "integer") then
        local whole = math.floor(fit)
        ScreenScale = (whole >= 1) and whole or fit
    elseif (screenScaleMode == "auto" or screenScaleMode == true) then
        ScreenScale = fit
    elseif (type(screenScaleMode) == "number" and screenScaleMode > 0) then
        ScreenScale = screenScaleMode
    else
        ScreenScale = 1
    end

    DrawX = math.floor((screen_w - CANVAS_WIDTH * ScreenScale) * 0.5 + 0.5)
    DrawY = math.floor((screen_h - CANVAS_HEIGHT * ScreenScale) * 0.5 + 0.5)
end

--- Change how the game screen is scaled at runtime.
---@param mode string|number|boolean "integer" | "auto" | number | false
function SetScreenScale(mode)
    screenScaleMode = mode
    updateScreenScale()
end

--- The multiplier currently applied to the game canvas.
---@return number
function GetScreenScale()
    return ScreenScale
end

-- Startup: pick the border art, let the queued scene switch settle, allocate the
-- two canvases, then bring up Discord Rich Presence.
function love.load()

    Border.SetImage("snowy.png")

    Scenes.flushPendingSwitch()
    scene_ = Scenes.current

    -- Readable stencil canvases: scenes draw into MAIN_CANVAS, and the screen
    -- shader chain ping-pongs between it and INTERMEDIATE_CANVAS.
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

    -- Discord Rich Presence. Failures only print a line: a missing or closed
    -- Discord client must never stop the game.
    Discord.application_id = Global.GetVariable("DiscordAppID")

    Discord.onReady(function(user)
        print("[DiscordRPC] READY  app=" .. tostring(Discord.application_id) ..
              "  user=" .. tostring(user and user.username))
    end)
    Discord.onDisconnected(function(code, msg)
        print("[DiscordRPC] DISCONNECTED  code=" .. tostring(code) .. "  msg=" .. tostring(msg))
    end)
    Discord.onError(function(code, msg)
        print("[DiscordRPC] ERROR  code=" .. tostring(code) .. "  msg=" .. tostring(msg))
    end)

    local ok_init, err_init = Discord.init()
    if (not ok_init) then
        print("[DiscordRPC] init() FAILED: " .. tostring(err_init))
    else
        local ok_act, err_act = Discord.setActivity({
            details     = "Fighting Sans",
            state       = "Route: Genocide",
            large_image = "icon",
            large_text  = "SoulEngine",
            start       = Discord.timestamp(),
        })
        if (not ok_act) then
            print("[DiscordRPC] setActivity() FAILED: " .. tostring(err_act))
        end
    end
end

-- Per-frame update. A long stall (loading, window drag, breakpoint) is clamped
-- so sprites cannot tunnel through walls or skip collision checks.
function love.update(dt)
    dt = math.min(dt, 1 / 20)

    Scenes.flushPendingSwitch()

    -- Global systems first (border, input, tweens, sprites, audio, dev tools);
    -- the scene and the camera come after.
    Border.Update(dt)
    Guard.Update(dt)
    Joystick.Update()
    Controller.Update()
    Keyboard.Update()
    VirtualKeyboard.Update()
    Tween.Update(dt)
    Sprites.Update(dt)
    Typers.Update(dt)
    Audio.Update(dt)
    if (Debugger and Debugger.Update) then Debugger.Update() end
    if (DevTool and DevTool.Update) then DevTool.Update(dt) end
    if (DevMode and DevMode.Update) then DevMode.Update(dt) end
    Gamejolt.update(dt)
    Discord.update(dt)

    scene_ = Scenes.current
    if (scene_.update and not scene_.pausing) then scene_.update(dt) end
    Camera:Update(dt)

    -- Software frame limiter: sleep the remaining budget, then spin until the
    -- frame time is spent, so the FPS setting wins over the monitor refresh rate.
    frameTime = 1 / Global.GetVariable("FPS")
    local endTime = SE.timer.getTime()
    local elapsedTime = endTime - startTime
    if (elapsedTime < frameTime) then
        local sleepTime = frameTime - elapsedTime
        if (sleepTime > 2) then
            print(debug.traceback())
            SE.timer.sleep(sleepTime - 0.001)
        else
            SE.timer.sleep(sleepTime - 0.001)
        end
        while (SE.timer.getTime() - startTime < frameTime) do end
    end
    startTime = SE.timer.getTime()
end

-- Draw pass, in order: scene -> screen shaders -> window (border plus scaled
-- canvas) -> debug overlays.
function love.draw()
    -- Scene pass: everything lands on MAIN_CANVAS at game resolution, with the
    -- camera transform applied and the stencil buffer cleared.
    SE.graphics.setCanvas({MAIN_CANVAS, stencil = true})
    SE.graphics.clear(0, 0, 0, 1, true, false, true)

    Camera:apply()
    Layers.draw()
    if (scene_.draw) then
        scene_.draw()
    end
    Camera:unload()
    if (DevMode and DevMode.Draw) then DevMode.Draw() end

    -- Optional post-process chain. Each shader reads one canvas and writes the
    -- other; source and target swap so the final image ends up in source.
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

    -- Present to the window: clear it, paint the border art if enabled, then blit
    -- the canvas at DrawX/DrawY with ScreenScale applied.
    SE.graphics.setCanvas()
    SE.graphics.clear(0, 0, 0, 1)

    if (BORDER_MODE) then
        Border.Draw()
    end

    SE.graphics.push()
    SE.graphics.translate(DrawX, DrawY)
    SE.graphics.scale(ScreenScale, ScreenScale)

    SE.graphics.setColor(1, 1, 1, 1)
    SE.graphics.draw(source)
    if (BORDER_MODE and not Border.enabled) then
        local r, g, b = unpack(Global.GetVariable("MainColor") or {1, 1, 1})
        SE.graphics.setColor(r, g, b, 1)
        SE.graphics.setLineWidth(2)
        SE.graphics.rectangle("line", -1, -1, 642, 482)
        SE.graphics.setColor(1, 1, 1, 1)
    end
    SE.graphics.pop()

    -- Debug overlays draw in window space, outside the scaled transform.
    if (Debugger and Debugger.Draw) then Debugger.Draw() end

    if (DevTool and DevTool.Draw) then DevTool.Draw() end

    VirtualKeyboard.Draw()
end

-- Global hotkeys run before the scene, so a scene can never swallow them:
-- F4 toggles fullscreen, F2 reloads localization and re-enters the F2 room.
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
        if (Conf and Conf.Load) then Conf.Load() end
        Scenes.switchTo(Global.GetVariable("F2Room"))
    end

    -- Development hotkeys, skipped in releases: F8 dev tool, F5 hot reload,
    -- F6 debug dump. F5 drops both module trees and re-enters the same scene.
    if (not _RELEASED) then
        if (DevTool and DevTool.Toggle and key == "f8") then
            DevTool.Toggle()
            return
        elseif (key == "f5") then
            Localize.reload()
            if (Hack and Hack.Unapply) then Hack.Unapply() end
            ClearModuleTree("Scripts.Libraries")
            ClearGameTree()
            local sceneName = Scenes.name_current
            if (Scenes.UnloadModule) then
                Scenes.UnloadModule(sceneName)
            else
                package.loaded["Scripts.Scenes." .. sceneName] = nil
            end
            Scenes.switchTo(sceneName)
            if (Hack and Hack.Load) then Hack.Load() end
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
            if (Hack and Hack.Report) then Hack.Report() end
            print("==================")
            return
        end
    end

    if (DevMode and DevMode.HandleKey and DevMode.HandleKey(key, isrepeat)) then
        return
    end

    if (not _RELEASED) and DevTool and DevTool.HandleKey and DevTool.WantsKeys then
        local _devShift = love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift")
        DevTool.HandleKey(key, isrepeat, _devShift)
    end

    -- Only keys no global handler consumed reach the scene.
    if (scene_.keypressed and not scene_.pausing) then scene_.keypressed(key, scancode, isrepeat) end
end

-- Input and window events are forwarded to the scene and skipped while it is
-- pausing. Mouse and touch pass through the on-screen keyboard first: if a
-- virtual key takes the event, the scene never sees it.
function love.keyreleased(key, scancode)
    if (scene_.keyreleased and not scene_.pausing) then scene_.keyreleased(key, scancode) end
end

function love.textinput(text)
    if (scene_.textinput and not scene_.pausing) then scene_.textinput(text) end
end

function love.mousepressed(x, y, button, istouch, presses)
    if (DevMode and DevMode.MousePressed and DevMode.MousePressed(x, y, button)) then
        return
    end

    local consumed = false
    if (button == 1 and not istouch) then
        consumed = VirtualKeyboard.MousePressed(x, y)
    end
    if (not consumed and scene_.mousepressed and not scene_.pausing) then scene_.mousepressed(x, y, button, istouch, presses) end
end

function love.mousereleased(x, y, button, istouch, presses)
    if (DevMode and DevMode.MouseReleased and DevMode.MouseReleased(x, y, button)) then
        return
    end

    local consumed = false
    if (button == 1 and not istouch) then
        consumed = VirtualKeyboard.MouseReleased(x, y)
    end
    if (not consumed and scene_.mousereleased and not scene_.pausing) then scene_.mousereleased(x, y, button, istouch, presses) end
end

function love.mousemoved(x, y, dx, dy, istouch)
    if (DevMode and DevMode.MouseMoved) then DevMode.MouseMoved(x, y) end
    VirtualKeyboard.MouseMoved(x, y)
    if (scene_.mousemoved and not scene_.pausing) then scene_.mousemoved(x, y, dx, dy, istouch) end
end

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

function love.joystickadded(joystick)
    Joystick.Connect(joystick)
end

function love.joystickremoved(joystick)
    Joystick.Disconnect(joystick)
end

function love.wheelmoved(x, y)
    if (DevMode and DevMode.WheelMoved and DevMode.WheelMoved(x, y)) then
        return
    end
    if (scene_.wheelmoved and not scene_.pausing) then scene_.wheelmoved(x, y) end
end

function love.focus(f)
    if (not f) then VirtualKeyboard.ReleaseAll() end
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

-- Shut down Rich Presence, then let the scene save or clean up before exit.
function love.quit()
    print("quitting")
    Discord.shutdown()
    if (scene_.quit) then scene_.quit() end
end