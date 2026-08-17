--[[
    VirtualKeyboard.lua - Touch-screen controller with an auto-created on-screen
    virtual keyboard.

    On mobile (Android / iOS) it enables itself automatically and shows a set of
    on-screen controls (default: Undertale-style d-pad + confirm / cancel / menu).
    On desktop you can force it on for testing via
    Global.GetVariable("ControllerSimulation").virtualKeyboard == true,
    then click the buttons with the mouse to "simulate" touch.

    Every press is routed through the SAME simulated-input system as Keyboard
    (or optionally Joystick), so game logic reading GetState() sees the exact
    same feedback: 1 = just pressed, 2 = held, -1 = just released, 0 = released.
--]]

local VirtualKeyboard = {
    enabled = false,         -- master on/off
    visible = true,          -- whether the overlay is drawn
    autoDetect = true,       -- enable automatically on touch devices
    target = "Keyboard",     -- "Keyboard" (simulates keys) or "Joystick" (simulates buttons)
    buttons = {},            -- array of on-screen button defs
    boundTouches = {},       -- touch id -> button id (which button each finger holds)
    alpha = 0.7,             -- overlay opacity
    round = 8,               -- rounded-corner radius
    lineWidth = 2,
    fontSize = 18,
}

local MOUSE_TOUCH_ID = "__vk_mouse"

-- Default Undertale-style mobile layout.
-- Coordinates are normalized: nx/ny = center on screen (0..1), fw/fh = size as a
-- fraction of the screen HEIGHT (keeps touch targets a consistent pixel size).
local defaultLayout = {
    { id = "up",       key = "up",       label = "▲", nx = 0.16, ny = 0.70, fw = 0.26, fh = 0.20, color = { 0.25, 0.25, 0.35 } },
    { id = "down",     key = "down",     label = "▼", nx = 0.16, ny = 0.92, fw = 0.26, fh = 0.20, color = { 0.25, 0.25, 0.35 } },
    { id = "left",     key = "left",     label = "◀", nx = 0.05, ny = 0.81, fw = 0.26, fh = 0.20, color = { 0.25, 0.25, 0.35 } },
    { id = "right",    key = "right",    label = "▶", nx = 0.27, ny = 0.81, fw = 0.26, fh = 0.20, color = { 0.25, 0.25, 0.35 } },
    { id = "menu",     key = "c",        label = "C", nx = 0.84, ny = 0.62, fw = 0.20, fh = 0.18, color = { 0.35, 0.25, 0.40 } },
    { id = "confirm",  key = "z",        label = "A", nx = 0.92, ny = 0.80, fw = 0.24, fh = 0.22, color = { 0.20, 0.40, 0.55 } },
    { id = "cancel",   key = "x",        label = "B", nx = 0.72, ny = 0.90, fw = 0.24, fh = 0.18, color = { 0.55, 0.25, 0.25 } },
}

--- Build the default button list from the layout table above.
local function buildDefaultButtons()
    VirtualKeyboard.buttons = {}
    for _, def in ipairs(defaultLayout) do
        local btn = {
            id = def.id,
            key = def.key,
            label = def.label,
            nx = def.nx,
            ny = def.ny,
            fw = def.fw,
            fh = def.fh,
            color = def.color,
            enabled = true,
            pressed = false,
            x = 0, y = 0, w = 0, h = 0,
        }
        table.insert(VirtualKeyboard.buttons, btn)
    end
end
buildDefaultButtons()

--- Return true if the current OS is a touch-first device.
---@return boolean
function VirtualKeyboard.IsTouchDevice()
    if (love and love.system and love.system.getOS) then
        local os = love.system.getOS()
        if (os == "Android" or os == "iOS" or os == "tvOS") then
            return true
        end
    end
    return false
end

--- Enable / disable the virtual keyboard manually.
---@param bool boolean
function VirtualKeyboard.SetEnabled(bool)
    VirtualKeyboard.enabled = not not bool
end

--- Show / hide the overlay (input is still routed if enabled).
---@param bool boolean
function VirtualKeyboard.SetVisible(bool)
    VirtualKeyboard.visible = not not bool
end

--- Toggle auto-detection on touch devices (default true).
---@param bool boolean
function VirtualKeyboard.SetAutoDetect(bool)
    VirtualKeyboard.autoDetect = not not bool
end

--- Route simulated presses to "Keyboard" (keys) or "Joystick" (gamepad buttons).
---@param target string
function VirtualKeyboard.SetTarget(target)
    VirtualKeyboard.target = target == "Joystick" and "Joystick" or "Keyboard"
end

--- Replace the whole layout with a custom one.
---Each def: { id, key, label, nx, ny, fw, fh, color }
---@param layout table
function VirtualKeyboard.SetLayout(layout)
    VirtualKeyboard.buttons = {}
    if (not layout) then layout = defaultLayout end
    for _, def in ipairs(layout) do
        local btn = {
            id = def.id,
            key = def.key,
            label = def.label,
            nx = def.nx,
            ny = def.ny,
            fw = def.fw,
            fh = def.fh,
            color = def.color,
            enabled = def.enabled ~= false,
            pressed = false,
            x = 0, y = 0, w = 0, h = 0,
        }
        table.insert(VirtualKeyboard.buttons, btn)
    end
    VirtualKeyboard.Layout()
end

--- Add a single button to the current layout.
---@param def table
function VirtualKeyboard.AddButton(def)
    local btn = {
        id = def.id,
        key = def.key,
        label = def.label,
        nx = def.nx,
        ny = def.ny,
        fw = def.fw,
        fh = def.fh,
        color = def.color,
        enabled = def.enabled ~= false,
        pressed = false,
        x = 0, y = 0, w = 0, h = 0,
    }
    table.insert(VirtualKeyboard.buttons, btn)
    return btn
end

--- Enable / disable a button by id (disabled buttons don't catch input or draw).
---@param id string
---@param bool boolean
function VirtualKeyboard.SetButtonEnabled(id, bool)
    for _, btn in ipairs(VirtualKeyboard.buttons) do
        if (btn.id == id) then
            btn.enabled = not not bool
        end
    end
end

--- Recompute pixel rectangles from the normalized layout (call on resize).
function VirtualKeyboard.Layout()
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    for _, btn in ipairs(VirtualKeyboard.buttons) do
        btn.w = btn.fw * h
        btn.h = btn.fh * h
        btn.x = btn.nx * w - btn.w * 0.5
        btn.y = btn.ny * h - btn.h * 0.5
    end
end

--- Call every frame (main.lua -> love.update).
function VirtualKeyboard.Update()
    if (VirtualKeyboard.autoDetect and not VirtualKeyboard.enabled and VirtualKeyboard.IsTouchDevice()) then
        VirtualKeyboard.enabled = true
    end
    VirtualKeyboard.Layout()
end

local function pointInRect(px, py, r)
    return px >= r.x and px <= r.x + r.w and py >= r.y and py <= r.y + r.h
end

--- Route a simulated press to the chosen input target.
local function pressButton(btn)
    if (VirtualKeyboard.target == "Joystick") then
        if (Joystick and Joystick.SimulatePress) then
            Joystick.SimulatePress(btn.key)
        end
    else
        if (Keyboard and Keyboard.SimulatePress) then
            Keyboard.SimulatePress(btn.key)
        end
    end
end

--- Route a simulated release to the chosen input target.
local function releaseButton(btn)
    if (VirtualKeyboard.target == "Joystick") then
        if (Joystick and Joystick.SimulateRelease) then
            Joystick.SimulateRelease(btn.key)
        end
    else
        if (Keyboard and Keyboard.SimulateRelease) then
            Keyboard.SimulateRelease(btn.key)
        end
    end
end

--- When a touch starts. Returns true if the touch was consumed by a button.
---@param id any
---@param sx number
---@param sy number
---@return boolean
function VirtualKeyboard.TouchPressed(id, sx, sy)
    if (not VirtualKeyboard.enabled or not VirtualKeyboard.visible) then return false end
    if (VirtualKeyboard.boundTouches[id]) then return true end

    for _, btn in ipairs(VirtualKeyboard.buttons) do
        if (btn.enabled and pointInRect(sx, sy, btn)) then
            VirtualKeyboard.boundTouches[id] = btn.id
            btn.pressed = true
            pressButton(btn)
            return true
        end
    end
    return false
end

--- When a touch moves. The held button stays held until the finger lifts.
---@param id any
---@param sx number
---@param sy number
function VirtualKeyboard.TouchMoved(id, sx, sy)
    -- intentionally kept simple: dragging does not cancel a held button
end

--- When a touch ends. Returns true if a held button was released.
---@param id any
---@param sx number
---@param sy number
---@return boolean
function VirtualKeyboard.TouchReleased(id, sx, sy)
    local btnId = VirtualKeyboard.boundTouches[id]
    if (not btnId) then return false end

    VirtualKeyboard.boundTouches[id] = nil
    for _, btn in ipairs(VirtualKeyboard.buttons) do
        if (btn.id == btnId) then
            btn.pressed = false
            releaseButton(btn)
            return true
        end
    end
    return false
end

--- Desktop helper: treat a left-click as a touch (for simulating on PC).
---@param sx number
---@param sy number
---@return boolean
function VirtualKeyboard.MousePressed(sx, sy)
    if (not VirtualKeyboard.enabled or not VirtualKeyboard.visible) then return false end
    return VirtualKeyboard.TouchPressed(MOUSE_TOUCH_ID, sx, sy)
end

--- Desktop helper: release the simulated mouse touch.
---@param sx number
---@param sy number
---@return boolean
function VirtualKeyboard.MouseReleased(sx, sy)
    return VirtualKeyboard.TouchReleased(MOUSE_TOUCH_ID, sx, sy)
end

--- Draw the virtual keyboard overlay (screen space). Call in love.draw.
function VirtualKeyboard.Draw()
    if (not VirtualKeyboard.enabled or not VirtualKeyboard.visible) then return end

    local font = SE.graphics.getFont()
    local oldLineWidth = SE.graphics.getLineWidth and SE.graphics.getLineWidth() or VirtualKeyboard.lineWidth

    for _, btn in ipairs(VirtualKeyboard.buttons) do
        if (btn.enabled) then
            local color = btn.color or { 0.15, 0.15, 0.2 }
            local r, g, b = color[1], color[2], color[3]

            -- body
            SE.graphics.setColor(r, g, b, btn.pressed and 1 or VirtualKeyboard.alpha)
            SE.graphics.rectangle("fill", btn.x, btn.y, btn.w, btn.h, VirtualKeyboard.round, VirtualKeyboard.round)

            -- border
            SE.graphics.setColor(1, 1, 1, 0.45)
            SE.graphics.setLineWidth(VirtualKeyboard.lineWidth)
            SE.graphics.rectangle("line", btn.x, btn.y, btn.w, btn.h, VirtualKeyboard.round, VirtualKeyboard.round)

            -- label
            SE.graphics.setColor(1, 1, 1, 0.95)
            local tw = font:getWidth(btn.label)
            local th = font:getHeight()
            SE.graphics.print(btn.label, btn.x + (btn.w - tw) * 0.5, btn.y + (btn.h - th) * 0.5)
        end
    end

    SE.graphics.setLineWidth(oldLineWidth)
end

return VirtualKeyboard
