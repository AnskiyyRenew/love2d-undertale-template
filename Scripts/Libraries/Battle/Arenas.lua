local arenas = {
    insts = {},
    stencils = {},
    _onground = false,

    refollow = false
}

local function check_plus_amount()
    local amount = 0

    for _, a in ipairs(arenas.insts)
    do
        if (a.is_containing) then
            amount = amount + 1
        end
    end

    return amount
end

local function smooth_value(value, target, speed)
    local _res = value
    if (_res > target) then
        _res = math.max(_res - speed, target)
    elseif (_res < target) then
        _res = math.min(_res + speed, target)
    end
    return _res
end

local function clamp(value, min, max)
    return math.max(min, math.min(value, max))
end

local function direction(x1, y1, x2, y2, offset)
    local dx = x2 - x1
    local dy = y2 - y1
    return math.deg(math.atan2(dy, dx)) + offset
end

local function check_nearest_arena()
    local distance = math.huge
    local nearest

    for i = 1, #arenas.insts
    do
        local shell = arenas.insts[i]
        if (shell.is_active and shell.mode == "plus") then
            if (shell.shape == "rectangle") then
                local dx, dy = Player.sprite.x - shell.black.x, Player.sprite.y - shell.black.y
                local sin, cos = math.sin(math.rad(shell.black.rotation)), math.cos(math.rad(shell.black.rotation))
                local w, h = shell.width, shell.height
                local vx, vy = 0, 0

                vx = clamp(dx * cos + dy * sin, -w / 2 + 8, w / 2 - 8)
                vy = clamp(dy * cos - dx * sin, -h / 2 + 8, h / 2 - 8)

                local dist = math.sqrt(math.pow(vx - (dx * cos + dy * sin), 2) + math.pow(vy - (dy * cos - dx * sin), 2))
                if (dist < distance) then
                    distance = dist
                    nearest = shell
                end
            elseif (shell.shape == "circle") then
                local dx, dy = Player.sprite.x - shell.black.x, Player.sprite.y - shell.black.y
                local sin, cos = math.sin(math.rad(shell.black.rotation)), math.cos(math.rad(shell.black.rotation))
                local w, h = shell.width, shell.height
                local a, b = w / 2 - 8, h / 2 - 8
                local rx, ry = dx * cos + dy * sin, dy * cos - dx * sin
                local vx, vy = 0, 0

                local relangle = direction(shell.black.x, shell.black.y, Player.sprite.x, Player.sprite.y, 0)
                local nsin, ncos = math.cos(math.rad(relangle)), math.sin(math.rad(relangle))
                vx = clamp(rx, -a * ncos, a * ncos)
                vy = clamp(ry, -b * nsin, b * nsin)
                local dist = math.sqrt(math.pow(vx - rx, 2) + math.pow(vy - ry, 2))
                if (dist < distance) then
                    distance = dist
                    nearest = shell
                end
            end
        end
    end

    return nearest
end

-- Check if a world-space point is valid for the player to stand on:
--   1) Must be inside at least one active plus arena (shrunk by 8px for player size)
--   2) Must NOT be inside any active minus arena (expanded by 5+8=13px per side for visual margin + player size)
local function is_point_valid(px, py)
    -- Check if inside any active plus arena
    local in_plus = false

    for _, a in ipairs(arenas.insts)
    do
        if (a.is_active and a.mode == "plus") then
            local dx, dy = px - a.x, py - a.y
            local cos, sin = math.cos(math.rad(a.rotation)), math.sin(math.rad(a.rotation))
            local w, h = a.width, a.height
            local lx = dx * cos + dy * sin
            local ly = dy * cos - dx * sin

            if (a.shape == "rectangle") then
                if (lx >= -w / 2 + 8 and lx <= w / 2 - 8 and ly >= -h / 2 + 8 and ly <= h / 2 - 8) then
                    in_plus = true
                    break
                end
            elseif (a.shape == "circle" or a.shape == "ellipse") then
                local a_axis, b_axis = w / 2 - 8, h / 2 - 8
                if ((lx * lx) / (a_axis * a_axis) + (ly * ly) / (b_axis * b_axis) <= 1) then
                    in_plus = true
                    break
                end
            end
        end
    end

    if (not in_plus) then return false end

    -- Check if NOT inside any active minus arena (expanded by (w+10)/2 + 8 = w/2 + 13 per side)
    for _, a in ipairs(arenas.insts)
    do
        if (a.is_active and a.mode == "minus") then
            local dx, dy = px - a.x, py - a.y
            local cos, sin = math.cos(math.rad(a.rotation)), math.sin(math.rad(a.rotation))
            local w, h = a.width, a.height
            local lx = dx * cos + dy * sin
            local ly = dy * cos - dx * sin

            if (a.shape == "rectangle") then
                if (lx >= -(w + 10) / 2 - 8 and lx <= (w + 10) / 2 + 8 and ly >= -(h + 10) / 2 - 8 and ly <= (h + 10) / 2 + 8) then
                    return false
                end
            elseif (a.shape == "circle" or a.shape == "ellipse") then
                local a_axis, b_axis = w / 2 + 8, h / 2 + 8
                if ((lx * lx) / (a_axis * a_axis) + (ly * ly) / (b_axis * b_axis) <= 1) then
                    return false
                end
            end
        end
    end

    return true
end

-- Circular diffusion brute-force search for the nearest valid landing point.
-- Starts from (px, py) and checks concentric circles with increasing radius.
-- Returns (px, py) if no valid point is found within max_radius.
local function find_nearest_valid(px, py)
    local step = 4
    local max_radius = 300

    -- Check the center point first
    if (is_point_valid(px, py)) then
        return px, py
    end

    for r = step, max_radius, step
    do
        local num_points = math.max(8, math.floor(2 * math.pi * r / step))

        for i = 1, num_points
        do
            local angle = (2 * math.pi / num_points) * i
            local cx = px + r * math.cos(angle)
            local cy = py + r * math.sin(angle)

            if (is_point_valid(cx, cy)) then
                return cx, cy
            end
        end
    end

    -- Fallback: return original position if nothing found
    return px, py
end

-- Shared arena probe. `ox`/`oy` is an offset from the player's centre; the arena
-- tests are direction-agnostic, so the same code serves the foot
-- (PlayerOnGround, gravity side) and the head (PlayerOnCeiling, opposite side).
local function side_touching(player, ox, oy)
    local px, py = player.x + ox, player.y + oy

    for _, a in ipairs(arenas.insts)
    do
        if (a.is_active) then
            local dx, dy = px - a.x, py - a.y
            local cos, sin = math.cos(math.rad(a.rotation)), math.sin(math.rad(a.rotation))
            local lx = dx * cos + dy * sin
            local ly = dy * cos - dx * sin
            local w, h = a.width, a.height

            if (a.mode == "plus") then
                -- Touching when the probe leaves the arena on any side. Since the
                -- probe points along a fixed local axis it naturally crosses the
                -- edge on that side, so this detects all four walls.
                if (a.shape == "rectangle") then
                    if (lx < -w / 2 or lx > w / 2 or ly < -h / 2 or ly > h / 2) then
                        return true
                    end
                elseif (a.shape == "circle" or a.shape == "ellipse") then
                    local a_axis, b_axis = w / 2, h / 2
                    if ((lx * lx) / (a_axis * a_axis) + (ly * ly) / (b_axis * b_axis) >= 1) then
                        return true
                    end
                end
            elseif (a.mode == "minus") then
                -- Touching when the probe enters the range.
                -- NOTE: the collision in Arenas.Update keeps the player's centre out of the
                -- expanded forbidden zone (thickness*2 + 8 per side), so after the first frame
                -- the probe can never reach the raw [-w/2, w/2] x [-h/2, h/2] range. Expand the
                -- detection zone by the player's half-size (8px) only - not by the arena's visual
                -- thickness - so the probe poking 9px past the centre still counts as entering it.
                local half_w = w / 2 + 4
                local half_h = h / 2 + 4

                if (a.shape == "rectangle") then
                    if (lx >= -half_w and lx <= half_w and ly >= -half_h and ly <= half_h) then
                        return true
                    end
                elseif (a.shape == "circle" or a.shape == "ellipse") then
                    if ((lx * lx) / (half_w * half_w) + (ly * ly) / (half_h * half_h) <= 1) then
                        return true
                    end
                end
            end
        end
    end

    return false
end

function arenas.PlayerOnGround(player)
    local psin, pcos = math.sin(math.rad(player.rotation)), math.cos(math.rad(player.rotation))

    -- The player is a 16x16 square, so from its centre to the foot is 8px. The
    -- foot is probed along the player's local "down" (its gravity direction),
    -- so the same test works for every soul rotation:
    -- down (0), left (90), up (180) and right (270).
    return side_touching(player, -psin * 10, pcos * 10)
end

---Like PlayerOnGround, but probes the player's local "up": true when the top of
---the head touches an arena edge (e.g. the ceiling of the battle box, or the
---underside of a minus obstacle). Used by the blue soul's ceiling float.
---@param player table
---@return boolean
function arenas.PlayerOnCeiling(player)
    local psin, pcos = math.sin(math.rad(player.rotation)), math.cos(math.rad(player.rotation))

    -- Half the player's height plus a 2px margin, along the local "up" direction.
    return side_touching(player, psin * 10, -pcos * 10)
end

function arenas.New(mode, shape, x, y, width, height, angle)
    arenas.refollow = false
    local _x, _y, _width, _height, _angle = x, y, width, height, angle
    if (type(x) ~= "number") then _x = 320 end
    if (type(y) ~= "number") then _y = 320 end
    if (type(width) ~= "number") then _width = 155 end
    if (type(height) ~= "number") then _height = 130 end
    if (type(angle) ~= "number") then _angle = 0 end

    local arena = {
        mode = (mode or "plus"),
        shape = (shape or "rectangle"),
        thickness = 5,

        x = _x,
        y = _y,
        width = (_width > 16) and _width or 16,
        height = (_height > 16) and _height or 16,
        rotation = _angle,

        is_active = true,
        is_containing = false,

        move_player = true,
        followers = {}
    }
    local _target = {
        x = _x,
        y = _y,
        width = arena.width,
        height = arena.height,
        rotation = arena.rotation
    }
    arena.target = _target
    arena.speeds = {
        x = 7.5,
        y = 7.5,
        width = 15,
        height = 15,
        rotation = 15
    }

    if (arena.shape == "rectangle") then
        local white = Sprites.CreateSprite("px.png", "ArenasExtraW")
        local black = Sprites.CreateSprite("px.png", "ArenasExtraB")
        white.color = Global.GetVariable("MainColor")
        black.color = {0, 0, 0}

        if (arena.mode == "minus") then
            white.layer = "ArenasCoverW"
            black.layer = "ArenasCoverB"
            white:SetStencils(arenas.stencils)
            black:SetStencils(arenas.stencils)
        else
            local mask = Masks.New("rectangle", _x, _y, _width, _height, _angle, 0)
            arena.mask = mask
            table.insert(arenas.stencils, mask)
        end

        white:Scale(arena.width + arena.thickness * 2, arena.height + arena.thickness * 2)
        black:Scale(arena.width, arena.height)

        white:MoveTo(_x, _y)
        black:MoveTo(_x, _y)

        white.rotation = arena.rotation
        black.rotation = arena.rotation

        arena.white = white
        arena.black = black
    end

    function arena:Resize(w, h, imm)
        local _w = (w > 16 and w or 16)
        local _h = (h > 16 and h or 16)
        local _i = (imm or false)

        arena.target.width = _w
        arena.target.height = _h
        if (_i) then
            arena.width = _w
            arena.height = _h
        end
    end

    function arena:ResizeWithSpeed(w, h, speedw, speedh)
        local _w = (w > 16 and w or 16)
        local _h = (h > 16 and h or 16)

        arena.target.width = _w
        arena.target.height = _h
        arena.speeds.width = (speedw or 15)
        arena.speeds.height = (speedh or 15)
    end

    function arena:ResizeWithTime(w, h, timew, timeh)
        local _w = (w > 16 and w or 16)
        local _h = (h > 16 and h or 16)

        arena.target.width = _w
        arena.target.height = _h

        local dw = math.abs(arena.target.width - arena.width)
        local dh = math.abs(arena.target.height - arena.height)
        arena.speeds.width = (math.floor(dw / timew) or 15)
        arena.speeds.height = (math.floor(dh / timeh) or 15)
    end

    function arena:RotateTo(rotation)
        local _r = (rotation or 0)
        arena.target.rotation = _r
    end

    function arena:ResetSpeed()
        arena.speeds = {
            x = 7.5,
            y = 7.5,
            width = 15,
            height = 15,
            rotation = 15
        }
    end

    function arena:MoveTo(target_x, target_y, imm)
        arena.target.x = target_x
        arena.target.y = target_y

        if (imm) then
            arena.x = target_x
            arena.y = target_y
        end
    end

    function arena:SetThickness(t)
        arena.thickness = (t or 5)
    end

    function arena:OuterColor(color)
        arena.white.color = (color or {1, 1, 1})
    end
    function arena:InnerColor(color)
        arena.black.color = (color or {0, 0, 0})
    end

    function arena:UpSide(value)
        local w = arena.target.height + value
        if (w < 16) then w = 16 end

        arena.speeds.y = arena.speeds.height / 2
        arena.target.y = arena.target.y - (w - arena.target.height) / 2
        arena.target.height = w
    end

    function arena:DownSide(value)
        local w = arena.target.height + value
        if (w < 16) then w = 16 end

        arena.speeds.y = arena.speeds.height / 2
        arena.target.y = arena.target.y + (w - arena.target.height) / 2
        arena.target.height = w
    end

    function arena:LeftSide(value)
        local w = arena.target.width + value
        if (w < 16) then w = 16 end

        arena.speeds.x = arena.speeds.width / 2
        arena.target.x = arena.target.x - (w - arena.target.width) / 2
        arena.target.width = w
    end

    function arena:RightSide(value)
        local w = arena.target.width + value
        if (w < 16) then w = 16 end

        arena.speeds.x = arena.speeds.width / 2
        arena.target.x = arena.target.x + (w - arena.target.width) / 2
        arena.target.width = w
    end

    function arena:GetCenterPos(side)
        local res = {0, 0}
        local w_2 = arena.width / 2
        local h_2 = arena.height / 2
        local length = 0
        local sin, cos = math.sin(math.rad(arena.rotation)), math.cos(math.rad(arena.rotation))

        if (side == "up") then
            length = (h_2 + arena.thickness / 2)
            res = {
                arena.x + length * sin,
                arena.y - length * cos
            }
        elseif (side == "down") then
            length = -(h_2 + arena.thickness / 2)
            res = {
                arena.x + length * sin,
                arena.y - length * cos
            }
        elseif (side == "left") then
            length = (w_2 + arena.thickness / 2)
            res = {
                arena.x - length * cos,
                arena.y - length * sin
            }
        elseif (side == "right") then
            length = -(w_2 + arena.thickness / 2)
            res = {
                arena.x - length * cos,
                arena.y - length * sin
            }
        end

        return res[1], res[2]
    end

    function arena:GetCornerPos(corner)
        local res = {0, 0}
        local corner_x = arena.width / 2 + arena.thickness / 2
        local corner_y = arena.height / 2 + arena.thickness / 2
        local sin, cos = math.sin(math.rad(arena.rotation)), math.cos(math.rad(arena.rotation))
        if (corner == "ul") then
            corner_x = -arena.width / 2 - arena.thickness / 2
            corner_y = -arena.height / 2 - arena.thickness / 2
        elseif (corner == "ur") then
            corner_y = -arena.height / 2 - arena.thickness / 2
        elseif (corner == "dl") then
            corner_x = -arena.width / 2 - arena.thickness / 2
        end

        res[1] = arena.x + corner_x * cos - corner_y * sin
        res[2] = arena.y + corner_x * sin + corner_y * cos
        return res[1], res[2]
    end

    function arena:AddFollower(sprite, position)
        table.insert(arena.followers, {
            sprite = sprite,
            position = position
        })
    end

    function arena:Destroy()
        LuaEX.rmVarTable(arenas.insts, arena)
        arena.white:Destroy()
        arena.black:Destroy()
    end

    table.insert(arenas.insts, arena)
    return arena
end

function arenas.Update(dt)
    local p = Player.sprite

    for _, arena in ipairs(arenas.insts)
    do
        -- To target
        arena.x = smooth_value(arena.x, arena.target.x, arena.speeds.x)
        arena.y = smooth_value(arena.y, arena.target.y, arena.speeds.y)
        arena.width = smooth_value(arena.width, arena.target.width, arena.speeds.width)
        arena.height = smooth_value(arena.height, arena.target.height, arena.speeds.height)
        arena.rotation = smooth_value(arena.rotation, arena.target.rotation, arena.speeds.rotation)

        -- Sprite things
        arena.white:MoveTo(arena.x, arena.y)
        arena.black:MoveTo(arena.x, arena.y)
        arena.black:Scale(arena.width, arena.height)
        arena.white:Scale(arena.width + arena.thickness * 2, arena.height + arena.thickness * 2)
        arena.white.rotation = arena.rotation
        arena.black.rotation = arena.rotation
        if (arena.mask) then
            arena.mask:Follow(arena.white)
        end

        for _, follower in ipairs(arena.followers)
        do
            local x, y
            local position = follower.position
            if (position == "ul" or position == "ur" or position == "dl" or position == "dr") then
                x, y = arena:GetCornerPos(position)
            else
                x, y = arena:GetCenterPos(position)
            end
            follower.sprite:MoveTo(x, y)
        end

        if (arena.move_player) then
            p:Move(arena.black.speed.x, arena.black.speed.y)
        end

        -- Collision
        if (not arena.is_active) then return end

        local mode = arena.mode
        local shape = arena.shape

        local dx, dy = p.x - arena.x, p.y - arena.y
        local w, h = arena.width, arena.height
        local cos, sin = math.cos(math.rad(arena.rotation)), math.sin(math.rad(arena.rotation))

        if (mode == "plus") then
            if (shape == "rectangle") then
                if (
                    dx * cos + dy * sin >= -w / 2 + 8 and dx * cos + dy * sin <= w / 2 - 8 and
                    dy * cos - dx * sin >= -h / 2 + 8 and dy * cos - dx * sin <= h / 2 - 8
                ) then
                    arena.is_containing = true
                else
                    arena.is_containing = false
                end

                if (check_plus_amount() < 1 and check_nearest_arena() == arena) then
                    while ((p.x - arena.x) * math.cos(math.rad(arena.rotation)) + (p.y - arena.y) * math.sin(math.rad(arena.rotation)) < -w / 2 + 8) do
                        cos, sin = math.cos(math.rad(arena.rotation)), math.sin(math.rad(arena.rotation))
                        p:Move(cos, sin)
                    end
                    while ((p.x - arena.x) * math.cos(math.rad(arena.rotation)) + (p.y - arena.y) * math.sin(math.rad(arena.rotation)) > w / 2 - 8) do
                        cos, sin = math.cos(math.rad(arena.rotation)), math.sin(math.rad(arena.rotation))
                        p:Move(-cos, -sin)
                    end
                    while ((p.y - arena.y) * math.cos(math.rad(arena.rotation)) - (p.x - arena.x) * math.sin(math.rad(arena.rotation)) > h / 2 - 8) do
                        cos, sin = math.cos(math.rad(arena.rotation)), math.sin(math.rad(arena.rotation))
                        p:Move(sin, -cos)
                    end
                    while ((p.y - arena.y) * math.cos(math.rad(arena.rotation)) - (p.x - arena.x) * math.sin(math.rad(arena.rotation)) < -h / 2 + 8) do
                        cos, sin = math.cos(math.rad(arena.rotation)), math.sin(math.rad(arena.rotation))
                        p:Move(-sin, cos)
                    end
                end
            end
        else
            if (not arenas.refollow) then
                arena.white:SetStencils(arenas.stencils)
                arena.black:SetStencils(arenas.stencils)
                arenas.refollow = true
            end
            if (shape == "rectangle") then
                local lx = dx * cos + dy * sin
                local ly = dy * cos - dx * sin

                -- Expanded forbidden zone: minus rectangle + 8px on each side (player is 16x16)
                local min_lx, max_lx = -(w + arena.thickness * 2) / 2 - 8, (w + arena.thickness * 2) / 2 + 8
                local min_ly, max_ly = -(h + arena.thickness * 2) / 2 - 8, (h + arena.thickness * 2) / 2 + 8

                -- Check if the player's centre is inside the forbidden zone
                if (lx >= min_lx and lx <= max_lx and ly >= min_ly and ly <= max_ly) then
                    -- Distance to each edge of the expanded rectangle
                    local d_left   = lx - min_lx
                    local d_right  = max_lx - lx
                    local d_bottom = ly - min_ly
                    local d_top    = max_ly - ly

                    local min_dist = math.min(d_left, d_right, d_bottom, d_top)

                    -- Snap lx/ly past the nearest edge (+1px) so the boundary check
                    -- on the next frame does not re-detect the player as inside
                    if (min_dist == d_left)   then lx = min_lx - 1
                    elseif (min_dist == d_right)  then lx = max_lx + 1
                    elseif (min_dist == d_bottom) then ly = min_ly - 1
                    else                              ly = max_ly + 1
                    end

                    -- Convert local coordinates back to world space and move the player
                    p.x = arena.x + lx * cos - ly * sin
                    p.y = arena.y + lx * sin + ly * cos

                    -- If after being pushed out the player is outside the valid playable area,
                    -- circular-diffusion search for the nearest valid landing spot
                    if (not is_point_valid(p.x, p.y)) then
                        local nx, ny = find_nearest_valid(p.x, p.y)
                        p.x, p.y = nx, ny
                    end
                end
            end
        end
    end
end

function arenas.Clear()
    for i = #arenas.insts, 1, -1 do
        local a = arenas.insts[i]
        if (i ~= 1) then
            a:Destroy()
        end
    end
end

return arenas