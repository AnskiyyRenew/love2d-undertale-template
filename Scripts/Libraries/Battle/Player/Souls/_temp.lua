--  PLAYER SOUL — TEMPLATE AND CONTRACT
--
--  A soul is a plain module table whose `Update(dt)` moves the player. Copy this
--  file to `Game/Souls/<name>.lua` (keep the local name `action`) and switch to
--  it with `Player.SetSoul("<name>")`. Lookup is Game-first; the engine copy in
--  `Scripts/Libraries/Battle/Player/Souls/<id>.lua` is the fallback.
--
--  Callbacks:
--    Init(sprite, can_move, args)  Once per switch: bind the sprite, pick the
--                                  tint, reset state, read `args`.
--    Update(dt)                    Every frame while this soul is active and
--                                  `Player.canMove` is true.
--
--  Fields: `sprite` (the driven sprite), `can_move` (mirrors Player.canMove),
--  `is_moving` (yours), `use_platforms` (optional: true = caught by
--  Player.BluePlatform surfaces, absent = passes through).
--
--  `Player.action` IS this module table and the file is re-executed on every
--  switch, so reset module-level values in Init. Read input through
--  `Controller.GetState("left")` and friends, never `Keyboard`.

local action = {
    sprite = nil,
    can_move = true,
    is_moving = false,
    -- use_platforms = true,   -- uncomment to stand on Player.BluePlatform surfaces
}

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

    -- TODO: reset your own counters / flags here (my_timer = 0, ...).
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