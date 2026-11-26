--- GUI Input - mouse input helper (screen -> canvas space, edge-detected)

local Input = {}

--- Convert window screen coords -> canvas coords (640x480 space).
--- DrawX / DrawY / ScreenScale are globals set by main.lua's updateScreenScale().
---@param sx number
---@param sy number
function Input.ScreenToCanvas(sx, sy)
    local scale = ScreenScale or 1
    if (not scale or scale <= 0) then scale = 1 end
    local dx = DrawX or 0
    local dy = DrawY or 0
    return (sx - dx) / scale, (sy - dy) / scale
end

local state = {
    held     = {},
    pressed  = {},
    released = {},
    wheel    = 0,
    pos      = { x = 0, y = 0 },
}

local pending = {
    pressed  = {},
    released = {},
    wheel    = 0,
}

--- love.mousepressed handler. Call from scene.mousepressed.
function Input.OnPressed(sx, sy, button)
    local cx, cy = Input.ScreenToCanvas(sx, sy)
    state.held[button] = true
    pending.pressed[button] = true
    state.pos.x = cx
    state.pos.y = cy
end

--- love.mousereleased handler. Call from scene.mousereleased.
function Input.OnReleased(sx, sy, button)
    local cx, cy = Input.ScreenToCanvas(sx, sy)
    state.held[button] = false
    pending.released[button] = true
    state.pos.x = cx
    state.pos.y = cy
end

--- love.mousemoved handler. Keeps cursor position fresh for hover detection
--- even when no button is held. Call from scene.mousemoved.
function Input.OnMoved(sx, sy)
    local cx, cy = Input.ScreenToCanvas(sx, sy)
    state.pos.x = cx
    state.pos.y = cy
end

--- love.wheelmoved handler. Call from scene.wheelmoved.
---@param x number
---@param y number
function Input.OnWheel(x, y)
    local d = (y > 0 and 1) or (y < 0 and -1) or 0
    pending.wheel = pending.wheel + d
end

--- Freeze pending events into `state` for the scene to read this frame, and
--- read a fresh cursor position (mousemoved may not have fired this frame).
--- MUST be called at the TOP of scene.update, before any input reads.
function Input.Update()
    state.pressed  = pending.pressed
    state.released = pending.released
    state.wheel    = pending.wheel
    local sx, sy = SE.mouse.getPosition()
    state.pos.x, state.pos.y = Input.ScreenToCanvas(sx, sy)
    pending.pressed  = {}
    pending.released = {}
    pending.wheel    = 0
end

--- Current cursor position in canvas space.
function Input.GetCanvasMouse()
    return state.pos.x, state.pos.y
end

--- Whether the button is currently held (real-time).
---@return boolean
function Input.IsDown(button)
    return state.held[button] == true
end

--- Whether the button had a down-edge this frame.
---@return boolean
function Input.IsPressed(button)
    return state.pressed[button] == true
end

--- Whether the button had an up-edge this frame.
---@return boolean
function Input.IsReleased(button)
    return state.released[button] == true
end

--- Wheel delta for this frame (+1 / -1 / 0).
---@return number
function Input.GetWheel()
    return state.wheel or 0
end

--- Reset all state (held / pressed / released / wheel / pos). Call on scene
--- clear so a mouse button held across a scene switch doesn't leave IsDown
--- stuck true (love may not deliver mousereleased to the new scene).
function Input.Reset()
    state.held = {}
    state.pressed = {}
    state.released = {}
    state.wheel = 0
    state.pos = { x = 0, y = 0 }
    pending.pressed = {}
    pending.released = {}
    pending.wheel = 0
end

return Input
