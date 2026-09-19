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

---Derives the gravity direction from a rotation angle. The soul always falls
---towards the side it is "standing" on (the sprite's local down).
---0deg = down, 90deg = left, 180deg = up, 270deg = right.
---@param angle number
---@return string
local function auto_direction(angle)
    local a = angle % 360
    if (a <= 45 or a > 315) then
        return "down"
    elseif (a <= 135) then
        return "left"
    elseif (a <= 225) then
        return "up"
    else
        return "right"
    end
end

---Updates the current gravity direction (and mirrors it into `dir`).
---@param direction string|nil "down"|"up"|"left"|"right"
local function set_direction(direction)
    if (direction == "down" or direction == "up" or direction == "left" or direction == "right") then
        dir = direction
        man_dir = direction
    end
end

---Sets the sprite rotation without changing the gravity direction.
---@param angle number
function action.Angle(angle)
    if (not action.sprite) then return end
    action.sprite.rotation = angle
end

---Sets both the gravity direction and the sprite rotation.
---@param direction string "down"|"up"|"left"|"right"
---@param angle number|nil
function action.AngleDir(direction, angle)
    if (not action.sprite) then return end
    set_direction(direction)
    if (angle) then
        action.sprite.rotation = angle
    end
end

---Sets the rotation and derives the gravity direction automatically from it.
---@param angle number
function action.AngleAuto(angle)
    if (not action.sprite) then return end
    action.sprite.rotation = angle
    set_direction(auto_direction(angle))
end

---Starts a slam towards the current gravity direction.
---@param angle number
---@param hp number|nil
---@param inv number|nil
function action.Slam(angle, hp, inv)
    if (not action.sprite) then return end
    slamming = true
    current_speed = 15
    action.sprite.rotation = angle

    slam_hp = (hp or 0)
    slam_inv = (inv or 0)
end

---Starts a slam with an explicit gravity direction and rotation.
---@param direction string "down"|"up"|"left"|"right"
---@param angle number|nil
---@param hp number|nil
---@param inv number|nil
function action.SlamDir(direction, angle, hp, inv)
    if (not action.sprite) then return end
    slamming = true
    current_speed = 15
    set_direction(direction)
    if (angle) then
        action.sprite.rotation = angle
    end

    slam_hp = (hp or 0)
    slam_inv = (inv or 0)
end

---Starts a slam, deriving the gravity direction from the rotation angle.
---@param angle number
---@param hp number|nil
---@param inv number|nil
function action.SlamAuto(angle, hp, inv)
    if (not action.sprite) then return end
    slamming = true
    current_speed = 15
    action.sprite.rotation = angle
    set_direction(auto_direction(angle))

    slam_hp = (hp or 0)
    slam_inv = (inv or 0)
end

---Returns the current gravity direction.
---@return string
function action.GetDirection()
    return man_dir
end

---Overrides the gravity direction without touching the rotation.
---@param direction string "down"|"up"|"left"|"right"
function action.SetDirection(direction)
    set_direction(direction)
end

---Resets the soul back to its default state.
function action.Reset()
    speed = 2
    current_speed = 0
    can_jump = false
    jumping = false
    first_jumped = true
    slamming = false
    slam_hp = 0
    slam_inv = 0
    set_direction("down")
end

---Returns the soul's vertical speed along its gravity direction.
---Positive means "falling" (moving towards the platform), negative means jumping.
---@return number
function action.GetSpeed()
    return current_speed
end

---Overrides the soul's vertical speed.
---@param value number
function action.SetSpeed(value)
    current_speed = (value or 0)
end

---Locks or unlocks jumping.
---@param value boolean
function action.SetCanJump(value)
    can_jump = (value == true)
end

---Forces the variable-height jump state.
---@param value boolean
function action.SetJumping(value)
    jumping = (value == true)
end

---Lands the soul on a one-way platform: kill the fall speed and allow a jump.
function action.Land()
    can_jump = true
    jumping = false
    current_speed = 0
    first_jumped = false
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

            if (Arenas.PlayerOnGround(sprite) or Player.platform_ground) then
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

            -- The gravity direction decides which key jumps and which keys move
            -- sideways, so the soul can "stand" on any of the four sides.
            local jump_key = 0
            if (man_dir == "down") then
                jump_key = up
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
            elseif (man_dir == "up") then
                jump_key = down
                if (left > 0) then
                    sprite:Move(
                        speed * cos,
                        speed * sin
                    )
                elseif (right > 0) then
                    sprite:Move(
                        speed * -cos,
                        speed * -sin
                    )
                end
            elseif (man_dir == "left") then
                jump_key = right
                if (up > 0) then
                    sprite:Move(
                        speed * -cos,
                        speed * -sin
                    )
                elseif (down > 0) then
                    sprite:Move(
                        speed * cos,
                        speed * sin
                    )
                end
            elseif (man_dir == "right") then
                jump_key = left
                if (up > 0) then
                    sprite:Move(
                        speed * cos,
                        speed * sin
                    )
                elseif (down > 0) then
                    sprite:Move(
                        speed * -cos,
                        speed * -sin
                    )
                end
            end

            if (jumping) then
                current_speed = current_speed + gravity
                if (jump_key <= 0) then
                    jumping = false
                    current_speed = (current_speed < -float and -float or current_speed)
                end
            else
                if (can_jump) then
                    if (jump_key > 0 and not first_jumped) then
                        first_jumped = true
                        current_speed = -max_jump
                        can_jump = false
                        jumping = true
                    end
                else
                    current_speed = current_speed + gravity
                end
            end

            -- Head bonk: if the soul's head touches the top of the arena while
            -- jumping, give it the float/glide speed exactly once, then drop out
            -- of the jump state so gravity takes over. Clearing `jumping` is what
            -- stops it lingering on the ceiling while the key stays held.
            if (jumping and Arenas.PlayerOnCeiling(sprite)) then
                current_speed = -float
                jumping = false
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