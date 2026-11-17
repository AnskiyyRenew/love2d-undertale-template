--[[
    Controller.lua - unified multi-device input (Keyboard + Joystick).
    Controller.Update mirrors the gamepad onto Keyboard's simulated keys;
    Controller.GetState merges both devices (1/2/-1/0, bind-style priority).
]]

local Controller = {
    -- logical names mirrored from the gamepad onto Keyboard keys
    mirror = { "up", "down", "left", "right", "confirm", "cancel", "menu", "shift" },
    mirrorPressed = {},      -- name -> boolean (whether we currently mirror it)
    enableMirror = true,     -- set false to disable the mirror bridge
    deadzone = 0.15,         -- analog deadzone; filtering happens in Joystick.GetAxis
}

--- Release every key this bridge mirrored (gamepad disconnect / input off).
local function releaseMirrored()
    for name, wasPressed in pairs(Controller.mirrorPressed) do
        if (wasPressed and Keyboard and Keyboard.SimulateRelease) then
            Keyboard.SimulateRelease(name)
        end
        Controller.mirrorPressed[name] = false
    end
end

--- Call every frame BEFORE Keyboard.Update(), so the game's GetState() calls
--- already see the gamepad.
function Controller.Update()
    local mirroring = Controller.enableMirror
        and (Keyboard and Keyboard.allowInput ~= false)
        and (Joystick and Joystick.IsConnected and Joystick.IsConnected())

    if (not mirroring) then
        releaseMirrored()
        return
    end

    for _, name in ipairs(Controller.mirror) do
        local down = Joystick.IsDown(name)
        local prev = Controller.mirrorPressed[name]
        if (down and not prev) then
            Keyboard.SimulatePress(name)
            Controller.mirrorPressed[name] = true
        elseif (not down and prev) then
            Keyboard.SimulateRelease(name)
            Controller.mirrorPressed[name] = false
        end
    end
end

--- Unified state query for a logical name (button, bind, or key).
---@param name string
---@return integer
function Controller.GetState(name)
    local ks = (Keyboard and Keyboard.GetState) and Keyboard.GetState(name) or 0
    local js = (Joystick and Joystick.GetState) and Joystick.GetState(name) or 0

    local anyPressed = false
    local anyJustPressed = false
    local anyJustReleased = false

    if (ks == 1) then anyJustPressed = true
    elseif (ks == 2) then anyPressed = true
    elseif (ks == -1) then anyJustReleased = true end

    if (js == 1) then anyJustPressed = true
    elseif (js == 2) then anyPressed = true
    elseif (js == -1) then anyJustReleased = true end

    if (anyJustPressed) then
        return 1
    elseif (anyPressed) then
        return 2
    elseif (anyJustReleased) then
        return -1
    end
    return 0
end

--- Return true if a logical name is currently held on any device.
---@param name string
---@return boolean
function Controller.IsDown(name)
    return Controller.GetState(name) >= 1
end

--- Unified analog axis read (from the gamepad; no axes on keyboard/touch yet).
---@param name string
---@return number
function Controller.GetAxis(name)
    if (Joystick and Joystick.GetAxis) then
        return Joystick.GetAxis(name)
    end
    return 0
end

--- Return a smooth -1..1 movement vector from the left stick, falling back to
--- the digital arrows when the stick is centered.
---@return number, number
function Controller.GetVector()
    local x, y = 0, 0
    if (Joystick and Joystick.GetAxis) then
        -- GetAxis already applies the dead-zone and re-scales to 0..1.
        x = Joystick.GetAxis("leftx")
        y = Joystick.GetAxis("lefty")
    end
    if (x == 0) then
        if (Controller.IsDown("right")) then x = 1
        elseif (Controller.IsDown("left")) then x = -1 end
    end
    if (y == 0) then
        if (Controller.IsDown("down")) then y = 1
        elseif (Controller.IsDown("up")) then y = -1 end
    end
    return x, y
end

--- Set the analog dead-zone (default 0.15). Forwards to Joystick, where the
--- filtering actually happens.
---@param v number
function Controller.SetDeadzone(v)
    if (v ~= nil) then Controller.deadzone = v end
    if (Joystick and Joystick.SetDeadzone) then Joystick.SetDeadzone(v) end
end

--- Enable / disable the gamepad -> keyboard mirror bridge (default on).
---@param bool boolean
function Controller.SetMirrorEnabled(bool)
    Controller.enableMirror = not not bool
    if (not Controller.enableMirror) then releaseMirrored() end
end

--- Devices that currently report a non-zero state for `name` (debug aid).
---@param name string
---@return table
function Controller.GetSource(name)
    local out = {}
    if (Keyboard and Keyboard.GetState) then
        local s = Keyboard.GetState(name)
        if (s ~= 0) then table.insert(out, { device = "Keyboard", state = s }) end
    end
    if (Joystick and Joystick.GetState) then
        local s = Joystick.GetState(name)
        if (s ~= 0) then table.insert(out, { device = "Joystick", state = s }) end
    end
    return out
end

--- Summary of what is currently connected (for debug / pause menus).
---@return table
function Controller.GetDevices()
    local vkEnabled = VirtualKeyboard and VirtualKeyboard.enabled or false
    return {
        keyboard = true,
        joystickConnected = Joystick and Joystick.IsConnected() or false,
        joystickCount = Joystick and Joystick.GetCount() or 0,
        virtualKeyboard = vkEnabled,
    }
end

--- Enable / disable player input on every device at once.
---@param bool boolean
function Controller.AllowPlayerInput(bool)
    if (Keyboard and Keyboard.AllowPlayerInput) then Keyboard.AllowPlayerInput(bool) end
    if (Joystick and Joystick.AllowPlayerInput) then Joystick.AllowPlayerInput(bool) end
    if (not bool) then releaseMirrored() end
end

return Controller
