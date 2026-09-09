local action = {
    sprite = nil,
    can_move = true,
    is_moving = false
}

-- Default vars.
local speed = 2
local gravity = 0.15
local max_jump = 5
local float = 1
local can_jump = false
local jumping = false
local first_jumped = true
local slamming = false
local slam_hp = 0
local slam_inv = 0
local current_speed = 0
local dir = "down"
local man_dir = "down"
local speed_limit = 10

function action.Angle(angle)
    if (not action.sprite) then return end
    action.sprite.rotation = angle
end

function action.Slam(angle, hp, inv)
    if (not action.sprite) then return end
    slamming = true
    current_speed = 15
    action.sprite.rotation = angle

    slam_hp = (hp or 0)
    slam_inv = (inv or 0)
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
            local cos, sin = math.cos(math.rad(sprite.rotation)), math.sin(math.rad(sprite.rotation))

            if (Arenas.PlayerOnGround(sprite)) then
                can_jump = true
                jumping = false
                current_speed = 0
                first_jumped = false

                if (slamming) then
                    Audio.PlaySound("snd_slam.wav")
                    Audio.PlaySound("snd_phurt.wav")
                    slamming = false
                    Player.Hurt(slam_hp, slam_inv)
                end
            else
                can_jump = false
                first_jumped = false
            end

            if (jumping) then
                current_speed = current_speed + gravity
                if (up <= 0) then
                    jumping = false
                    current_speed = (current_speed < -float and -float or current_speed)
                end
            else
                if (can_jump) then
                    if (man_dir == "down" and up > 0 and not first_jumped) then
                        first_jumped = true
                        current_speed = -max_jump
                        can_jump = false
                        jumping = true
                    end
                else
                    current_speed = current_speed + gravity
                end
            end

            if (man_dir == "down") then
                if (left > 0) then
                    sprite:Move(
                        speed * -cos,
                        speed * -sin
                    )
                elseif (right > 0) then
                    sprite:Move(
                        speed * cos,
                        speed * sin
                    )
                end
            end

            current_speed = math.min(current_speed, speed_limit)
            sprite:Move(
                -current_speed * sin,
                current_speed * cos
            )
        end
    end
end

return action