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
require("Scripts.Libraries.Engine.PathDefiner")
SE = ImportFile("Engine.FuncProtector")
print("Configuration loaded, engine version: " .. _VER)
print("配置已加载成功，引擎版本:             " .. _VER .. "\n")

LuaEX = ImportFile("Utils.LuaExtended")
Global = ImportFile("Global")
-- Every font load goes through Fonts.New: Game/Resources/Fonts wins over
-- Resources/Fonts, so a game can swap any typeface by dropping a same-named file.
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
-- Must load after Typers (Label wraps InstText) and Layers.
GUI = ImportFile("GUI")
-- Dev-only modules: nil in release builds (_RELEASED); call sites are nil-guarded.
if (not _RELEASED) then
    Debugger = ImportFile("Engine.Debugger")
    DevTool = ImportFile("Engine.DevTool")
    -- e-n-d unlocks it, F10 opens the wave picker.
    DevMode = ImportFile("Engine.DevMode")
else
    Debugger = nil
    DevTool = nil
    DevMode = nil
end
Gamejolt = ImportFile("GamejoltAPI")
Discord = ImportFile("DiscordRPC")
-- Root conf_pure.lua (defaults), then Game/conf_pure.lua (overrides); F2 re-runs both.
Conf = ImportFile("Engine.GameConf")
Conf.Load()
ImportFile("Engine.2_0")
Localize = ImportFile("Localize")
Localize.setFile(Global.GetVariable("Language"))
Border = ImportFile("Utils.Border")
Border.SetEnabled(false)
Border.FadeIn(0)
math.randomseed()

-- Simulate virtual keyboard / gamepad on desktop (PureConf "ControllerSimulation").
local _controllerSim = Global.GetVariable("ControllerSimulation")
if (_controllerSim) then
    if (_controllerSim.virtualKeyboard) then
        VirtualKeyboard.SetEnabled(true)
    end
    if (_controllerSim.joystick) then
        Joystick.SimulateConnection(true)
    end
end

-- Analog stick dead-zone (PureConf "ControllerDeadzone").
local _deadzone = Global.GetVariable("ControllerDeadzone")
if (_deadzone ~= nil) then
    Controller.SetDeadzone(_deadzone)
end

-- Game-side hacks (Game/Hacks/) load after every engine library and before the
-- first scene, so a hack can patch engine modules without editing Scripts/.
Hack = ImportFile("Engine.HackLoader")
Hack.Load()

local frameTime = 1 / Global.GetVariable("FPS")
local startTime = SE.timer.getTime()

local scene_
Scenes.switchTo(Global.GetVariable("FirstRoom"))

ScreenScale = 1
DrawX, DrawY = 0, 0
local MAIN_CANVAS, INTERMEDIATE_CANVAS

-- SCREEN_SCALE (conf.lua) decides how big the game canvas is drawn; the canvas
-- is always dead-centre and Border uses the same scale, so they cannot drift.
-- Legacy: SCREEN_SCALE nil -> FILL_SCREEN ("auto" fullscreen, 1:1 otherwise).
local screenScaleMode = SCREEN_SCALE
if (screenScaleMode == nil) then
    screenScaleMode = FILL_SCREEN and "auto" or false
end

local function updateScreenScale()
    local screen_w, screen_h = SE.graphics.getDimensions()

    -- BORDER_MODE scales by the Border art instead of the canvas, so the frame
    -- fits the window and the canvas drops into its inner opening. Otherwise the
    -- canvas itself is fit to the window and no frame is drawn.
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

        -- Canvas opening inside the Border art; Border.SetOpening() can override it.
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
        -- Pixel-perfect: whole multiples; shrink if the window is smaller.
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

function love.load()
    -- Flush the deferred scene synchronously so scene_ is set before any love.*
    -- event (e.g. love.resize) can fire ahead of the first update.

    -- Default frame, lazy-loaded; scenes switch via Border.SetImage / FadeIn.
    Border.SetImage("ruins")

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

    Discord.application_id = Global.GetVariable("DiscordAppID")

    -- DiscordRPC fails silently unless these callbacks are hooked.
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
            large_image = "qq20250220-225345",
            large_text  = "It's a bad time.",
            start       = Discord.timestamp(),   -- elapsed timer
        })
        if (not ok_act) then
            print("[DiscordRPC] setActivity() FAILED: " .. tostring(err_act))
        end
    end
end

function love.update(dt)
    dt = math.min(dt, 1 / 20)

    -- Scene switches are queued so a switchTo during callbacks is not re-entrant.
    Scenes.flushPendingSwitch()

    Border.Update(dt)
    Guard.Update(dt)
    -- Order matters: poll the gamepad, mirror it onto Keyboard's simulated keys,
    -- then Keyboard.Update() finalises all key states before the scene reads them.
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

function love.draw()
    SE.graphics.setCanvas({MAIN_CANVAS, stencil = true})
    -- Clear colour AND stencil: a stencil left over from one wave leaks into
    -- every later wave, so the mask buffer must be zeroed per frame.
    SE.graphics.clear(0, 0, 0, 1, true, false, true)

    Camera:apply()
    Layers.draw()
    if (scene_.draw) then
        scene_.draw()
    end
    Camera:unload()
    -- Drawn in canvas space: a scene switch or camera move must not shift it.
    if (DevMode and DevMode.Draw) then DevMode.Draw() end

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

    -- Border frame, drawn BEHIND the gameplay canvas at the same scale and
    -- aligned to its rectangle. Only in BORDER_MODE, where the screen is already
    -- sized to the frame, so it cannot overflow.
    if (BORDER_MODE) then
        Border.Draw()
    end

    SE.graphics.push()
    SE.graphics.translate(DrawX, DrawY)
    SE.graphics.scale(ScreenScale, ScreenScale)

    SE.graphics.setColor(1, 1, 1, 1)
    SE.graphics.draw(source)
    if (not Border.enabled) then
        local r, g, b = unpack(Global.GetVariable("MainColor"))
        SE.graphics.setLineWidth(2)
        SE.graphics.rectangle("line", -1, -1, 642, 482)
    end
    SE.graphics.pop()

    if (Debugger and Debugger.Draw) then Debugger.Draw() end

    -- DevTool renders its own canvas and pushes it into the SDL child window.
    if (DevTool and DevTool.Draw) then DevTool.Draw() end

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
        -- Re-execute BOTH config scripts (root defaults + Game overrides).
        if (Conf and Conf.Load) then Conf.Load() end
        Scenes.switchTo(Global.GetVariable("F2Room"))
    end
    if (not _RELEASED) then
        if (DevTool and DevTool.Toggle and key == "f8") then
            DevTool.Toggle()
            return
        elseif (key == "f5") then
            Localize.reload()
            -- Unapply the hacks BEFORE dropping the patched modules, so Load()
            -- re-applies onto fresh tables instead of stacking wrappers.
            if (Hack and Hack.Unapply) then Hack.Unapply() end
            ClearModuleTree("Scripts.Libraries")
            -- Game content is a second root: without this, Game/Souls,
            -- Game/Encounter ... keep their module-level state across a reload.
            ClearGameTree()
            local sceneName = Scenes.name_current
            -- Unload whichever copy was loaded (Game area or root).
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

    -- The panel swallows its own keys (arrows / confirm must not reach the
    -- battle menu underneath); otherwise it only watches the unlock sequence and F10.
    if (DevMode and DevMode.HandleKey and DevMode.HandleKey(key, isrepeat)) then
        return
    end

    -- SDL child-window keys are unreliable, so forward them from the main window
    -- (only while the tool has focus or the mouse hovers it); the scene still gets them.
    if (not _RELEASED) and DevTool and DevTool.HandleKey and DevTool.WantsKeys then
        local _devShift = love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift")
        DevTool.HandleKey(key, isrepeat, _devShift)
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
    -- Losing focus delivers no mouse/touch releases: drop held virtual keys so
    -- nothing stays stuck down in the background.
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

function love.quit()
    print("quitting")
    Discord.shutdown()
    if (scene_.quit) then scene_.quit() end
end