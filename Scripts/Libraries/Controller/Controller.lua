--[[
    Controller.lua - Unified multi-device input accessor.

    Provides two layers of integration so game code works no matter which
    device the player uses:

    1) Mirror bridge (Controller.Update)
       The game's existing code reads input via Keyboard.GetState("left") /
       "confirm" / "cancel" / "up" / "down" / "right" / "menu" / "shift".
       This bridge copies the gamepad's logical states into Keyboard's
       simulated keys every frame, so e.g. pushing the left stick (leftx < 0)
       is EXACTLY equivalent to holding the "left" key, and "a" is exactly
       equivalent to holding the "confirm" key. No existing call sites need
       to change.

    2) Unified query (Controller.GetState)
       Merges Keyboard (which now includes the mirrored gamepad) and Joystick
       into a single call, with bind-style priority:
           1 = just pressed, 2 = held, -1 = just released, 0 = released
--]]

local Controller = {
    -- logical names mirrored from the gamepad onto Keyboard keys
    mirror = { "up", "down", "left", "right", "confirm", "cancel", "menu", "shift" },
    mirrorPressed = {},      -- name -> boolean (whether we currently mirror it)
    enableMirror = true,     -- set false to disable the mirror bridge
    deadzone = 0.15,         -- analog deadzone (kept in sync with Joystick; filtering happens in Joystick.GetAxis)
}

--- Release any keyboard keys we previously mirrored (used when the gamepad
--- disconnects or input is disabled so nothing gets stuck held).
local function releaseMirrored()
    for name, wasPressed in pairs(Controller.mirrorPressed) do
        if (wasPressed and Keyboard and Keyboard.SimulateRelease) then
            Keyboard.SimulateRelease(name)
        end
        Controller.mirrorPressed[name] = false
    end
end

--- Call every frame BEFORE Keyboard.Update() (main.lua -> love.update).
--- Mirrors the gamepad's logical states onto Keyboard keys so the game's
--- existing Keyboard.GetState() calls respond to the gamepad too.
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

--- Return a smooth -1..1 movement vector from the gamepad's left stick,
--- falling back to the digital arrow keys / dpad when the stick is centered.
---@return number, number
function Controller.GetVector()
    local x, y = 0, 0
    if (Joystick and Joystick.GetAxis) then
        -- Joystick.GetAxis already applies the dead-zone + re-scaling: a
        -- centered stick reads 0, anything past the dead-zone is a smooth 0..1.
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

--- Set the analog dead-zone (default 0.15). Forwards to Joystick so filtering
--- is centralized (applied inside Joystick.GetAxis); keeps Controller.deadzone
--- in sync for anyone reading it directly.
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

--- Return a list of devices that currently contribute a non-zero state
--- for the given name (useful for debugging / "which device did that").
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
