--- Player soul template and contract. A soul is a plain module table whose `Update(dt)` moves the player. Loaded Game-first from `Game/Souls/<id>.lua`; the engine copy is only the fallback.

local action = {
    sprite = nil,
    can_move = true,
    is_moving = false,
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
        sprite.color = {1, 0, 0}
    end

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
        else
        end
    end
end

return action
