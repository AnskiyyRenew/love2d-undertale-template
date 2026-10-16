--  CELESTE SOUL
--  ============================================================================
--  A platformer-style soul inspired by Celeste's movement kit: walk, jump,
--  wall grab, wall slide, wall jump, and an 8-directional dash (with double
--  dash). Gravity is always downward (rotation 0), unlike the blue soul's
--  four-directional gravity.
--
--  Controls (raw key IDs — bypasses bind groups so Z/X/C are exclusive):
--    Arrows .... move / climb (while grabbing) / dash direction
--    Z .......... hold to grab wall (requires stamina)
--    X .......... dash (edge press, needs a direction)
--    C .......... jump / wall jump (edge press)
--
--  Dash colours (reflect how many dashes are currently available):
--    2 dashes .... {1, 0.5, 1}  (light pink)
--    1 dash ..... {1, 0.3, 0.3}  (red)
--    0 dashes ... {0.3, 1, 1}    (cyan)
--
--  Stamina:
--    Max 110. Each wall jump costs 27.5 (4 wall jumps = 110, then depleted).
--    When stamina hits 0: can't grab walls, forced wall slide, flash red.
--    Refreshes fully on ground / platform touch.
--
--  Arena size note: the collision queries (PlayerOnGround / PlayerOnWall etc.)
--  in Arenas.lua now read the sprite's actual half-extent from xscale/yscale,
--  so crouching (yscale < 1) no longer makes the soul float. Nothing extra to
--  do here — just set sprite.yscale at the call site.
-- ============================================================================

local action = {
    sprite = nil,
    can_move = true,
    is_moving = false,
    -- Opt in to one-way platforms (Player.BluePlatform surfaces).
    use_platforms = true
}

-- Tunable constants (px/frame at 60fps)
local WALK_SPEED        = 2.5    -- horizontal walk speed
local GRAVITY           = 0.4    -- per-frame gravity acceleration
local MAX_FALL          = 8      -- terminal fall velocity
local JUMP_FORCE        = 7      -- initial upward velocity on jump
local FLOAT_SPEED       = 1.5    -- upward drift after variable-jump cut
local CLIMB_UP_SPEED    = 1.5    -- wall-grab climb up  (slower, like Celeste)
local CLIMB_DOWN_SPEED  = 3      -- wall-grab climb down
local WALL_SLIDE_SPEED  = 2      -- max fall speed while wall sliding
local WALL_JUMP_X       = 4      -- wall-jump horizontal burst
local WALL_JUMP_Y       = 6      -- wall-jump upward burst
local WALL_JUMP_CONTROL = 8      -- frames of lerped horizontal control
local WALL_JUMP_LERP    = 0.25   -- lerp factor per frame during control window
local DASH_SPEED        = 7      -- dash velocity (constant during dash)
local DASH_DURATION     = 10     -- dash duration in frames
local MAX_DASHES        = 2      -- dashes refreshed on ground / platform touch

-- Stamina
local MAX_STAMINA       = 110    -- 4 wall jumps (27.5 each) = 110
local WALL_JUMP_STAMINA = 27.5   -- stamina cost per wall jump

-- Dash colours (by remaining dash count)
local COLOR_TWO_DASH   = {1, 0.5, 1}
local COLOR_ONE_DASH   = {1, 0.3, 0.3}
local COLOR_NO_DASH    = {0.3, 1, 1}

-- Exhaustion flash colour
local COLOR_FLASH_RED   = {1, 0, 0}

---Returns the colour that reflects the current dash count.
---@param dashes_remaining number
---@return table
local function dash_color(dashes_remaining)
    if (dashes_remaining >= 2) then return COLOR_TWO_DASH end
    if (dashes_remaining >= 1) then return COLOR_ONE_DASH end
    return COLOR_NO_DASH
end

-- State (module-level locals, reset in Init / Reset)
local vel_x = 0
local vel_y = 0
local is_jumping = false          -- true while holding a ground jump (variable height)
local dashes = MAX_DASHES
local is_dashing = false
local dash_timer = 0
local dash_dx = 0
local dash_dy = 0
local wall_jump_timer = 0
local stamina = MAX_STAMINA
local flash_timer = 0             -- increments while exhausted (for red flash)

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

    -- Time scale: 1 in frame-based mode, 60*dt in real-time mode so per-frame
    -- constants stay the same and the trajectory is framerate-independent.
    local realtime = Global.GetVariable("UseRealTime(dt)")
    local ts = (realtime and dt) and (60 * dt) or 1

    -- Input — raw key IDs ("z"/"x"/"c") bypass the bind groups so that
    -- Shift/Ctrl don't trigger dash/jump. Arrows stay on bind groups for
    -- gamepad compatibility.
    local up    = Controller.GetState("up")
    local down  = Controller.GetState("down")
    local left  = Controller.GetState("left")
    local right = Controller.GetState("right")
    local grab_btn = Controller.GetState("z")   -- Z only (not Return/Shift)
    local dash_btn = Controller.GetState("x")   -- X only (not Shift)
    local jump_btn = Controller.GetState("c")   -- C only (not Ctrl)

    -- Digital direction vector (-1 / 0 / +1 per axis)
    local input_x = (right > 0 and 1 or 0) - (left > 0 and 1 or 0)
    local input_y = (down > 0 and 1 or 0) - (up > 0 and 1 or 0)

    action.is_moving = (input_x ~= 0)

    -- Collision state — reflects the position clamped by Arenas.Update last
    -- frame, so it is accurate at the start of this frame (before we move).
    local on_ground  = Arenas.PlayerOnGround(sprite) or Player.platform_ground
    local on_ceiling = Arenas.PlayerOnCeiling(sprite)
    local wall_side  = Arenas.GetWallSide(sprite)   -- 1 = right, -1 = left, 0 = none
    local on_wall    = (wall_side ~= 0)

    -- ========================================================================
    --  DASH (overrides everything else while active)
    -- ========================================================================
    if (is_dashing) then
        dash_timer = dash_timer - ts
        if (dash_timer <= 0) then
            -- Dash ends: leave a fraction of the dash velocity as residual
            -- momentum so the transition into normal physics isn't a dead stop.
            is_dashing = false
            vel_x = dash_dx * 0.4
            vel_y = dash_dy * 0.4
        else
            sprite.speed = {x = dash_dx * ts, y = dash_dy * ts}
            sprite:Move(dash_dx * ts, dash_dy * ts)
            return
        end
    end

    -- Dash trigger: edge press + must have a direction + must have a dash left
    if (dash_btn == 1 and dashes > 0 and (input_x ~= 0 or input_y ~= 0)) then
        is_dashing  = true
        dash_timer  = DASH_DURATION
        dashes      = dashes - 1
        local len   = math.sqrt(input_x * input_x + input_y * input_y)
        dash_dx     = (input_x / len) * DASH_SPEED
        dash_dy     = (input_y / len) * DASH_SPEED
        -- Colour reflects remaining dashes (already decremented above).
        sprite.color = dash_color(dashes)
        sprite.speed = {x = dash_dx * ts, y = dash_dy * ts}
        sprite:Move(dash_dx * ts, dash_dy * ts)
        return
    end

    -- ========================================================================
    --  GROUND REFRESH
    -- ========================================================================
    if (on_ground) then
        dashes = MAX_DASHES
        stamina = MAX_STAMINA
        if (vel_y > 0) then vel_y = 0 end   -- stop residual downward velocity
    end

    -- Wall grab: hold Z while touching a wall, not on the ground, and still
    -- have stamina. When stamina is depleted the player can't grab — they
    -- slide down instead (see forced slide below).
    local wall_grab = (on_wall and grab_btn > 0 and not on_ground and stamina > 0)
    local exhausted = (stamina <= 0 and on_wall and not on_ground)

    -- ========================================================================
    --  JUMP / WALL JUMP (edge press on C)
    -- ========================================================================
    local wall_jumped = false
    if (jump_btn == 1) then
        if (on_ground) then
            vel_y = -JUMP_FORCE
            is_jumping = true
            wall_jump_timer = 0
        elseif (on_wall and stamina > 0) then
            -- Burst away from the wall + upward. Costs stamina.
            vel_x = -wall_side * WALL_JUMP_X
            vel_y = -WALL_JUMP_Y
            is_jumping = false
            wall_jumped = true
            wall_jump_timer = WALL_JUMP_CONTROL
            stamina = math.max(0, stamina - WALL_JUMP_STAMINA)
        end
    end

    -- Variable jump height: releasing C while still rising cuts the upward
    -- velocity to a small drift, giving short-hop / full-hop control.
    if (is_jumping and jump_btn <= 0) then
        is_jumping = false
        if (vel_y < -FLOAT_SPEED) then
            vel_y = -FLOAT_SPEED
        end
    end

    -- ========================================================================
    --  PHYSICS
    -- ========================================================================
    if (wall_grab and not wall_jumped) then
        -- Cling: no gravity, no horizontal drift. Climb with vertical input.
        -- Up is slower (CLIMB_UP_SPEED) than down (CLIMB_DOWN_SPEED), matching
        -- Celeste's speedModifier = y > 0 ? 0.5 : 1.
        vel_x = 0
        if (input_y < 0) then
            vel_y = -CLIMB_UP_SPEED
        elseif (input_y > 0) then
            vel_y = CLIMB_DOWN_SPEED
        else
            vel_y = 0
        end
    else
        -- Gravity (only when airborne)
        if (not on_ground) then
            vel_y = vel_y + GRAVITY * ts
        end

        -- Wall slide: touching a wall, airborne, not grabbing.
        --   Normal: must be pushing toward the wall to slide.
        --   Exhausted (stamina = 0): forced slide regardless of input.
        if (on_wall and not on_ground and not wall_grab) then
            local pushing = (input_x > 0 and wall_side > 0)
                         or (input_x < 0 and wall_side < 0)
            if ((pushing or exhausted) and vel_y > WALL_SLIDE_SPEED) then
                vel_y = WALL_SLIDE_SPEED
            end
        end

        -- Terminal velocity
        vel_y = math.min(vel_y, MAX_FALL)

        -- Horizontal movement
        if (wall_jump_timer > 0) then
            -- After a wall jump, horizontal control is lerped (reduced) for a
            -- few frames so the burst isn't immediately cancelled by input.
            local target_vx = input_x * WALK_SPEED
            local lerp_f = math.min(1, WALL_JUMP_LERP * ts)
            vel_x = vel_x + (target_vx - vel_x) * lerp_f
            wall_jump_timer = wall_jump_timer - ts
        else
            vel_x = input_x * WALK_SPEED
        end
    end

    -- Ceiling bonk: zero out upward velocity when the head touches the ceiling.
    if (on_ceiling and vel_y < 0) then
        vel_y = 0
    end

    -- Record the frame's movement on sprite.speed so Player.BluePlatformCollide
    -- can reconstruct the previous-foot position for its crossing test (the
    -- Sprites library's Move() does not update .speed on its own).
    sprite.speed = {x = vel_x * ts, y = vel_y * ts}
    sprite:Move(vel_x * ts, vel_y * ts)

    -- ========================================================================
    --  COLOUR FEEDBACK
    -- ========================================================================
    if (is_dashing) then
        -- Dash sets its own colour at trigger time; don't override mid-dash.
    elseif (exhausted) then
        -- Stamina depleted + on wall + airborne: flash red.
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
