local action = {
    sprite = nil,
    can_move = true,
    is_moving = false
}

-- Default vars.
local speed = 2

---Controls the player's movement and behaviour.
---@param dt number|nil
function action.Update(dt)
    if (not action.sprite) then return end

    local can_move = action.can_move
    local sprite = action.sprite
    local up, down, left, right = Keyboard.GetState("up"), Keyboard.GetState("down"), Keyboard.GetState("left"), Keyboard.GetState("right")
    local cancel = Keyboard.GetState("cancel")

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