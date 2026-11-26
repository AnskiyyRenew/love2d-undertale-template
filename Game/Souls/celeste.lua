--- Celeste soul: walk, jump, wall grab/slide/jump and an 8-directional dash (double dash). Gravity is always downward (rotation 0).

local action = {
    sprite = nil,
    can_move = true,
    is_moving = false,
    use_platforms = true
}

local WALK_SPEED        = 2.5
local GRAVITY           = 0.4
local MAX_FALL          = 8
local JUMP_FORCE        = 7
local FLOAT_SPEED       = 1.5
local CLIMB_UP_SPEED    = 1.5
local CLIMB_DOWN_SPEED  = 3
local WALL_SLIDE_SPEED  = 2
local WALL_JUMP_X       = 4
local WALL_JUMP_Y       = 6
local WALL_JUMP_CONTROL = 8
local WALL_JUMP_LERP    = 0.25
local DASH_SPEED        = 7
local DASH_DURATION     = 10
local MAX_DASHES        = 2

local MAX_STAMINA       = 110
local WALL_JUMP_STAMINA = 27.5

local COLOR_TWO_DASH   = {1, 0.5, 1}
local COLOR_ONE_DASH   = {1, 0.3, 0.3}
local COLOR_NO_DASH    = {0.3, 1, 1}

local COLOR_FLASH_RED   = {1, 0, 0}

---Returns the colour that reflects the current dash count.
---@param dashes_remaining number
---@return table
local function dash_color(dashes_remaining)
    if (dashes_remaining >= 2) then return COLOR_TWO_DASH end
    if (dashes_remaining >= 1) then return COLOR_ONE_DASH end
    return COLOR_NO_DASH
end

local vel_x = 0
local vel_y = 0
local is_jumping = false
local dashes = MAX_DASHES
local is_dashing = false
local dash_timer = 0
local dash_dx = 0
local dash_dy = 0
local wall_jump_timer = 0
local stamina = MAX_STAMINA
local flash_timer = 0

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
        sprite.color = dash_color(MAX_DASHES)
        sprite.rotation = 0
    end
    action.Reset()
    return action
end

---Resets the soul back to its default state.
function action.Reset()
    vel_x = 0
    vel_y = 0
    is_jumping = false
    dashes = MAX_DASHES
    is_dashing = false
    dash_timer = 0
    dash_dx = 0
    dash_dy = 0
    wall_jump_timer = 0
    stamina = MAX_STAMINA
    flash_timer = 0
    if (action.sprite) then
        action.sprite.color = dash_color(MAX_DASHES)
    end
end

---Returns the soul's vertical speed (positive = falling). Used by the platform
---system to decide whether to catch the player.
---@return number
function action.GetSpeed()
    return vel_y
end

---Overrides the soul's vertical speed.
---@param value number
function action.SetSpeed(value)
    vel_y = (value or 0)
end

---Lands the soul on a one-way platform: kill the fall speed and refresh dashes.
function action.Land()
    vel_y = 0
    dashes = MAX_DASHES
    stamina = MAX_STAMINA
    is_jumping = false
end

---Controls the player's movement and behaviour.
---@param dt number|nil
function action.Update(dt)
    if (not action.sprite) then return end
    if (not action.can_move) then return end

    local sprite = action.sprite

    local realtime = Global.GetVariable("UseRealTime(dt)")
    local ts = (realtime and dt) and (60 * dt) or 1

    local up    = Controller.GetState("up")
    local down  = Controller.GetState("down")
    local left  = Controller.GetState("left")
    local right = Controller.GetState("right")
    local grab_btn = Controller.GetState("z")
    local dash_btn = Controller.GetState("x")
    local jump_btn = Controller.GetState("c")

    local input_x = (right > 0 and 1 or 0) - (left > 0 and 1 or 0)
    local input_y = (down > 0 and 1 or 0) - (up > 0 and 1 or 0)

    action.is_moving = (input_x ~= 0)

    local on_ground  = Arenas.PlayerOnGround(sprite) or Player.platform_ground
    local on_ceiling = Arenas.PlayerOnCeiling(sprite)
    local wall_side  = Arenas.GetWallSide(sprite)
    local on_wall    = (wall_side ~= 0)

    if (is_dashing) then
        dash_timer = dash_timer - ts
        if (dash_timer <= 0) then
            is_dashing = false
            vel_x = dash_dx * 0.4
            vel_y = dash_dy * 0.4
        else
            sprite.speed = {x = dash_dx * ts, y = dash_dy * ts}
            sprite:Move(dash_dx * ts, dash_dy * ts)
            return
        end
    end

    if (dash_btn == 1 and dashes > 0 and (input_x ~= 0 or input_y ~= 0)) then
        is_dashing  = true
        dash_timer  = DASH_DURATION
        dashes      = dashes - 1
        local len   = math.sqrt(input_x * input_x + input_y * input_y)
        dash_dx     = (input_x / len) * DASH_SPEED
        dash_dy     = (input_y / len) * DASH_SPEED
        sprite.color = dash_color(dashes)
        sprite.speed = {x = dash_dx * ts, y = dash_dy * ts}
        sprite:Move(dash_dx * ts, dash_dy * ts)
        return
    end

    if (on_ground) then
        dashes = MAX_DASHES
        stamina = MAX_STAMINA
        if (vel_y > 0) then vel_y = 0 end
    end

    local wall_grab = (on_wall and grab_btn > 0 and not on_ground and stamina > 0)
    local exhausted = (stamina <= 0 and on_wall and not on_ground)

    local wall_jumped = false
    if (jump_btn == 1) then
        if (on_ground) then
            vel_y = -JUMP_FORCE
            is_jumping = true
            wall_jump_timer = 0
        elseif (on_wall and stamina > 0) then
            vel_x = -wall_side * WALL_JUMP_X
            vel_y = -WALL_JUMP_Y
            is_jumping = false
            wall_jumped = true
            wall_jump_timer = WALL_JUMP_CONTROL
            stamina = math.max(0, stamina - WALL_JUMP_STAMINA)
        end
    end

    if (is_jumping and jump_btn <= 0) then
        is_jumping = false
        if (vel_y < -FLOAT_SPEED) then
            vel_y = -FLOAT_SPEED
        end
    end

    if (wall_grab and not wall_jumped) then
        vel_x = 0
        if (input_y < 0) then
            vel_y = -CLIMB_UP_SPEED
        elseif (input_y > 0) then
            vel_y = CLIMB_DOWN_SPEED
        else
            vel_y = 0
        end
    else
        if (not on_ground) then
            vel_y = vel_y + GRAVITY * ts
        end

        if (on_wall and not on_ground and not wall_grab) then
            local pushing = (input_x > 0 and wall_side > 0)
                         or (input_x < 0 and wall_side < 0)
            if ((pushing or exhausted) and vel_y > WALL_SLIDE_SPEED) then
                vel_y = WALL_SLIDE_SPEED
            end
        end

        vel_y = math.min(vel_y, MAX_FALL)

        if (wall_jump_timer > 0) then
            local target_vx = input_x * WALK_SPEED
            local lerp_f = math.min(1, WALL_JUMP_LERP * ts)
            vel_x = vel_x + (target_vx - vel_x) * lerp_f
            wall_jump_timer = wall_jump_timer - ts
        else
            vel_x = input_x * WALK_SPEED
        end
    end

    if (on_ceiling and vel_y < 0) then
        vel_y = 0
    end

    sprite.speed = {x = vel_x * ts, y = vel_y * ts}
    sprite:Move(vel_x * ts, vel_y * ts)

    if (is_dashing) then
    elseif (exhausted) then
        flash_timer = flash_timer + ts
        if (math.floor(flash_timer) % 8 < 4) then
            sprite.color = COLOR_FLASH_RED
        else
            sprite.color = dash_color(dashes)
        end
    else
        flash_timer = 0
        sprite.color = dash_color(dashes)
    end
end

return action
