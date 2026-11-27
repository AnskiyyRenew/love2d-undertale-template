local blasters = {
    insts = {}
}

local function typeDetector(var, tar_types)
    for _, v in ipairs(tar_types) do
        if type(var) == v then return true end
    end
    return false
end

local BLASTER_SPRITE_FOLDER = "Blaster/"
local BLASTER_SOUND_FOLDER = "Blaster/"

local FLAT_BLASTER_SOUND_FOLDER = "Blaster"

local DEFAULT_SPRITE_FOLDER = "Default"
local DEFAULT_SOUND_FOLDER = "Default"

local SPRITE_ROOTS = { "Game/Resources/Sprites/", "Resources/Sprites/" }
local SOUND_ROOTS = { "Game/Resources/Sounds/", "Resources/Sounds/" }

--- Test whether a file exists on the LÖVE filesystem. LÖVE 11 returns a table
--- from getInfo, LÖVE 12 returns the info directly, so only truthiness is
--- trusted; a one-byte read is the last resort.
---@param path string
---@return boolean
local function fileExists(path)
    if (not path) or (path == "") then return false end

    local ok, info = pcall(function()
        return SE.filesystem.getInfo and SE.filesystem.getInfo(path)
    end)
    if (ok and info) then return true end

    local readable, data = pcall(function()
        return love.filesystem.read(path, 1)
    end)
    return (readable and data ~= nil)
end

--- True when `relative` exists in any of `roots`, probed in order.
---@param roots table
---@param relative string
---@return boolean
local function assetExists(roots, relative)
    for _, root in ipairs(roots) do
        if (fileExists(root .. relative)) then return true end
    end
    return false
end

--- Normalise a folder argument. nil means "use the default folder".
---@param value any
---@param label string Argument name, used when warning about a bad value.
---@return string|nil
local function readFolderArg(value, label)
    if (value == nil) then return nil end

    if (type(value) ~= "string") then
        print("[Attacks - Blasters] The argument '" .. label ..
            "' is an invalid value, using the default folder instead.")
        return nil
    end

    local name = value:gsub("\\", "/")
    name = name:gsub("^/+", ""):gsub("/+$", "")
    if (name == "") then
        print("[Attacks - Blasters] The argument '" .. label ..
            "' is an empty path, using the default folder instead.")
        return nil
    end

    return name
end

--- Resolve the sprite folder for a blaster. A requested folder is only honoured
--- when its head sprite exists; otherwise the default is used and the miss is
--- reported, so a bad path never turns into an invisible blaster.
---@param gb_sprites string|nil Folder inside "Blaster/", e.g. "Default".
---@return string Folder name, used as "Blaster/" .. folder .. "/<file>.png".
local function resolveSpriteFolder(gb_sprites)
    local name = readFolderArg(gb_sprites, "gb_sprites")
    if (not name) then return DEFAULT_SPRITE_FOLDER end

    local relative = BLASTER_SPRITE_FOLDER .. name .. "/spr_gasterblaster_0.png"
    if (assetExists(SPRITE_ROOTS, relative)) then return name end

    print("[Attacks - Blasters] WARNING: blaster sprites '" .. name ..
        "' not found at " .. relative .. ", using '" .. DEFAULT_SPRITE_FOLDER ..
        "' instead.")
    return DEFAULT_SPRITE_FOLDER
end

--- Resolve the sound folder for a blaster. A missing sub-folder falls back to
--- the flat "Blaster/" layout before giving up.
---@param gb_sounds string|nil Folder inside "Blaster/", e.g. "Default".
---@return string Path prefix, used as prefix .. "/snd_intro.wav".
local function resolveSoundFolder(gb_sounds)
    local flat_relative = FLAT_BLASTER_SOUND_FOLDER .. "/snd_intro.wav"
    local flat_hit = assetExists(SOUND_ROOTS, flat_relative)

    local function subFolderOf(folder)
        return BLASTER_SOUND_FOLDER .. folder
    end

    local function subFolderHit(folder)
        return assetExists(SOUND_ROOTS,
            BLASTER_SOUND_FOLDER .. folder .. "/snd_intro.wav")
    end

    local name = readFolderArg(gb_sounds, "gb_sounds")

    if (name) then
        if (subFolderHit(name)) then return subFolderOf(name) end

        if (flat_hit) then
            print("[Attacks - Blasters] WARNING: blaster sounds '" .. name ..
                "' not found at " .. BLASTER_SOUND_FOLDER .. name ..
                "/snd_intro.wav, falling back to the flat '" ..
                FLAT_BLASTER_SOUND_FOLDER .. "' layout.")
            return FLAT_BLASTER_SOUND_FOLDER
        end

        print("[Attacks - Blasters] WARNING: blaster sounds '" .. name ..
            "' not found at " .. BLASTER_SOUND_FOLDER .. name ..
            "/snd_intro.wav, using '" .. DEFAULT_SOUND_FOLDER .. "' instead.")
        name = nil
    end

    if (subFolderHit(DEFAULT_SOUND_FOLDER)) then
        return subFolderOf(DEFAULT_SOUND_FOLDER)
    end

    return FLAT_BLASTER_SOUND_FOLDER
end

--- Named frame windows, keyed by lowercase name; `from` and `to` are resolved per
--- blaster because they depend on `wait_time` and the initial `fire_time`.
--- "Fading" has no upper bound: it ends when the blaster is destroyed, which also
--- covers extra beams and custom alpha.
local PHASES = {
    waiting = {
        from = function (b) return 1 end,
        to = function (b) return b.wait_time end,
    },
    charging = {
        from = function (b) return math.max(1, b.wait_time - 12) end,
        to = function (b) return b.wait_time - 1 end,
    },
    firing = {
        from = function (b) return b.wait_time end,
        to = function (b) return b.wait_time + b.fire_total - 1 end,
    },
    fading = {
        from = function (b) return b.wait_time + b.fire_total end,
        to = function () return math.huge end,
    },
}

local PHASE_NAMES = "'Waiting', 'Charging', 'Firing' or 'Fading'"

--- Looks up a phase name case-insensitively.
---@param name string
---@return table|nil
local function resolvePhase(name)
    if (type(name) ~= "string") then return nil end
    return PHASES[name:lower()]
end

--- Runs the callbacks registered through `OnFrame` and `During`, in registration
--- order. Frame numbers are compared with `>=` / `<=` instead of `==`, so a
--- callback registered for a frame that has already passed still fires once and a
--- range ends on the first update past `to_frame`. Callbacks may register more
--- callbacks or destroy the blaster; the pass stops as soon as it is destroyed.
---@param blaster table
---@param dt number
local function run_schedule(blaster, dt)
    local once = blaster._onces
    if (once) then
        local due = false
        for i = 1, #once do
            if (blaster.time >= once[i].frame) then due = true break end
        end

        if (due) then
            local list, rest = {}, {}
            for i = 1, #once do
                local task = once[i]
                if (blaster.time >= task.frame) then
                    list[#list + 1] = task
                else
                    rest[#rest + 1] = task
                end
            end

            blaster._onces = rest
            for i = 1, #list do
                list[i].fn(blaster, dt)
                if (blaster._destroyed) then return end
            end
        end
    end

    local spans = blaster._spans
    if (spans) then
        for i = 1, #spans do
            if (blaster.time > spans[i].to) then
                local keep = {}
                for j = 1, #spans do
                    if (blaster.time <= spans[j].to) then
                        keep[#keep + 1] = spans[j]
                    end
                end
                blaster._spans = keep
                spans = keep
                break
            end
        end

        for i = 1, #spans do
            local task = spans[i]
            if (blaster.time >= task.from) then
                task.fn(blaster, dt)
                if (blaster._destroyed) then return end
            end
        end
    end
end

--- Fires `fn` once, on the frame where `blaster.time` first reaches `frame`.
--- `frame` is a number (counted like `blaster.time`, the first update is 1) or a
--- phase name, which uses the phase's first frame: `"Waiting"` is 1,
--- `"Charging"` is `wait_time - 12`, `"Firing"` is `wait_time` and `"Fading"` is
--- `wait_time + fire_total`.
--- The callback receives `(blaster, dt)`; `blaster.time` is the frame it actually
--- fired on, which is later than `frame` when it was registered after that frame.
---@param self table
---@param frame number|string Frame number or one of the phase names.
---@param fn function Called as `fn(blaster, dt)`.
---@return table|nil blaster Returned for chaining; nil when an argument is invalid.
local function blasterOnFrame(self, frame, fn)
    if (type(frame) == "string") then
        local phase = resolvePhase(frame)
        if (not phase) then
            print("[Attacks - Blasters] OnFrame: unknown phase '" .. frame .. "', expected " .. PHASE_NAMES .. ".")
            return nil
        end

        frame = phase.from(self)
    end

    if (type(frame) ~= "number") then
        print("[Attacks - Blasters] OnFrame: 'frame' must be a number or a phase name, the call is ignored.")
        return nil
    end
    if (type(fn) ~= "function") then
        print("[Attacks - Blasters] OnFrame: 'fn' must be a function, the call is ignored.")
        return nil
    end

    self._onces = self._onces or {}
    self._onces[#self._onces + 1] = {frame = frame, fn = fn}
    return self
end

--- Runs `fn` on every frame from `from_frame` to `to_frame`, both inclusive.
--- Either pass two frame numbers, or a single phase name: `During("Firing", fn)`
--- covers the whole firing window and `During("Fading", fn)` runs until the
--- blaster is destroyed. In the numeric form, omit `to_frame` (or pass
--- `math.huge`) to keep running until destruction. A range that has already ended
--- before the call never runs.
---@param self table
---@param from_frame number|string First frame, or one of the phase names.
---@param to_frame number|function|nil Last frame; in the phase form `fn` sits here.
---@param fn function Called as `fn(blaster, dt)`.
---@return table|nil blaster Returned for chaining; nil when an argument is invalid.
local function blasterDuring(self, from_frame, to_frame, fn)
    if (type(from_frame) == "string") then
        local phase = resolvePhase(from_frame)
        if (not phase) then
            print("[Attacks - Blasters] During: unknown phase '" .. from_frame .. "', expected " .. PHASE_NAMES .. ".")
            return nil
        end

        if (type(to_frame) == "function") then
            fn = to_frame
        end
        if (type(fn) ~= "function") then
            print("[Attacks - Blasters] During: 'fn' must be a function, the call is ignored.")
            return nil
        end

        from_frame, to_frame = phase.from(self), phase.to(self)
    end

    if (type(from_frame) ~= "number") then
        print("[Attacks - Blasters] During: 'from_frame' must be a number or a phase name, the call is ignored.")
        return nil
    end
    if (to_frame ~= nil and type(to_frame) ~= "number") then
        print("[Attacks - Blasters] During: 'to_frame' must be a number or nil, the call is ignored.")
        return nil
    end
    if (type(fn) ~= "function") then
        print("[Attacks - Blasters] During: 'fn' must be a function, the call is ignored.")
        return nil
    end

    local to = (to_frame == nil) and math.huge or to_frame
    if (to < from_frame) then
        print("[Attacks - Blasters] During: 'to_frame' is before 'from_frame', the call is ignored.")
        return nil
    end

    self._spans = self._spans or {}
    self._spans[#self._spans + 1] = {from = from_frame, to = to, fn = fn}
    return self
end

function blasters.New(start_pos, final_pos, angles, wait_time, fire_time, gb_sprites, gb_sounds)
    local blaster = {
        _path = resolveSpriteFolder(gb_sprites),
        sounds_path = resolveSoundFolder(gb_sounds),
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
    blaster.fire_total = _fire

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
        if (blaster._destroyed) then return end
        blaster._destroyed = true

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

    blaster.OnFrame = blasterOnFrame
    blaster.During = blasterDuring

    table.insert(blasters.insts, blaster)
    return blaster
end

function blasters.NewTween(pos_tween, angles_tween, move_time, fire_time, gb_sprites, gb_sounds)
    local blaster = {
        _path = resolveSpriteFolder(gb_sprites),
        sounds_path = resolveSoundFolder(gb_sounds),
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
    blaster.fire_total = _fire

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
        if (blaster._destroyed) then return end
        blaster._destroyed = true

        for i = #blasters.insts, 1, -1
        do
            local b = blasters.insts[i]
            if (b == blaster) then
                for j = #b.beams, 1, -1
                do
                    b.beams[j]:Destroy()
                end

                b.image:Destroy()
                table.remove(blasters.insts, i)
            end
        end
    end

    blaster.OnFrame = blasterOnFrame
    blaster.During = blasterDuring

    table.insert(blasters.insts, blaster)
    return blaster
end

--- Advances every active blaster: approach, sprite animation, auto fire and the
--- beam sync all happen here. Callbacks registered through `OnFrame` and `During`
--- run next, then the blaster's own `Step(dt)`; both see the final state of the
--- shared pass, so they can override position, angle, beams, or destroy it.
---@param dt number Delta time in seconds, forwarded to the callbacks and `Step`.
function blasters.Update(dt)
    for i = #blasters.insts, 1, -1
    do
        local b = blasters.insts[i]
        if (b._active) then
            b.time = b.time + 1
            local time, img, wait, fire, finalp, finala = b.time, b.image, b.wait_time, b.fire_time, b.final_pos, b.final_angle

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
                            b_:Destroy()
                            table.remove(b.beams, j)
                        end
                    end
                end
            end

            if (not b._destroyed) then
                run_schedule(b, dt)

                if (not b._destroyed and b.Step) then
                    b:Step(dt)
                end
            end
        end
    end
end

return blasters
