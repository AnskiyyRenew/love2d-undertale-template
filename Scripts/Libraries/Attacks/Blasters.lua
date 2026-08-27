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
        sounds_path = "Blaster",
        _active = true,
        _can_move = true,
        _default_fire = true,

        beams = {},
        time = 0,
        HurtMode = "normal",
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

    Audio.PlaySound("Blaster/snd_intro.wav")

    function blaster:Beam(angle)
        local beam = Sprites.CreateSprite("Blaster/" .. blaster._path .. "/beam.png", sprite.layer - 0.01)
        beam.relative_angle = angle
        beam.rotation = blaster.image.rotation + angle - 90
        beam:MoveTo(blaster.image.x, blaster.image.y)
        beam.xpivot = 1
        beam:Scale(3, 2)
        beam.isBullet = true
        table.insert(blaster.beams, beam)
    end

    function blaster:Destroy()
        for k, v in ipairs(blasters.insts)
        do
            if (v == blaster) then
                for i = #v.beams, 1, -1
                do
                    local b = v.beams[i]
                    b:Destroy()
                end

                v.image:Destroy()
                v = nil
                table.remove(blasters.insts, k)
            end
        end
    end

    table.insert(blasters.insts, blaster)
    return blaster
end

function blasters.NewTween(pos_tween, angles_tween, move_time, fire_time, gb_sprites, gb_sounds)
    local blaster = {
        _path = "Default",
        sounds_path = "Blaster",
        _active = true,
        _can_move = true,
        _default_fire = true,

        beams = {},
        time = 0,
        HurtMode = "normal",
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

    Audio.PlaySound(blaster.sounds_path .. "/snd_intro.wav")

    function blaster:Beam(angle)
        local beam = Sprites.CreateSprite("Blaster/" .. blaster._path .. "/beam.png", sprite.layer - 0.01)
        beam.relative_angle = angle
        beam.rotation = blaster.image.rotation + angle - 90
        beam:MoveTo(blaster.image.x, blaster.image.y)
        beam.xpivot = 1
        beam:Scale(3, 2)
        beam.isBullet = true
        table.insert(blaster.beams, beam)
    end

    function blaster:Destroy()
        for i = #blasters.insts, 1, -1
        do
            local b = blasters.insts[i]
            if (b == blaster) then
                b.image:Destroy()
                table.remove(blasters.insts, i)
            end
        end
    end

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
            if (time <= wait) then
                img:MoveTo(
                    img.x + (finalp[1] - img.x) / 8,
                    img.y + (finalp[2] - img.y) / 8
                )
                img.rotation = img.rotation + (finala - img.rotation) / 8
            end
            if (time == wait - 12) then
                b.image:SetAnimation({
                    "Blaster/" .. b._path .. "/spr_gasterblaster_1.png",
                    "Blaster/" .. b._path .. "/spr_gasterblaster_2.png",
                    "Blaster/" .. b._path .. "/spr_gasterblaster_3.png",
                    "Blaster/" .. b._path .. "/spr_gasterblaster_4.png"
                }, 3 / 60)
            elseif (time == wait) then
                b.image:SetAnimation({
                    "Blaster/" .. b._path .. "/spr_gasterblaster_5.png",
                    "Blaster/" .. b._path .. "/spr_gasterblaster_4.png",
                }, 2 / 60)

                if (b._default_fire) then
                    b:Beam(0)
                    Audio.PlaySound(b.sounds_path .. "/snd_fire.wav")
                end
            end
            if (time >= wait) then
                b.fire_time = b.fire_time - 1

                if (b._can_move) then
                    b.image:Move(
                        (time - b.wait_time) * math.sin(math.rad(b.image.rotation)),
                        (time - b.wait_time) * -math.cos(math.rad(b.image.rotation))
                    )
                end
                if (b.image.x < -160 or b.image.x > 800 or b.image.y < -160 or b.image.y > 640) then
                    b._can_move = false
                end

                if (b.fire_time < 0 and #b.beams == 0) then
                    b:Destroy()
                end
            end

            for j = #b.beams, 1, -1
            do
                local b_ = b.beams[j]
                if (b_) then
                    b_.rotation = b.image.rotation - 90 + b_.relative_angle
                    b_.color = b.image.color
                    b_['HurtMode'] = b['HurtMode']
                    b_:MoveTo(b.image.x, b.image.y)

                    if (b.fire_time >= 0) then
                        b_.yscale = b.image.xscale + 0.25 + 1 * math.sin(b.fire_time / 4) / 5
                    else
                        b_['HurtMode'] = "safe"
                        b_.isBullet = false
                        b_.alpha = b_.alpha - 0.05
                        b_.yscale = b_.yscale + (0 - b_.yscale) / 8
                        if (b_.alpha <= 0) then
                            print("a")
                            b_:Destroy()
                            table.remove(b.beams, j)
                        end
                    end
                end
            end
        end
    end
end

return blasters