--[[
    Joystick.lua - Gamepad / Joystick controller

    Uses the SAME feedback convention as Keyboard.lua:
        state 0  = released
        state 1  = just pressed (this frame)
        state 2  = held
        state -1 = just released (this frame)

    Supports:
      * Auto-detection of connected gamepads (LÖVE standard gamepad mapping
        when available, raw numbered fallback otherwise).
      * Analog sticks & triggers as axis values AND as dead-zone buttons.
      * Binds (grouping several buttons/axes under one name).
      * Simulation so you can test on desktop without hardware
        (pair with the "ControllerSimulation" variable in PureConf.lua).
--]]

local Joystick = {
    joysticks = {},          -- array of connected LÖVE joystick objects
    enabled = true,          -- master switch (AllowPlayerInput)
    deadzone = 0.15,         -- analog deadzone (0..1)
    axisThreshold = 0.5,     -- value a trigger must exceed to count as a button press

    -- logical button name -> { pressed, pressaux, state }
    buttons = {},
    -- logical axis name -> current float value
    axes = {},

    -- bind name -> { keys = { ... } } (same concept as Keyboard.Bind)
    binds = {},

    -- simulation
    simulatedButtons = {},   -- name -> { pressed, pressaux, state }
    simulatedAxes = {},      -- name -> float value
    simulatedConnection = false, -- fake an active gamepad
}

-- LÖVE standard gamepad button names (used when joystick:isGamepad() is true)
local gamepadButtons = {
    "a", "b", "x", "y",
    "back", "guide", "start",
    "leftstick", "rightstick",
    "leftshoulder", "rightshoulder",
    "dpup", "dpdown", "dpleft", "dpright",
}

-- Analog gamepad axes (reported as axis values)
local gamepadAxisNames = {
    "leftx", "lefty", "rightx", "righty", "triggerleft", "triggerright",
}

-- Analog axes -> virtual button names (dead-zone / threshold driven)
local axisButtonMaps = {
    { axis = "leftx",        negative = "leftstickleft",  positive = "leftstickright" },
    { axis = "lefty",        negative = "leftstickup",     positive = "leftstickdown" },
    { axis = "rightx",       negative = "rightstickleft", positive = "rightstickright" },
    { axis = "righty",       negative = "rightstickup",    positive = "rightstickdown" },
    { axis = "triggerleft",  trigger = "triggerleft" },
    { axis = "triggerright", trigger = "triggerright" },
}

--- Get (creating if needed) the state table for a logical button.
local function ensureButton(name)
    local b = Joystick.buttons[name]
    if (not b) then
        b = { pressed = false, pressaux = false, state = 0 }
        Joystick.buttons[name] = b
    end
    return b
end

--- Set the raw "is down" flag of a logical button.
local function setButton(name, down)
    ensureButton(name).pressed = not not down
end

--- Finalize a button's state from pressed/pressaux (edge detection).
local function finalizeButtonState(b)
    if (b.pressed and b.pressed == b.pressaux) then
        b.state = 2
    elseif (not b.pressed and b.pressed == b.pressaux) then
        b.state = 0
    else
        if (b.pressed and not b.pressaux) then
            b.state = 1
        else
            b.state = -1
        end
        b.pressaux = b.pressed
    end
end

--- Refresh the list of connected joysticks from the engine.
---@return table
function Joystick.Refresh()
    local list = {}
    if (SE.joystick and SE.joystick.getJoysticks) then
        list = SE.joystick.getJoysticks()
    end
    Joystick.joysticks = {}
    for _, joy in ipairs(list) do
        if (joy and joy.isConnected and joy:isConnected()) then
            table.insert(Joystick.joysticks, joy)
        end
    end
    return Joystick.joysticks
end

--- Add a joystick (call from love.joystickadded / love.gamepadadded).
---@param joy any
---@return boolean
function Joystick.Connect(joy)
    if (not joy) then return false end
    for _, j in ipairs(Joystick.joysticks) do
        if (j == joy) then return true end
    end
    table.insert(Joystick.joysticks, joy)
    return true
end

--- Remove a joystick (call from love.joystickremoved / love.gamepadremoved).
---@param joy any
---@return boolean
function Joystick.Disconnect(joy)
    if (not joy) then return false end
    for i = #Joystick.joysticks, 1, -1 do
        if (Joystick.joysticks[i] == joy) then
            table.remove(Joystick.joysticks, i)
        end
    end
    return true
end

--- Return the array of connected joystick objects.
---@return table
function Joystick.GetJoysticks()
    return Joystick.joysticks
end

--- Return the number of connected gamepads (accounts for simulated connection).
---@return integer
function Joystick.GetCount()
    if (Joystick.simulatedConnection and #Joystick.joysticks == 0) then
        return 1
    end
    return #Joystick.joysticks
end

--- Return true if at least one gamepad is connected (or a simulated one).
---@return boolean
function Joystick.IsConnected()
    return #Joystick.joysticks > 0 or Joystick.simulatedConnection
end

--- Set the analog dead-zone (default 0.15).
---@param v number
function Joystick.SetDeadzone(v)
    Joystick.deadzone = v or Joystick.deadzone
end

--- Set the threshold used to turn triggers/sticks into button presses (default 0.5).
---@param v number
function Joystick.SetAxisThreshold(v)
    Joystick.axisThreshold = v or Joystick.axisThreshold
end

--- Bind a name to a set of gamepad buttons / virtual buttons / binds.
---Allows checking a whole group with a single name (same as Keyboard.Bind).
---@param name string
---@param ... string
function Joystick.Bind(name, ...)
    Joystick.binds[name] = { keys = {...} }
end

-- Default binds (Undertale-style, matching the Keyboard binds)
Joystick.Bind("confirm", "a")
Joystick.Bind("cancel", "b")
Joystick.Bind("menu", "start", "y", "back")
Joystick.Bind("shift", "leftshoulder", "rightshoulder")
Joystick.Bind("arrows",
    "dpup", "dpdown", "dpleft", "dpright",
    "leftstickup", "leftstickdown", "leftstickleft", "leftstickright")
Joystick.Bind("up", "dpup", "leftstickup")
Joystick.Bind("down", "dpdown", "leftstickdown")
Joystick.Bind("left", "dpleft", "leftstickleft")
Joystick.Bind("right", "dpright", "leftstickright")

--- Poll a single joystick object (wrapped in pcall for safety).
local function pollJoystick(joy)
    if (not joy) then return end
    local ok = pcall(function()
        if (joy.isConnected and not joy:isConnected()) then
            Joystick.Disconnect(joy)
            return
        end

        local isGamepad = joy.isGamepad and joy:isGamepad()

        if (isGamepad) then
            for _, btn in ipairs(gamepadButtons) do
                setButton(btn, joy:isGamepadDown(btn))
            end
            for _, ax in ipairs(gamepadAxisNames) do
                local v = joy:getGamepadAxis(ax)
                Joystick.axes[ax] = v or 0
            end
        else
            -- Fallback: expose raw buttons/axes with numbered names (btn1, axis1, ...)
            local btnCount = joy:getButtonCount()
            for i = 1, btnCount do
                setButton("btn" .. i, joy:isDown(i - 1))
            end
            local axCount = joy:getAxisCount()
            for i = 1, axCount do
                Joystick.axes["axis" .. i] = joy:getAxis(i - 1) or 0
            end
        end
    end)
    if (not ok) then
        -- joystick probably disconnected mid-poll; drop it cleanly
        Joystick.Disconnect(joy)
    end
end

--- Derive virtual button states from the analog axes.
local function updateAxesAsButtons()
    for _, map in ipairs(axisButtonMaps) do
        local v = Joystick.axes[map.axis] or 0
        if (map.trigger) then
            setButton(map.trigger, v >= Joystick.axisThreshold)
        else
            setButton(map.negative, v <= -Joystick.deadzone)
            setButton(map.positive, v >= Joystick.deadzone)
        end
    end
end

--- Call this every frame (main.lua -> love.update).
function Joystick.Update()
    -- Sync the connected list each frame (cheap), so we pick up hot-plugged pads
    -- even if love.joystickadded wasn't wired up.
    if (SE.joystick and SE.joystick.getJoysticks) then
        local list = SE.joystick.getJoysticks()
        local present = {}
        for _, joy in ipairs(list) do
            present[joy] = true
            Joystick.Connect(joy)
        end
        for i = #Joystick.joysticks, 1, -1 do
            if (not present[Joystick.joysticks[i]]) then
                table.remove(Joystick.joysticks, i)
            end
        end
    end

    -- Reset raw button states each frame; polling below re-marks what is down.
    -- Anything not re-polled (e.g. a pad was unplugged) releases cleanly.
    for name, b in pairs(Joystick.buttons) do
        b.pressed = false
    end

    -- Reset axis values each frame so unplugged pads don't leave virtual
    -- stick/trigger buttons stuck held.
    for name in pairs(Joystick.axes) do
        Joystick.axes[name] = 0
    end

    for _, joy in ipairs(Joystick.joysticks) do
        pollJoystick(joy)
    end

    -- Simulated axes override the real ones BEFORE we derive virtual buttons,
    -- so SimulateAxis() also drives the virtual stick/trigger buttons.
    for name, v in pairs(Joystick.simulatedAxes) do
        Joystick.axes[name] = v
    end

    updateAxesAsButtons()

    -- Simulated buttons override the real ones
    for name, sim in pairs(Joystick.simulatedButtons) do
        setButton(name, sim.pressed)
    end

    -- Finalize the edge states for every known button
    for name, b in pairs(Joystick.buttons) do
        finalizeButtonState(b)
    end
end

--- Return the state of a gamepad button / virtual button / bind.
---Same convention as Keyboard.GetState: 0 = released, 1 = just pressed,
---2 = held, -1 = just released.
---@param name string
---@return integer
function Joystick.GetState(name)
    if (not Joystick.enabled) then return 0 end

    local b = Joystick.buttons[name]
    if (b) then return b.state end

    local bind = Joystick.binds[name]
    if (bind) then
        local anyPressed = false
        local allReleased = true
        local anyJustPressed = false
        local anyJustReleased = false
        for _, bindName in ipairs(bind.keys) do
            local state = Joystick.GetState(bindName)
            if (state == 1) then
                anyJustPressed = true
            elseif (state == 2) then
                anyPressed = true
            elseif (state == -1) then
                anyJustReleased = true
            end
            if (state ~= -1) then
                allReleased = false
            end
        end
        if (anyJustPressed) then
            return 1
        elseif (anyPressed) then
            return 2
        elseif (anyJustReleased) then
            return -1
        end
        return 0
    end

    return 0
end

--- Return true if a gamepad button / bind is currently held.
---@param name string
---@return boolean
function Joystick.IsDown(name)
    return Joystick.GetState(name) >= 1
end

--- Return the analog value of an axis (-1..1). Works for sticks & triggers.
---@param name string
---@return number
function Joystick.GetAxis(name)
    if (Joystick.simulatedAxes[name] ~= nil) then
        return Joystick.simulatedAxes[name]
    end
    return Joystick.axes[name] or 0
end

--- Enable / disable all joystick input.
---@param bool boolean
function Joystick.AllowPlayerInput(bool)
    Joystick.enabled = not not bool
end

--- Simulate a button press (takes effect on the next Joystick.Update()).
---@param name string
function Joystick.SimulatePress(name)
    local sim = Joystick.simulatedButtons[name]
    if (not sim) then
        sim = { pressed = false, pressaux = false, state = 0 }
        Joystick.simulatedButtons[name] = sim
    end
    sim.pressed = true
end

--- Simulate a button release (returns -1 for one frame, then 0).
---@param name string
function Joystick.SimulateRelease(name)
    local sim = Joystick.simulatedButtons[name]
    if (not sim) then
        sim = { pressed = false, pressaux = false, state = 0 }
        Joystick.simulatedButtons[name] = sim
    end
    sim.pressed = false
end

--- Simulate a quick tap of a button.
---@param name string
function Joystick.SimulateTap(name)
    Joystick.SimulatePress(name)
end

--- Simulate an axis value (e.g. to test analog movement without a pad).
---@param name string
---@param value number
function Joystick.SimulateAxis(name, value)
    Joystick.simulatedAxes[name] = value
end

--- Fake an active gamepad connection (so IsConnected()/GetCount() report one).
---@param bool boolean
function Joystick.SimulateConnection(bool)
    Joystick.simulatedConnection = not not bool
end

--- Return the name of the first connected gamepad (or nil).
---@return string?
function Joystick.GetGamepadName()
    if (#Joystick.joysticks == 0) then return nil end
    local joy = Joystick.joysticks[1]
    if (joy.getName) then return joy:getName() end
    return nil
end

return Joystick
