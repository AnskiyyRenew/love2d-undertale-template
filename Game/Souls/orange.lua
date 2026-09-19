local action = {
    sprite = nil,
    can_move = true,
    is_moving = false
}

-- Default vars.
local speed = 2
local time = 0
local dir = "idle"

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

    time = time + 1

    if (not can_move) then return end
    if (sprite) then
        if (time % 3 == 0) then
            local shadow = Sprites.CreateSprite(sprite.path, sprite.layer - 0.1)
            shadow.color = sprite.color
            shadow:MoveTo(sprite:GetPosition())
            shadow.Step = function (self)
                self.alpha = self.alpha - 0.1
                if (self.alpha <= 0) then
                    self:Destroy()
                end
            end
        end
        if (Global.GetVariable("UseRealTime(dt)")) then
            -- Put your dt logic here.
        else
            -- Put your frames logic here.
            local move_x = 0
            local move_y = 0

            if (left > 0) then move_x = -1 end
            if (right > 0) then move_x = 1 end
            if (up > 0) then move_y = -1 end
            if (down > 0) then move_y = 1 end
            if (move_x == 0 and move_y == -1) then
                dir = "u"
            elseif (move_x == 0 and move_y == 1) then
                dir = "d"
            elseif (move_x == -1 and move_y == 0) then
                dir = "l"
            elseif (move_x == 1 and move_y == 0) then
                dir = "r"
            elseif (move_x == -1 and move_y == -1) then
                dir = "ul"
            elseif (move_x == 1 and move_y == -1) then
                dir = "ur"
            elseif (move_x == -1 and move_y == 1) then
                dir = "dl"
            elseif (move_x == 1 and move_y == 1) then
                dir = "dr"
            end

            if (dir == "u") then
                sprite:Move(0, -speed)
            elseif (dir == "d") then
                sprite:Move(0, speed)
            elseif (dir == "l") then
                sprite:Move(-speed, 0)
            elseif (dir == "r") then
                sprite:Move(speed, 0)
            elseif (dir == "ul") then
                sprite:Move(-speed, -speed)
            elseif (dir == "ur") then
                sprite:Move(speed, -speed)
            elseif (dir == "dl") then
                sprite:Move(-speed, speed)
            elseif (dir == "dr") then
                sprite:Move(speed, speed)
            end
        end
    end
end

return action