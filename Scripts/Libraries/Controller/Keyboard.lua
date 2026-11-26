local Keyboard = {
    keys = {},
    binds = {},
    progresses = {},
    simulatedKeys = {},
    allowInput = true,

    touches = {},
    touchToMouse = false,
}

for i = 97, 122, 1
do
    table.insert(Keyboard.keys, {id = string.char(i), state = 0, pressed = false, pressaux = false})
end
for i = 48, 57, 1
do
    table.insert(Keyboard.keys, {id = string.char(i), state = 0, pressed = false, pressaux = false})
end
for i = 1, 12
do
    table.insert(Keyboard.keys, {id = "f" .. i, state = 0, pressed = false, pressaux = false})
end
for i = 0, 9, 1
do
    table.insert(Keyboard.keys, {id = tostring(i), state = 0, pressed = false, pressaux = false})
    table.insert(Keyboard.keys, {id = "kp" .. tostring(i), state = 0, pressed = false, pressaux = false})
end

table.insert(Keyboard.keys, {id = "space", state = 0, pressed = false, pressaux = false})
table.insert(Keyboard.keys, {id = "return", state = 0, pressed = false, pressaux = false})
table.insert(Keyboard.keys, {id = "escape", state = 0, pressed = false, pressaux = false})
table.insert(Keyboard.keys, {id = "backspace", state = 0, pressed = false, pressaux = false})
table.insert(Keyboard.keys, {id = "tab", state = 0, pressed = false, pressaux = false})
table.insert(Keyboard.keys, {id = "lshift", state = 0, pressed = false, pressaux = false})
table.insert(Keyboard.keys, {id = "rshift", state = 0, pressed = false, pressaux = false})
table.insert(Keyboard.keys, {id = "lctrl", state = 0, pressed = false, pressaux = false})
table.insert(Keyboard.keys, {id = "rctrl", state = 0, pressed = false, pressaux = false})
table.insert(Keyboard.keys, {id = "lalt", state = 0, pressed = false, pressaux = false})
table.insert(Keyboard.keys, {id = "ralt", state = 0, pressed = false, pressaux = false})
table.insert(Keyboard.keys, {id = "capslock", state = 0, pressed = false, pressaux = false})
table.insert(Keyboard.keys, {id = "numlock", state = 0, pressed = false, pressaux = false})
table.insert(Keyboard.keys, {id = "scrolllock", state = 0, pressed = false, pressaux = false})
table.insert(Keyboard.keys, {id = "printscreen", state = 0, pressed = false, pressaux = false})
table.insert(Keyboard.keys, {id = "pause", state = 0, pressed = false, pressaux = false})
table.insert(Keyboard.keys, {id = "insert", state = 0, pressed = false, pressaux = false})
table.insert(Keyboard.keys, {id = "delete", state = 0, pressed = false, pressaux = false})
table.insert(Keyboard.keys, {id = "home", state = 0, pressed = false, pressaux = false})
table.insert(Keyboard.keys, {id = "end", state = 0, pressed = false, pressaux = false})
table.insert(Keyboard.keys, {id = "pageup", state = 0, pressed = false, pressaux = false})
table.insert(Keyboard.keys, {id = "pagedown", state = 0, pressed = false, pressaux = false})

table.insert(Keyboard.keys, {id = "[", state = 0, pressed = false, pressaux = false})
table.insert(Keyboard.keys, {id = "]", state = 0, pressed = false, pressaux = false})
table.insert(Keyboard.keys, {id = "\\", state = 0, pressed = false, pressaux = false})
table.insert(Keyboard.keys, {id = ";", state = 0, pressed = false, pressaux = false})
table.insert(Keyboard.keys, {id = "'", state = 0, pressed = false, pressaux = false})
table.insert(Keyboard.keys, {id = ",", state = 0, pressed = false, pressaux = false})
table.insert(Keyboard.keys, {id = ".", state = 0, pressed = false, pressaux = false})
table.insert(Keyboard.keys, {id = "/", state = 0, pressed = false, pressaux = false})
table.insert(Keyboard.keys, {id = "`", state = 0, pressed = false, pressaux = false})
table.insert(Keyboard.keys, {id = "-", state = 0, pressed = false, pressaux = false})
table.insert(Keyboard.keys, {id = "=", state = 0, pressed = false, pressaux = false})

table.insert(Keyboard.keys, {id = "up", state = 0, pressed = false, pressaux = false})
table.insert(Keyboard.keys, {id = "down", state = 0, pressed = false, pressaux = false})
table.insert(Keyboard.keys, {id = "left", state = 0, pressed = false, pressaux = false})
table.insert(Keyboard.keys, {id = "right", state = 0, pressed = false, pressaux = false})

table.insert(Keyboard.keys, {id = "mouse1", state = 0, pressed = false, pressaux = false})
table.insert(Keyboard.keys, {id = "mouse2", state = 0, pressed = false, pressaux = false})
table.insert(Keyboard.keys, {id = "mouse3", state = 0, pressed = false, pressaux = false})
table.insert(Keyboard.keys, {id = "mouse4", state = 0, pressed = false, pressaux = false})
table.insert(Keyboard.keys, {id = "mouse5", state = 0, pressed = false, pressaux = false})

table.insert(Keyboard.keys, {id = "kp/", state = 0, pressed = false, pressaux = false})
table.insert(Keyboard.keys, {id = "kp*", state = 0, pressed = false, pressaux = false})
table.insert(Keyboard.keys, {id = "kp-", state = 0, pressed = false, pressaux = false})
table.insert(Keyboard.keys, {id = "kp+", state = 0, pressed = false, pressaux = false})
table.insert(Keyboard.keys, {id = "kp.", state = 0, pressed = false, pressaux = false})
table.insert(Keyboard.keys, {id = "kp=", state = 0, pressed = false, pressaux = false})

--- Bind a name to a set of keys, so one name covers the whole group.
---@param name string
---@param ... string
function Keyboard.Bind(name, ...)
    local keys = {...}
    Keyboard.binds[name] = {}

    local tab = Keyboard.binds[name]
    tab.keys = keys
    tab.state = 0
    tab.pressed = false
    tab.pressaux = false
end

Keyboard.Bind("shift", "lshift", "rshift")
Keyboard.Bind("ctrl", "lctrl", "rctrl")
Keyboard.Bind("alt", "lalt", "ralt")
Keyboard.Bind("confirm", "return", "z")
Keyboard.Bind("cancel", "x", "shift")
Keyboard.Bind("menu", "c", "ctrl")
Keyboard.Bind("arrows", "up", "down", "left", "right")

Keyboard.Bind("letter", "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z")
Keyboard.Bind("number", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9")

--- Convert screen coordinates to game world coordinates
---@param sx number screen x (pixels)
---@param sy number screen y (pixels)
---@return number, number world x,y
function Keyboard.ScreenToWorld(sx, sy)
    local s = ScreenScale
    local x = sx - (DrawX or 0)
    local y = sy - (DrawY or 0)
    x = x / s + (Camera and Camera.x or 0)
    y = y / s + (Camera and Camera.y or 0)
    return x, y
end

--- Enable / disable mapping the first touch to mouse1 (default false)
---@param bool boolean
function Keyboard.EnableTouchToMouse(bool)
    Keyboard.touchToMouse = not not bool
end

--- When a touch starts (call this in SE.touchpressed)
---@param id any
---@param sx number screen x
---@param sy number screen y
function Keyboard.TouchPressed(id, sx, sy)
    local t = Keyboard.touches[id] or { id = id, pressed = false, pressaux = false, state = 0, screenX = sx, screenY = sy }
    t.screenX = sx
    t.screenY = sy
    t.x, t.y = Keyboard.ScreenToWorld(sx, sy)
    t.pressed = true
    Keyboard.touches[id] = t

    if Keyboard.touchToMouse then
        if not Keyboard.simulatedKeys["__touch_mouse1"] or not Keyboard.simulatedKeys["__touch_mouse1"].pressed then
            Keyboard.simulatedKeys["mouse1"] = { pressed = true, pressaux = false, state = 1 }
            Keyboard.simulatedKeys["__touch_mouse1"] = { pressed = true, pressaux = false, state = 1 }
        end
    end
end

--- When a touch moves (call this in SE.touchmoved)
---@param id any
---@param sx number
---@param sy number
function Keyboard.TouchMoved(id, sx, sy)
    local t = Keyboard.touches[id]
    if not t then
        t = { id = id, pressed = true, pressaux = false, state = 1 }
        Keyboard.touches[id] = t
    end
    t.screenX = sx
    t.screenY = sy
    t.x, t.y = Keyboard.ScreenToWorld(sx, sy)
end

--- When a touch ends (call this in SE.touchreleased)
---@param id any
---@param sx number
---@param sy number
function Keyboard.TouchReleased(id, sx, sy)
    local t = Keyboard.touches[id]
    if not t then
        t = { id = id, screenX = sx, screenY = sy, x = sx, y = sy, pressed = false, pressaux = false, state = 0 }
        Keyboard.touches[id] = t
    end
    t.screenX = sx
    t.screenY = sy
    t.x, t.y = Keyboard.ScreenToWorld(sx, sy)
    t.pressed = false

    if Keyboard.touchToMouse then
        if Keyboard.simulatedKeys["__touch_mouse1"] and Keyboard.simulatedKeys["__touch_mouse1"].pressed then
            Keyboard.simulatedKeys["mouse1"] = { pressed = false, pressaux = true, state = -1 }
            Keyboard.simulatedKeys["__touch_mouse1"].pressed = false
        end
    end
end

--- Return the world coordinates and state of a given touch
---@param id any
function Keyboard.GetTouch(id)
    local t = Keyboard.touches[id]
    if not t then return nil end
    return t.x, t.y, t.state, t
end

--- Return a shallow copy of all current touches (for easy iteration)
---@return table
function Keyboard.GetTouches()
    local out = {}
    for k,v in pairs(Keyboard.touches) do
        table.insert(out, v)
    end
    return out
end

--- Shrink the touch map so it cannot grow without bound: a released touch is
--- dropped once it has been through state 0 for a frame.
local function updateTouchStates()
    for id, t in pairs(Keyboard.touches) do
        if t.pressed and t.pressed == t.pressaux then
            t.state = 2
        elseif (not t.pressed) and t.pressed == t.pressaux then
            t.state = 0
        elseif t.pressed ~= t.pressaux then
            if t.pressed and not t.pressaux then
                t.state = 1
            else
                t.state = -1
            end
            t.pressaux = t.pressed
        end

        if t.state == 0 and not t.pressed and (not t.keep) then
            Keyboard.touches[id] = nil
        end
    end
end

--- Simulate a key press: 1 next frame, then 2 while held.
---@param key string
function Keyboard.SimulatePress(key)
    local simKey = Keyboard.simulatedKeys[key]
    if (not simKey) then
        simKey = { pressed = false, pressaux = false, state = 0 }
        Keyboard.simulatedKeys[key] = simKey
    end
    simKey.pressed = true
end

--- Simulate a key being released (returns -1 for one frame, then 0).
---@param key string
function Keyboard.SimulateRelease(key)
    local simKey = Keyboard.simulatedKeys[key]
    if (not simKey) then
        simKey = { pressed = false, pressaux = false, state = 0 }
        Keyboard.simulatedKeys[key] = simKey
    end
    simKey.pressed = false
end

function Keyboard.SimulateTap(key)
    Keyboard.SimulatePress(key)
end

function Keyboard.AllowPlayerInput(bool)
    Keyboard.allowInput = bool
end

---Use this function to get the state of a key, or a keys binding.
---@param key string
---@return integer
function Keyboard.GetState(key)
    if (Keyboard.simulatedKeys[key]) then
        return Keyboard.simulatedKeys[key].state or 0
    end

    if (Keyboard.allowInput) then
        for _, v in pairs(Keyboard.keys)
        do
            if (v.id == key:lower()) then
                return v.state
            end
        end
        if (Keyboard.binds[key]) then
            local anyPressed = false
            local allReleased = true
            local anyJustPressed = false
            local anyJustReleased = false
            for _, bindKey in pairs(Keyboard.binds[key].keys)
            do
                local state = Keyboard.GetState(bindKey)
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
            elseif (allReleased) then
                return 0
            else
                return 0
            end
        end
    end

    return 0
end

--- Mouse position in game world space, whatever the game scale is.
---@return number, number
function Keyboard.GetMousePosition()
    local ScreenScale = ScreenScale
    local x, y = SE.mouse.getPosition()
    x = x - DrawX

    x = x / ScreenScale + Camera.x - 320
    y = y / ScreenScale + Camera.y - 240
    return x, y
end

--- Letter currently pressed (shift applied), or "" when only function keys are.
---@return string
function Keyboard.ReturnLetter()
    local letter = ""
    local functionKeys = {
        "lshift", "rshift", "space", "lctrl", "rctrl", "lalt", "ralt",
        "tab", "capslock", "enter", "esc", "backspace", "delete",
        "insert", "home", "end", "pageup", "pagedown", "numlock",
        "scrolllock", "pause", "printscreen", "f1", "f2", "f3", "f4",
        "f5", "f6", "f7", "f8", "f9", "f10", "f11", "f12",
        "up", "down", "left", "right", "mouse1", "mouse2", "mouse3", "mouse4", "mouse5"
    }

    local isFunctionKey = {}
    for _, key in ipairs(functionKeys) do
        isFunctionKey[key] = true
    end

    local symbolMappings = {
        ["1"] = "!", ["2"] = "@", ["3"] = "#", ["4"] = "$", ["5"] = "%",
        ["6"] = "^", ["7"] = "&", ["8"] = "*", ["9"] = "(", ["0"] = ")",

        ["-"] = "_", ["="] = "+", ["["] = "{", ["]"] = "}", ["\\"] = "|",
        [";"] = ":", ["'"] = "\"", [","] = "<", ["."] = ">", ["/"] = "?",
        ["`"] = "~"
    }

    for _, v in pairs(Keyboard.keys) do
        if v.state == 1 and not isFunctionKey[v.id] then
            if string.match(v.id, "^[a-z]$") then
                letter = v.id
                if Keyboard.GetState("shift") >= 1 then
                    letter = string.upper(letter)
                end
                break
            elseif symbolMappings[v.id] then
                if Keyboard.GetState("shift") >= 1 then
                    letter = symbolMappings[v.id]
                else
                    letter = v.id
                end
                break
            end
        end
    end
    return letter
end

--- Simulate a key press for `duration` frames, then release it.
---@param key string
---@param duration number
---@return table
function Keyboard.AutoPress(key, duration)
    local progress = {}
    progress.duration = (duration or 1)
    progress.key = key
    progress.timer = 0

    if (type(key) ~= "string") then
        print("Keyboard.AutoPress: key must be a string")
    end

    table.insert(Keyboard.progresses, progress)
    return progress
end

function Keyboard.Update()
    for _, v in pairs(Keyboard.keys)
    do
        if (type(v.id) == "string") then
            if (not string.find(v.id, "mouse")) then
                if (SE.keyboard.isDown(v.id)) then
                    v.pressed = true
                else
                    v.pressed = false
                end
                if (v.pressed and v.pressed == v.pressaux) then
                    v.state = 2
                end
                if (not v.pressed and v.pressed == v.pressaux) then
                    v.state = 0
                end
                if (v.pressed ~= v.pressaux) then
                    if (v.pressed and not v.pressaux) then
                        v.state = 1
                    else
                        v.state = -1
                    end
                    v.pressaux = v.pressed
                end
            else
                if (SE.mouse.isDown(v.id:sub(-1))) then
                    v.pressed = true
                else
                    v.pressed = false
                end
                if (v.pressed and v.pressed == v.pressaux) then
                    v.state = 2
                end
                if (not v.pressed and v.pressed == v.pressaux) then
                    v.state = 0
                end
                if (v.pressed ~= v.pressaux) then
                    if (v.pressed and not v.pressaux) then
                        v.state = 1
                    else
                        v.state = -1
                    end
                    v.pressaux = v.pressed
                end
            end
        end
    end

    updateTouchStates()

    for i = #Keyboard.progresses, 1, -1
    do
        local progress = Keyboard.progresses[i]
        if (progress.timer <= progress.duration) then
            if (progress.timer == 1) then
                Keyboard.SimulatePress(progress.key)
            end
        else
            Keyboard.SimulateRelease(progress.key)
            table.remove(Keyboard.progresses, i)
        end
        progress.timer = progress.timer + 1
    end

    local staleKeys = {}
    for key, simKey in pairs(Keyboard.simulatedKeys) do
        if (simKey.pressed ~= nil) then
            if (simKey.pressed and simKey.pressed == simKey.pressaux) then
                simKey.state = 2
            elseif (not simKey.pressed and simKey.pressed == simKey.pressaux) then
                simKey.state = 0
            else
                if (simKey.pressed and not simKey.pressaux) then
                    simKey.state = 1
                else
                    simKey.state = -1
                end
                simKey.pressaux = simKey.pressed
            end

            if (not simKey.pressed and simKey.state == 0) then
                table.insert(staleKeys, key)
            end
        end
    end
    for _, key in ipairs(staleKeys) do
        Keyboard.simulatedKeys[key] = nil
    end
end

return Keyboard
