local action = {
    sprite = nil,
    can_move = true,
    is_moving = false
}

local speed = 2

---Controls the player's movement and behaviour.
---@param dt number|nil
function action.Update(dt)
    if (not action.sprite) then return end

    local can_move = action.can_move
    local sprite = action.sprite
    local up, down, left, right = Keyboard.GetState("up"), Keyboard.GetState("down"), Keyboard.GetState("left"), Keyboard.GetState("right")
    local cancel = Keyboard.GetState("cancel")

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