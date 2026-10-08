--[[
    GUI Input - mouse input helper (screen -> canvas space, edge-detected)

    The engine renders everything onto a 640x480 canvas, then scales it to the
    window (see main.lua: DrawX / DrawY / ScreenScale). Raw mouse coordinates
    from love.mouse* arrive in WINDOW space; GUI components live in CANVAS
    space. This helper does the screen->canvas conversion and edge-detects
    button state so a scene can poll IsPressed / IsReleased / IsDown once per
    frame, mirroring the manual `prev` table pattern the keyboard code already
    uses.

    Lifecycle (the scene wires these four love callbacks):
      scene.mousepressed(x,y,btn,...)   -> GUI.Input.OnPressed(x,y,btn)
      scene.mousereleased(x,y,btn,...)  -> GUI.Input.OnReleased(x,y,btn)
      scene.mousemoved(x,y,...)         -> GUI.Input.OnMoved(x,y)
      scene.wheelmoved(x,y)             -> GUI.Input.OnWheel(x,y)
      scene.update(dt)                  -> GUI.Input.Update()   -- at the TOP
    Then read:
      GUI.Input.GetCanvasMouse()   -> cx, cy   (current cursor in canvas space)
      GUI.Input.IsDown(1)          -> bool      (held right now)
      GUI.Input.IsPressed(1)       -> bool      (down-edge this frame)
      GUI.Input.IsReleased(1)      -> bool      (up-edge this frame)
      GUI.Input.GetWheel()         -> int        (+1 up / -1 down / 0)
    Left mouse button = 1.

    State model: `held` is real-time (mutated directly by OnPressed/OnReleased,
    so IsDown reflects the live state even mid-frame); `pressed` / `released`
    / `wheel` are frozen per-frame at the start of Update(), so IsPressed /
    IsReleased stay true for exactly the frame that follows the event. Events
    that arrive async between frames accumulate in `pending` and are swapped in
    on the next Update().
]]

local Input = {}

--- Convert window screen coords -> canvas coords (640x480 space).
--- DrawX / DrawY / ScreenScale are globals set by main.lua's updateScreenScale().
function Input.ScreenToCanvas(sx, sy)
    local scale = ScreenScale or 1
    if (not scale or scale <= 0) then scale = 1 end
    local dx = DrawX or 0
    local dy = DrawY or 0
    return (sx - dx) / scale, (sy - dy) / scale
end

-- Real-time state (held is mutated directly; pressed/released/wheel/pos are
-- frozen per-frame by Update).
local state = {
    held     = {},       -- button -> bool, real-time
    pressed  = {},       -- button -> bool, frozen for this frame
    released = {},       -- button -> bool, frozen for this frame
    wheel    = 0,        -- int, frozen for this frame
    pos      = { x = 0, y = 0 },  -- canvas-space cursor
}

-- Pending events accumulate async between frames; swapped into `state` by Update.
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
function Input.OnWheel(x, y)
    -- Collapse to +1 / -1 / 0 per event; accumulate (rare double-notches).
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
    -- reset per-frame buffers for the next frame's async events
    pending.pressed  = {}
    pending.released = {}
    pending.wheel    = 0
end

--- Current cursor position in canvas space.
function Input.GetCanvasMouse()
    return state.pos.x, state.pos.y
end

--- Whether the button is currently held (real-time).
function Input.IsDown(button)
    return state.held[button] == true
end

--- Whether the button had a down-edge this frame.
function Input.IsPressed(button)
    return state.pressed[button] == true
end

--- Whether the button had an up-edge this frame.
function Input.IsReleased(button)
    return state.released[button] == true
end

--- Wheel delta for this frame (+1 / -1 / 0).
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
