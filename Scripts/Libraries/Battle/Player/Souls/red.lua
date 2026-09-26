local action = {
    sprite = nil,
    can_move = true,
    is_moving = false
}

local speed = 2

-- Init: the contract lives in _temp.lua. Binding, tint and state reset belong
-- to the soul, so the engine never pokes these fields from outside.
---@param sprite table|nil The player sprite driven by this soul.
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
            if (up > 0) then sprite.y = sprite.y - speed * 60 * dt end
            if (down > 0) then sprite.y = sprite.y + speed * 60 * dt end
            if (left > 0) then sprite.x = sprite.x - speed * 60 * dt end
            if (right > 0) then sprite.x = sprite.x + speed * 60 * dt end
        else
            if (up > 0) then sprite.y = sprite.y - speed end
            if (down > 0) then sprite.y = sprite.y + speed end
            if (left > 0) then sprite.x = sprite.x - speed end
            if (right > 0) then sprite.x = sprite.x + speed end
        end
    end
end

return action