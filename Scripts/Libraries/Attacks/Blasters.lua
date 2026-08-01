local blasters = {
    insts = {}
}

local function typeDetector(var, tar_types)
    for _, v in ipairs(tar_types) do
        if type(var) == v then return true end
    end
    return false
end

function blasters.New(start_pos, final_pos, angles, wait_time, fire_time, gb_sprites, gb_sounds)
    local blaster = {
        _path = "Default",
        _active = true,
        _can_move = true,

        time = 0
    }

    local _start = (start_pos or {320, -100})
    if (
        not typeDetector(_start, {"table"})
    ) then
        print("[Attacks - Blasters] The argument 'start_pos' is an invalid value, using '{320, -100}' instead.")
        _start = {320, -100}
    end

    local _final = (final_pos or {320, 240})
    if (
        not typeDetector(_final, {"table"})
    ) then
        print("[Attacks - Blasters] The argument 'final_pos' is an invalid value, using '{320, 240}' instead.")
        _final = {320, 240}
    end

    local _angles = (angles or {180, 0})
    if (
        not typeDetector(_angles, {"table"})
    ) then
        print("[Attacks - Blasters] The argument 'angles' is an invalid value, using '{180, 0}' instead.")
        _angles = {180, 0}
    end

    local _wait = (wait_time or 40)
    if (
        not typeDetector(_wait, {"number"})
    ) then
        print("[Attacks - Blasters] The argument 'wait_time' is an invalid value, using '40' instead.")
        _wait = 40
    end

    local _fire = (fire_time or 20)
    if (
        not typeDetector(_fire, {"number"})
    ) then
        print("[Attacks - Blasters] The argument 'fire_time' is an invalid value, using '20' instead.")
        _fire = 20
    end

    local sprite = Sprites.CreateSprite("Blaster/" .. blaster._path .. "/spr_gasterblaster_0.png", "TopAll")
    sprite:Scale(2, 2)
    sprite.rotation = _angles[1]
    sprite:MoveTo(unpack(_start))

    blaster.image = sprite
    blaster.final_pos = _final
    blaster.final_angle = _angles[2]
    blaster.wait_time = _wait
    blaster.fire_time = _fire

    table.insert(blasters.insts, blaster)
    return blaster
end

function blasters.NewTween(pos_tween, angles_tween, move_time, fire_time, gb_sprites, gb_sounds)
    local blaster = {
        _path = "Default",
        _active = true,
        _can_move = true,

        time = 0
    }

    local _pos = (pos_tween or {{320, -100}, {320, 240}, "QuartOut"})
    if (
        not typeDetector(pos_tween, {"table"})
    ) then
        print("[Attacks - Blasters] The argument 'start_pos' is an invalid value, using '{{320, -100}, {320, 240}, QuartOut}' instead.")
        _pos = {{320, -100}, {320, 240}, "QuartOut"}
    end

    local _angles = (angles_tween or {180, 0, "QuartOut"})
    if (
        not typeDetector(_angles, {"table"})
    ) then
        print("[Attacks - Blasters] The argument 'angles' is an invalid value, using '{180, 0, QuartOut}' instead.")
        _angles = {180, 0, "QuartOut"}
    end

    local _wait = (move_time or 30)
    if (
        not typeDetector(_wait, {"number"})
    ) then
        print("[Attacks - Blasters] The argument 'move_time' is an invalid value, using '30' instead.")
        _wait = 30
    end

    local _fire = (fire_time or 20)
    if (
        not typeDetector(_fire, {"number"})
    ) then
        print("[Attacks - Blasters] The argument 'fire_time' is an invalid value, using '20' instead.")
        _fire = 20
    end

    local sprite = Sprites.CreateSprite("Blaster/" .. blaster._path .. "/spr_gasterblaster_0.png", "TopAll")
    sprite:Scale(2, 2)
    sprite.rotation = _angles[1]
    sprite:MoveTo(unpack(_pos[1]))

    blaster.image = sprite
    blaster.final_pos = _pos[2]
    blaster.final_angle = _angles[2]
    blaster.wait_time = _wait
    blaster.fire_time = _fire

    Tween.CreateTween(function (v) sprite.x = v end, _pos[3], "", sprite.x, _pos[2][1], _wait)
    Tween.CreateTween(function (v) sprite.y = v end, _pos[3], "", sprite.y, _pos[2][2], _wait)
    Tween.CreateTween(function (v) sprite.rotation = v end, _angles[3], "", _angles[1], _angles[2], _wait)

    table.insert(blasters.insts, blaster)
    return blaster
end

function blasters.Update(dt)
    for i = #blasters.insts, 1, -1
    do
        local b = blasters.insts[i]
        if (b._active) then
            b.time = b.time + 1
            local time, img, wait, fire, finalp, finala = b.time, b.image, b.wait_time, b.fire_time, b.final_pos, b.final_angle

            -- Normal blasters.
            if (not b._tweening) then
                if (time <= wait) then
                    img:MoveTo(
                        img.x + (finalp[1] - img.x) / 8,
                        img.y + (finalp[2] - img.y) / 8
                    )
                    img.rotation = img.rotation + (finala - img.rotation) / 8
                end
                if (time == fire - 12) then
                    --
                end
            else

            end
        end
    end
end

return blasters