local arenas = {
    insts = {},
    stencils = {},

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

        x = _x,
        y = _y,
        width = (_width > 16) and _width or 16,
        height = (_height > 16) and _height or 16,
        rotation = _angle,

        is_active = true,
        is_containing = false,

        move_player = false
    }
    local _target = {
        x = _x,
        y = _y,
        width = arena.width,
        height = arena.height,
        rotation = arena.rotation
    }
    arena.target = _target

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

        white:Scale(arena.width + 10, arena.height + 10)
        black:Scale(arena.width, arena.height)

        white:MoveTo(_x, _y)
        black:MoveTo(_x, _y)

        white.rotation = arena.rotation
        black.rotation = arena.rotation

        arena.white = white
        arena.black = black
    elseif (arena.shape == "ellipse" or arena.shape == "circle") then
        local white = Sprites.CreateSprite("Shapes/circle.png", "ArenasExtraW")
        local black = Sprites.CreateSprite("Shapes/circle.png", "ArenasExtraB")
        white.color = Global.GetVariable("MainColor")
        black.color = {0, 0, 0}

        white:Scale(arena.width + 10, arena.height + 10)
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

    table.insert(arenas.insts, arena)
    return arena
end

function arenas.Update(dt)
    local p = Player.sprite

    for _, arena in ipairs(arenas.insts)
    do
        -- Target
        arena.x = smooth_value(arena.x, arena.target.x, 15)
        arena.y = smooth_value(arena.y, arena.target.y, 15)
        arena.width = smooth_value(arena.width, arena.target.width, 15)
        arena.height = smooth_value(arena.height, arena.target.height, 15)

        -- Sprite things
        arena.white:MoveTo(arena.x, arena.y)
        arena.black:MoveTo(arena.x, arena.y)
        arena.black:Scale(arena.width, arena.height)
        arena.white:Scale(arena.width + 10, arena.height + 10)
        arena.white.rotation = arena.rotation
        arena.black.rotation = arena.rotation
        if (arena.mask) then
            arena.mask:Follow(arena.white)
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
                local min_lx, max_lx = -(w + 10) / 2 - 8, (w + 10) / 2 + 8
                local min_ly, max_ly = -(h + 10) / 2 - 8, (h + 10) / 2 + 8

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

return arenas