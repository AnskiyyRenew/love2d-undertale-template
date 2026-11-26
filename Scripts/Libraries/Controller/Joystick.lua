--- Joystick.lua - gamepad controller (auto-detect, gamepad mapping with raw fallback, analog sticks/triggers, binds, simulation).

local Joystick = {
    joysticks = {},
    enabled = true,
    deadzone = 0.15,
    axisThreshold = 0.5,

    buttons = {},
    axes = {},

    binds = {},

    simulatedButtons = {},
    simulatedAxes = {},
    simulatedConnection = false,
}

local gamepadButtons = {
    "a", "b", "x", "y",
    "back", "guide", "start",
    "leftstick", "rightstick",
    "leftshoulder", "rightshoulder",
    "dpup", "dpdown", "dpleft", "dpright",
}

local gamepadAxisNames = {
    "leftx", "lefty", "rightx", "righty", "triggerleft", "triggerright",
}

local axisButtonMaps = {
    { axis = "leftx",        negative = "leftstickleft",  positive = "leftstickright" },
    { axis = "lefty",        negative = "leftstickup",     positive = "leftstickdown" },
    { axis = "rightx",       negative = "rightstickleft", positive = "rightstickright" },
    { axis = "righty",       negative = "rightstickup",    positive = "rightstickdown" },
    { axis = "triggerleft",  trigger = "triggerleft" },
    { axis = "triggerright", trigger = "triggerright" },
}

--- Apply the dead-zone to a raw axis value and re-scale (deadzone..1) to 0..1,
--- so movement starts smoothly at 0. Returns 0 inside the dead-zone.
---@param v number
---@return number
local function applyDeadzone(v)
    local dz = Joystick.deadzone or 0
    if (dz <= 0) then return v end
    local abs = math.abs(v)
    if (abs <= dz) then return 0 end
    local scaled = (abs - dz) / (1 - dz)
    return v > 0 and scaled or -scaled
end

--- Get (creating if needed) the state table for a logical button.
---@param name string
local function ensureButton(name)
    local b = Joystick.buttons[name]
    if (not b) then
        b = { pressed = false, pressaux = false, state = 0 }
        Joystick.buttons[name] = b
    end
    return b
end

--- Set the raw "is down" flag of a logical button.
---@param name string
---@param down boolean
local function setButton(name, down)
    ensureButton(name).pressed = not not down
end

--- Finalize a button's state from pressed/pressaux (edge detection).
---@param b table
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

--- Set the analog dead-zone (0..1), clamped to [0, 0.95].
---@param v number
function Joystick.SetDeadzone(v)
    if (v == nil) then return end
    Joystick.deadzone = math.max(0, math.min(v, 0.95))
end

--- Set the threshold used to turn triggers/sticks into button presses (default 0.5).
---@param v number
function Joystick.SetAxisThreshold(v)
    Joystick.axisThreshold = v or Joystick.axisThreshold
end

--- Bind a name to a set of gamepad buttons / virtual buttons / binds.
---@param name string
---@param ... string
function Joystick.Bind(name, ...)
    Joystick.binds[name] = { keys = {...} }
end

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
---@param joy table
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

    for name, b in pairs(Joystick.buttons) do
        b.pressed = false
    end

    for name in pairs(Joystick.axes) do
        Joystick.axes[name] = 0
    end

    for _, joy in ipairs(Joystick.joysticks) do
        pollJoystick(joy)
    end

    for name, v in pairs(Joystick.simulatedAxes) do
        Joystick.axes[name] = v
    end

    updateAxesAsButtons()

    for name, sim in pairs(Joystick.simulatedButtons) do
        setButton(name, sim.pressed)
    end

    for name, b in pairs(Joystick.buttons) do
        finalizeButtonState(b)
    end
end

--- Return the state of a button / virtual button / bind (0/1/2/-1).
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

--- Analog axis value (-1..1) with the dead-zone applied and re-scaled. Works for
--- sticks & triggers; simulated axes go through the same filtering.
---@param name string
---@return number
function Joystick.GetAxis(name)
    local v
    if (Joystick.simulatedAxes[name] ~= nil) then
        v = Joystick.simulatedAxes[name]
    else
        v = Joystick.axes[name] or 0
    end
    return applyDeadzone(v)
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
