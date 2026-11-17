-- sans animation.
-- Contract: Game/Animations/_temp.lua (plain table factory, dot calls at the
-- call site, functions bound by Battle.BindAnimation).
--
-- Three sprites for the battle body, repositioned every frame: torso (follows
-- yoff / 1.5), head (follows yoff + headx / heady), legs (static, pinned under
-- the torso except for the hurt knock-back). `self.cpos` is the HEAD CENTRE, so
-- `Game:InitAnimation(i, {320, 140})` puts the skull at (320, 140).
-- Ported from a 30 FPS room: every counter advances by `dt * SOURCE_FPS`.
-- bounce 0 = still, 1 = idle 8-shape, 2 = medium bob, 3 = tired bob.

local Sans = {}

local SOURCE_FPS = 30

local BODY_DIR = "Characters/Sans/"
local FACE_DIR = BODY_DIR .. "Face/"

-- Screen pixels at scale 2; TORSO_OFFSET_Y is the original `y + 42`.
local TORSO_OFFSET_Y = 42
-- LEG_GAP: 0 = legs touch the torso bottom, negative tucks, positive leaves a gap.
local LEG_GAP = 0
local TORSO_BOB_DAMP = 1.5

-- Idle torso cycle: spr_sansb_torso_0 .. 7.
local TORSO_FRAMES = 8
local TORSO_INTERVAL = 0.10

local HEAD_FRAMES = 11 -- spr_sans_bface_0 .. 10
local SWEAT_FRAMES = 3 -- spr_sansb_face_sweat_0 .. 2 (NOT in Resources yet)
local EYE_FRAMES = 2   -- spr_sansb_blueeye_0 .. 1

--- Build the list of "path_0.png" .. "path_<count-1>.png" for a sheet.
local function frameList(dir, prefix, count)
    local list = {}
    for i = 0, count - 1 do
        list[i + 1] = string.format("%s%s_%d.png", dir, prefix, i)
    end
    return list
end

--- Height of a sprite as it is actually drawn (scale 2 here).
local function drawnHeight(sprite)
    if (not sprite) then return 0 end
    return (sprite.height or 0) * (sprite.yscale or 1)
end

function Sans.New(pos)
    local self = {}

    -- Back-reference to this module's function table. Do not rename it.
    self._class = Sans

    self.running = true
    self.elements = {}

    self.hurting = false
    self.intensity = 16

    self.bounce = 1       -- idle 8-shape by default
    self.bounce_scale = 1 -- multiplies the sway amplitude
    self.siner = 0
    self.xoff = 0         -- last sway (read-only, for other code)
    self.yoff = 0         -- last bob (read-only, for other code)

    self.headx = 0
    self.heady = 0
    -- true: headx / heady ease back to 0 on their own.
    self.head_auto_return = true
    self.head_return_speed = 6

    self.faceemotion = 0 -- spr_sans_bface_<n>.png, 0..10
    self.facetype = 0    -- 0 = normal, 1 = blue eye
    self.f_i = 0         -- blue-eye frame timer
    self.sweat = 0       -- 0 = none, 1..3

    self.movearm = 1 -- 0 = torso idle cycle runs, ~= 0 pauses it

    self.torsoframe = 0
    self.torso_time = 0

    -- Cached frame paths, so no string concatenation happens per frame.
    self.head_frames = frameList(FACE_DIR, "spr_sans_bface", HEAD_FRAMES)
    self.torso_frames = frameList(BODY_DIR, "spr_sansb_torso", TORSO_FRAMES)
    self.sweat_frames = frameList(FACE_DIR, "spr_sansb_face_sweat", SWEAT_FRAMES)
    self.eye_frames = frameList(FACE_DIR, "spr_sansb_blueeye", EYE_FRAMES)

    -- Last applied frames, so Set() is only called when something changed.
    self._last_face = 0
    self._last_eye = -1
    self._last_sweat = -1

    Sans.Init(self, pos)

    Battle.BindAnimation(self, Sans)

    return self
end

function Sans.Init(self, pos)
    local _pos = (pos or {320, 140})

    local legs = Sprites.CreateSprite(BODY_DIR .. "spr_sansb_legs_0.png", "UI")
    local body = Sprites.CreateSprite(self.torso_frames[1], "UI")
    local head = Sprites.CreateSprite(self.head_frames[1], "UI")
    legs:Scale(2, 2)
    body:Scale(2, 2)
    head:Scale(2, 2)

    -- Same-layer sprites draw in `_id` order: legs → torso → head stacks correctly.
    self.legs = legs
    self.body = body
    self.head = head

    -- Offsets come from the real sprite heights, so another sheet stays aligned.
    self.torso_dy = TORSO_OFFSET_Y
    self.legs_dy = TORSO_OFFSET_Y
        + drawnHeight(body) * 0.5 -- bottom edge of the torso
        + drawnHeight(legs) * 0.5  -- centre of the legs
        + LEG_GAP

    self.cpos = {_pos[1], _pos[2]}

    -- Place once so nothing flashes at (0, 0) before the first Update().
    Sans.ApplyOffsets(self, 0, 0, 0)
end

--- Every sprite this instance currently owns (body parts + live overlays).
function Sans.AllSprites(self)
    local list = {}
    if (self.legs) then table.insert(list, self.legs) end
    if (self.body) then table.insert(list, self.body) end
    if (self.head) then table.insert(list, self.head) end
    if (self.blueeye) then table.insert(list, self.blueeye) end
    if (self.sweat_sprite) then table.insert(list, self.sweat_sprite) end
    return list
end

--- Lazily build a head overlay (blue eye / sweat) and put it right on top of
--- the head. Returns nil (once) when the image is missing from Resources.
function Sans.CreateOverlay(self, path, z_offset)
    local sprite = Sprites.CreateSprite(path, "UI")
    if (not sprite or not sprite.image or sprite._loaded == false) then
        -- Missing image → the engine hands back a 1x1 placeholder; drop it.
        if (sprite and sprite.Destroy) then
            sprite:Destroy()
        end
        return nil
    end

    sprite:Scale(2, 2)
    -- `_id` sets draw order within a layer; a small offset keeps overlays on top.
    sprite._id = (self.head._id or 0) + (z_offset or 0.1)
    Layers.mark_dirty()
    return sprite
end

--- The blue-eye overlay (created on first use).
function Sans.EnsureBlueEye(self)
    if (not self.blueeye and not self._no_blueeye) then
        self.blueeye = Sans.CreateOverlay(self, self.eye_frames[1], 0.2)
        if (self.blueeye) then
            self.blueeye.visible = false
        else
            self._no_blueeye = true
        end
    end
    return self.blueeye
end

--- The sweat overlay (created on first use). Needs spr_sansb_face_sweat_*.png in
--- Resources/Sprites/Characters/Sans/Face; without it the overlay stays nil.
function Sans.EnsureSweat(self)
    if (not self.sweat_sprite and not self._no_sweat) then
        self.sweat_sprite = Sans.CreateOverlay(self, self.sweat_frames[1], 0.3)
        if (self.sweat_sprite) then
            self.sweat_sprite.visible = false
        else
            self._no_sweat = true
        end
    end
    return self.sweat_sprite
end

--- Bounce mode: 0 = still, 1 = idle 8-shape, 2 = medium bob, 3 = tired bob.
function Sans.SetBounce(self, mode)
    self.bounce = math.floor(mode or 0)
end

--- Head expression (0..10 → spr_sans_bface_<n>.png).
function Sans.SetFace(self, index)
    self.faceemotion = math.max(0, math.min(HEAD_FRAMES - 1, math.floor(index or 0)))
end

--- 0 = normal face, 1 = blue eye.
function Sans.SetFaceType(self, t)
    self.facetype = math.floor(t or 0)
    self.f_i = 0
    self._blueeye_flash = false
end

--- Sweat drops: 0 = none, 1..3 (needs the missing spr_sansb_face_sweat_*.png).
function Sans.SetSweat(self, level)
    self.sweat = math.max(0, math.min(SWEAT_FRAMES, math.floor(level or 0)))
end

--- Show the blue eye for `duration` seconds, then go back to the normal face.
function Sans.FlashBlueEye(self, duration)
    self.facetype = 1
    self.f_i = 0
    self._blueeye_flash = true
    self._blueeye_timer = duration or 1
end

--- Offset the head (attack lean). With `head_auto_return` on (the default) the
--- offset smoothly returns to 0; set `self.head_auto_return = false` to hold it.
function Sans.SetHeadOffset(self, hx, hy)
    self.headx = hx or 0
    self.heady = hy or 0
end

--- Move the three parts (and overlays) to the current offsets.
---@param xoff    number Horizontal sway, already scaled (legs ignore it).
---@param yoff    number Vertical bob, already scaled (legs ignore it).
---@param shake_x number Hurt knock-back.
function Sans.ApplyOffsets(self, xoff, yoff, shake_x)
    local shake = shake_x or 0
    local ax = self.cpos[1] + xoff + shake
    local ay = self.cpos[2]

    local bob = yoff / TORSO_BOB_DAMP

    -- Legs are static (ignore xoff / yoff) but follow the hurt knock-back.
    self.legs:MoveTo(self.cpos[1] + shake, ay + self.legs_dy)

    self.body:MoveTo(ax, ay + self.torso_dy + bob)
    self.head:MoveTo(ax + self.headx, ay + yoff + self.heady)

    if (self.blueeye) then
        self.blueeye:MoveTo(ax + self.headx, ay + yoff + self.heady)
    end
    if (self.sweat_sprite) then
        self.sweat_sprite:MoveTo(ax + self.headx, ay + yoff + self.heady)
    end
end

--- Face, blue eye and sweat overlays.
---@param step number A "30 FPS frame tick" (dt * SOURCE_FPS).
function Sans.UpdateFace(self, step)
    local face = math.max(0, math.min(HEAD_FRAMES - 1, math.floor(self.faceemotion or 0)))
    if (face ~= self._last_face) then
        self._last_face = face
        self.head:Set(self.head_frames[face + 1])
    end

    if ((self.facetype or 0) == 1) then
        self.f_i = self.f_i + step
        local eye = Sans.EnsureBlueEye(self)
        if (eye) then
            local frame = math.floor(self.f_i / 2) % EYE_FRAMES
            eye.visible = true
            if (frame ~= self._last_eye) then
                self._last_eye = frame
                eye:Set(self.eye_frames[frame + 1])
            end
        end
    elseif (self.blueeye) then
        self.blueeye.visible = false
        self.f_i = 0
        self._last_eye = -1
    end

    local sweat = Sans.EnsureSweat(self)
    if (sweat) then
        local level = math.max(0, math.min(SWEAT_FRAMES, math.floor(self.sweat or 0)))
        if (level > 0) then
            sweat.visible = true
            if ((level - 1) ~= self._last_sweat) then
                self._last_sweat = level - 1
                sweat:Set(self.sweat_frames[level])
            end
        else
            sweat.visible = false
        end
    end
end

function Sans.Hurt(self)
    self.intensity = 0
end

--- OPTIONAL: called when an attack is launched at this enemy, before the hit lands.
--- `data` fields: enemy, damage, perfect, offset, position, attack (see _temp.lua).
function Sans.OnAttack(self, data)
    local ty = 220
    Tween.CreateTween(function (v)
        self.cpos[1] = v
    end, "Quad", "Out", 320, ty, 40)
    Tween.CreateTween(function (v)
        self.cpos[1] = v
    end, "Quad", "Out", ty, 320, 35, 80)
end

function Sans.Spare(self)
    for _, sprite in ipairs(Sans.AllSprites(self)) do
        sprite.alpha = 0.5
    end
end

function Sans.Update(self, dt)
    if (not self.running) then
        return
    end

    if (not self.legs or not self.body or not self.head or not self.cpos) then
        return
    end

    -- One 30 FPS "frame tick": every ported counter advances by this much.
    local step = dt * SOURCE_FPS

    -- Sway / bounce.
    local xoff, yoff = 0, 0
    local bounce = math.floor(self.bounce or 0)

    if (bounce == 3) then
        self.siner = self.siner + step
        yoff = math.sin(self.siner / 18) * 2
    elseif (bounce == 2) then
        self.siner = self.siner + step
        yoff = math.sin(self.siner / 15) * 4
    elseif (bounce == 1) then
        self.siner = self.siner + step
        yoff = math.sin(self.siner / 3)
        xoff = math.cos(self.siner / 6)
    else
        self.siner = 0
    end

    local scale = self.bounce_scale or 1
    xoff = xoff * scale
    yoff = yoff * scale
    self.xoff = xoff
    self.yoff = yoff

    -- Hurt shake.
    local shake_x = 0
    if (self.hurting) then
        shake_x = self.intensity
        if (self.intensity > 0) then
            self.intensity = -(self.intensity - step)
        else
            self.intensity = -self.intensity
        end

        if (math.abs(self.intensity) <= step) then
            self.intensity = 0
            self.hurting = false
        end
    end

    -- Head offsets (attack poses).
    if (self.head_auto_return) then
        local k = math.min(1, (self.head_return_speed or 6) * dt)
        self.headx = self.headx - self.headx * k
        self.heady = self.heady - self.heady * k
        if (math.abs(self.headx) < 0.05) then self.headx = 0 end
        if (math.abs(self.heady) < 0.05) then self.heady = 0 end
    end

    -- Blue-eye auto-off (only for FlashBlueEye).
    if (self._blueeye_timer) then
        self._blueeye_timer = self._blueeye_timer - dt
        if (self._blueeye_timer <= 0) then
            self._blueeye_timer = nil
            if (self._blueeye_flash) then
                self._blueeye_flash = false
                self.facetype = 0
                self.f_i = 0
            end
        end
    end

    -- Torso idle cycle; movearm ~= 0 (arm pose playing) pauses it.
    if (math.floor(self.movearm or 0) == 0) then
        self.torso_time = self.torso_time + dt
        if (self.torso_time >= TORSO_INTERVAL) then
            self.torso_time = self.torso_time - TORSO_INTERVAL
            self.torsoframe = (self.torsoframe + 1) % TORSO_FRAMES
            self.body:Set(self.torso_frames[self.torsoframe + 1])
        end
    end

    -- Face / blue eye / sweat.
    Sans.UpdateFace(self, step)

    -- Place every part.
    Sans.ApplyOffsets(self, xoff, yoff, shake_x)

    -- self.dead is set by Battle.Update at HP 0 + killable. No death sheet yet,
    -- so freeze the sway and let Destroy() dust the body.
    if (self.dead) then
        self.bounce = 0
    end
end

function Sans.Destroy(self)
    self.running = false

    if (not self.legs and not self.body and not self.head) then
        return
    end

    -- `sound` is true for the first part only: one dust sound, not three.
    local sound = true
    for _, sprite in ipairs({self.legs, self.body, self.head}) do
        if (sprite) then
            sprite:Dust(sound, true)
            sound = false
        end
    end

    for _, sprite in ipairs({self.blueeye, self.sweat_sprite}) do
        if (sprite) then
            sprite:Dust(false, true)
        end
    end

    self.legs = nil
    self.body = nil
    self.head = nil
    self.blueeye = nil
    self.sweat_sprite = nil

    for i = #self.elements, 1, -1
    do
        local e = self.elements[i]
        if (e and e.Destroy) then
            e:Destroy()
        end
    end
    self.elements = {}
end

return Sans
