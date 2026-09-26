--  PLAYER SOUL — TEMPLATE AND CONTRACT
--  ============================================================================
--  A soul is a plain module table whose `Update(dt)` decides how the player
--  moves. It is loaded Game-first: `Game/Souls/<id>.lua`, and the engine copy
--  in `Scripts/Libraries/Battle/Player/Souls/<id>.lua` is only the fallback.
--
--  HOW TO USE THIS FILE
--    1. Copy it to `Game/Souls/<your_soul>.lua` (the local name `action` is
--       only a convention — keep it, it is what every engine soul uses).
--    2. Replace the "-- TODO" parts.
--    3. Switch to it from a wave: `Player.SetSoul("your_soul")`.
--
--  THE CALLBACKS
--    * Init(sprite, can_move, args) → called by `Player.SetSoul` /
--      `Player.NewSoul` right after this file is (re)loaded, once per switch.
--      THIS IS WHERE A SOUL SETS ITSELF UP: bind the sprite, choose its own
--      tint, reset its own state, read `args`. The engine binds nothing by
--      itself, so whatever a run needs at the start belongs here.
--    * Update(dt) → called by Battle every frame while this soul is the active
--      one and `Player.canMove` is true.
--
--  THE FIELDS
--    * action.sprite   the player sprite this soul drives.
--    * action.can_move mirrors Player.canMove; false = do not move.
--    * action.is_moving yours, for "am I walking" checks.
--
--  IMPORTANT
--    * `Player.action` IS this module table — the engine never copies it. The
--      file is re-executed on every switch, so nothing leaks between souls, but
--      module-level values do live for as long as the battle does: reset them in
--      `Init` instead of assuming a fresh process.
--    * Read input through `Controller.GetState("left")` and friends, never
--      `Keyboard` — that is what keeps gamepads working.
--    * `args` is whatever the wave passed as `Player.SetSoul(id, args)`.
-- ============================================================================

local action = {
    sprite = nil,
    can_move = true,
    is_moving = false
}

-- Default vars.
local speed = 2

---Called once per soul switch: bind the sprite and start from a clean state.
---@param sprite table|nil The player sprite this soul drives.
---@param can_move boolean|nil Mirrors Player.canMove; nil keeps the current value.
---@param args table|nil Extra arguments from Player.SetSoul / Player.NewSoul.
---@return table self This soul module.
function action.Init(sprite, can_move, args)
    action.sprite = sprite
    if (can_move ~= nil) then
        action.can_move = (can_move ~= false)
    end

    if (sprite) then
        -- TODO: this soul's tint, or drop the line to keep the sprite's colour.
        sprite.color = {1, 0, 0}
    end

    -- TODO: reset your own counters / flags here (speed = 2, my_timer = 0, ...).
    speed = 2

    return action
end

---Controls the player's movement and behaviour.
---@param dt number|nil
function action.Update(dt)
    if (not action.sprite) then return end

    local can_move = action.can_move
    local sprite = action.sprite
    local up, down, left, right = Controller.GetState("up"), Controller.GetState("down"), Controller.GetState("left"), Controller.GetState("right")
    local cancel = Controller.GetState("cancel")

    if (cancel > 0) then
        speed = 1
    else
        speed = 2
    end

    if (not can_move) then return end
    if (sprite) then
        if (Global.GetVariable("UseRealTime(dt)")) then
            -- Put your dt logic here.
        else
            -- Put your frames logic here.
        end
    end
end

return action