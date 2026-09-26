-- sans animation.
--
-- Contract and style rules live in Game/Animations/_temp.lua — read that first.
-- Short version: plain table, NO metatable; every function is declared with a
-- dot and takes the instance as its first argument; `New(pos)` returns a plain
-- instance that carries `_class` back to this module and gets these functions
-- bound onto it (Battle.BindAnimation), so callers write `anim.SetFace(3)`.
-- Everything inside this file calls the module by name (`Sans.SetFace(self, 3)`).
-- Sprites stay colon-style.
--
--  SANS BATTLE BODY
--  The battle sprite is THREE independent sprites (legs + torso + head) that
--  are re-positioned every frame, exactly like the original draw event did with
--  draw_sprite_ext:
--      torso → anchor + offset, following only  yoff / 1.5
--      head  → anchor + yoff (+ headx / heady, used by attack poses)
--      legs  → STATIC: pinned directly under the torso, no sway and no bob
--  `self.cpos` is the anchor and is the HEAD CENTRE (the original code's `y`),
--  so `Game:InitAnimation(i, {320, 140})` puts sans' skull at (320, 140).
--
--  PORTING NOTES (the reference code was written for a 30 FPS room)
--    * `siner += 1` / `f_i += 1` / the hurt-shake decay are per-FRAME counters.
--      Here they advance by `dt * SOURCE_FPS`, so the motion is identical to
--      the original at 30 FPS and stays the same at 60 FPS (or any other rate).
--    * bounce 0 = still, 1 = idle 8-shape, 2 = medium bob, 3 = tired bob.
--    * The original offsets are tiny (max 4 px). `self.bounce_scale` (default
--      1) can multiply xoff / yoff if you want a more obvious bob.
--    * The torso frame came from `global.flag[20]`; here the torso simply
--      cycles through spr_sansb_torso_0..7 while no arm pose is playing.
--
--  STATE YOU CAN DRIVE (all settable at runtime, from waves / ACT handlers)
--    self.bounce        0..3  → Sans.SetBounce(anim, n)
--    self.bounce_scale  number → multiplies the sway amplitude
--    self.faceemotion   0..10 → Sans.SetFace(anim, n)   (spr_sans_bface_<n>.png)
--    self.facetype      0 = normal, 1 = blue eye → Sans.SetFaceType / Sans.FlashBlueEye
--    self.sweat         0 = none, 1..3           → Sans.SetSweat(anim, n)
--    self.movearm       0 = idle torso, ~= 0 pauses the torso cycle (arms TBD)
--    self.headx/heady   extra head offset        → Sans.SetHeadOffset(anim, x, y)
-- ============================================================================

local Sans = {}

-- ---------------------------------------------------------------------------
-- Tunables.
-- ---------------------------------------------------------------------------
-- The reference implementation ran in a 30 FPS room and used per-frame
-- counters. Our battle loop runs at ~60 FPS and hands us `dt`, so every
-- "per-frame" counter below is advanced with `dt * SOURCE_FPS` — the motion
-- then matches the original at any real frame rate.
local SOURCE_FPS = 30

local BODY_DIR = "Characters/Sans/"
local FACE_DIR = BODY_DIR .. "Face/"

-- Anchor offsets in screen pixels (each part is drawn at scale 2).
-- TORSO_OFFSET_Y is the original `y + 42`.
local TORSO_OFFSET_Y = 42
-- The legs never move: they are pinned right below the torso's rest position.
-- 0 = the legs touch the bottom of the torso (negative tucks them under it,
-- positive leaves a gap) — use it to fine-tune the seam.
local LEG_GAP = 0
-- The torso only takes 1/1.5 of the vertical bob (original math).
local TORSO_BOB_DAMP = 1.5

-- Idle torso cycle: spr_sansb_torso_0 .. 7.
local TORSO_FRAMES = 8
local TORSO_INTERVAL = 0.10

-- Frame counts of the other sheets.
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

-- ---------------------------------------------------------------------------
-- Instance
-- ---------------------------------------------------------------------------
function Sans.New(pos)
    local self = {}

    -- Back-reference to this module's function table. Do not rename it.
    self._class = Sans

    self.running = true
    self.elements = {}

    self.hurting = false
    self.intensity = 16

    -- --- sway / bounce ----------------------------------------------------
    self.bounce = 1       -- idle 8-shape by default
    self.bounce_scale = 1 -- 1 keeps the original amplitudes
    self.siner = 0        -- original `siner`
    self.xoff = 0         -- last horizontal sway (read-only, for other code)
    self.yoff = 0         -- last vertical bob (read-only, for other code)

    -- --- head offsets (attack poses) --------------------------------------
    self.headx = 0
    self.heady = 0
    -- When on, headx / heady ease back to 0 on their own (set to false to hold
    -- a pose until you reset it yourself).
    self.head_auto_return = true
    self.head_return_speed = 6

    -- --- face -------------------------------------------------------------
    self.faceemotion = 0 -- spr_sans_bface_<n>.png, 0..10
    self.facetype = 0    -- 0 = normal, 1 = blue eye
    self.f_i = 0         -- original `f_i` (blue-eye frame timer)
    self.sweat = 0       -- 0 = none, 1..3

    -- --- arms -------------------------------------------------------------
    self.movearm = 1 -- 0 = torso idle cycle runs, ~= 0 pauses it

    -- --- torso cycle ------------------------------------------------------
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

    -- The instance drives itself from here on (`anim.SetFace(3)`) — see
    -- Battle.BindAnimation for the rule.
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

    -- Sprites on one layer are drawn in creation order (Layers sorts by `_id`),
    -- so legs → torso → head already stacks correctly from back to front.
    self.legs = legs
    self.body = body
    self.head = head

    -- The torso hangs TORSO_OFFSET_Y below the head; the static legs sit right
    -- under the torso. Both offsets are read from the real sprite heights, so
    -- swapping in another legs / torso sheet keeps the parts lined up.
    self.torso_dy = TORSO_OFFSET_Y
    self.legs_dy = TORSO_OFFSET_Y
        + drawnHeight(body) * 0.5 -- bottom edge of the torso
        + drawnHeight(legs) * 0.5  -- centre of the legs
        + LEG_GAP

    self.cpos = {_pos[1], _pos[2]}

    -- Place everything once so nothing flashes at (0, 0) before the first
    -- Update() call.
    Sans.ApplyOffsets(self, 0, 0, 0)
end

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

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
    -- `_id` drives the draw order inside a layer; an offset right above the
    -- head keeps overlays on top even though they are created later.
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
            -- Remember the miss so we do not retry (and spam warnings) forever.
            self._no_blueeye = true
        end
    end
    return self.blueeye
end

--- The sweat overlay (created on first use).
--- NOTE: spr_sansb_face_sweat_*.png is not in
--- Resources/Sprites/Characters/Sans/Face yet — drop the files in and this
--- starts working with no code change.
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

-- ---------------------------------------------------------------------------
-- Public state setters
-- ---------------------------------------------------------------------------

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

-- ---------------------------------------------------------------------------
-- Positioning (the port of the original draw_sprite_ext calls)
-- ---------------------------------------------------------------------------

--- Move the three parts (and overlays) to the current offsets.
---@param xoff    number Horizontal sway, already scaled (legs ignore it).
---@param yoff    number Vertical bob, already scaled (legs ignore it).
---@param shake_x number Hurt knock-back.
function Sans.ApplyOffsets(self, xoff, yoff, shake_x)
    local shake = shake_x or 0
    local ax = self.cpos[1] + xoff + shake
    local ay = self.cpos[2]

    -- The torso takes only a fraction of the bob (original: yoff / 1.5), the
    -- head takes all of it.
    local bob = yoff / TORSO_BOB_DAMP

    -- The legs are STATIC: they ignore xoff / yoff completely and are simply
    -- pinned under the torso. They do follow a hurt knock-back (`shake`) so the
    -- body never visually breaks apart — drop the `+ shake` here if you want
    -- them to stay put even when hit.
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
    -- --- expression (original: global.faceemotion) -------------------------
    local face = math.max(0, math.min(HEAD_FRAMES - 1, math.floor(self.faceemotion or 0)))
    if (face ~= self._last_face) then
        self._last_face = face
        self.head:Set(self.head_frames[face + 1])
    end

    -- --- blue eye (original: facetype == 1, floor(f_i / 2)) ----------------
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

    -- --- sweat (original: sweat == 1 / 2 / 3) -----------------------------
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

-- ---------------------------------------------------------------------------
-- Contract callbacks
-- ---------------------------------------------------------------------------

function Sans.Hurt(self)
    --self.hurting = true
    self.intensity = 0
end

--- OPTIONAL: called the moment an attack is LAUNCHED at this enemy, before the
--- hit lands. Implement it to react (brace / dodge / telegraph / counter, ...).
--- `data` may contain:
---   data.enemy    → this enemy table
---   data.damage   → planned damage for the hit
---   data.perfect  → true when the timing landed in the perfect zone
---   data.offset   → distance from the perfect zone (0 = perfect)
---   data.position → {x, y} of the enemy on screen
---   data.attack   → the attack pattern instance
function Sans.OnAttack(self, data)
    -- Classic skeleton reaction: the eye lights up and the head nods toward the
    -- arena. A perfect strike keeps the glint on screen a little longer.
    local ty = 220
    Tween.CreateTween(function (v)
        self.cpos[1] = v
    end, "Quad", "Out", 320, ty, 40)
    Tween.CreateTween(function (v)
        self.cpos[1] = v
    end, "Quad", "Out", ty, 320, 35, 80)
end

function Sans.Spare(self)
    -- Spared: sans fades out instead of dying.
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

    -- A "30 FPS frame tick": every counter ported from the original advances by
    -- this much, so the animation speed is frame-rate independent.
    local step = dt * SOURCE_FPS

    -- ====================>
    -- 1) SWAY / BOUNCE ----------------------------------------------------
    -- bounce 0 = still, 1 = idle 8-shape, 2 = medium bob, 3 = tired bob.
    local xoff, yoff = 0, 0
    local bounce = math.floor(self.bounce or 0)

    if (bounce == 3) then
        -- Large, slow vertical breathing (worn-out sans).
        self.siner = self.siner + step
        yoff = math.sin(self.siner / 18) * 2
    elseif (bounce == 2) then
        -- Medium vertical bob.
        self.siner = self.siner + step
        yoff = math.sin(self.siner / 15) * 4
    elseif (bounce == 1) then
        -- Idle: fast vertical + slow horizontal → a small figure 8.
        self.siner = self.siner + step
        yoff = math.sin(self.siner / 3)
        xoff = math.cos(self.siner / 6)
    else
        -- Still.
        self.siner = 0
    end

    local scale = self.bounce_scale or 1
    xoff = xoff * scale
    yoff = yoff * scale
    self.xoff = xoff
    self.yoff = yoff

    -- 2) HURT SHAKE -------------------------------------------------------
    -- Same decay as the reference: flip the sign every tick while the
    -- magnitude shrinks by one unit per tick (0.5 units per frame at 60 FPS).
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

    -- 3) HEAD OFFSETS (attack poses) --------------------------------------
    if (self.head_auto_return) then
        local k = math.min(1, (self.head_return_speed or 6) * dt)
        self.headx = self.headx - self.headx * k
        self.heady = self.heady - self.heady * k
        if (math.abs(self.headx) < 0.05) then self.headx = 0 end
        if (math.abs(self.heady) < 0.05) then self.heady = 0 end
    end

    -- 4) BLUE-EYE AUTO-OFF (only for FlashBlueEye) ------------------------
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

    -- 5) TORSO IDLE CYCLE --------------------------------------------------
    -- The original only drew the plain torso while no arm animation was
    -- playing (`movearm == 0`); the same flag pauses this cycle.
    if (math.floor(self.movearm or 0) == 0) then
        self.torso_time = self.torso_time + dt
        if (self.torso_time >= TORSO_INTERVAL) then
            self.torso_time = self.torso_time - TORSO_INTERVAL
            self.torsoframe = (self.torsoframe + 1) % TORSO_FRAMES
            self.body:Set(self.torso_frames[self.torsoframe + 1])
        end
    end

    -- 6) FACE / BLUE EYE / SWEAT ------------------------------------------
    Sans.UpdateFace(self, step)

    -- 7) PLACE EVERY PART --------------------------------------------------
    Sans.ApplyOffsets(self, xoff, yoff, shake_x)

    -- 8) DEATH -------------------------------------------------------------
    -- `self.dead` is set by Battle.Update once HP hit 0 and the enemy is
    -- killable. sans has no death sheet yet, so we just freeze the idle sway
    -- and let Destroy() play the dust effect. Add your own animation here.
    if (self.dead) then
        self.bounce = 0
    end
    -- <====================
end

function Sans.Destroy(self)
    self.running = false

    if (not self.legs and not self.body and not self.head) then
        return
    end

    -- Dust the three body parts. Only the FIRST existing part plays
    -- snd_dust.wav, so the whole body disappears with ONE sound, not three.
    local sound = true
    for _, sprite in ipairs({self.legs, self.body, self.head}) do
        if (sprite) then
            sprite:Dust(sound, true)
            sound = false
        end
    end

    -- Overlays (blue eye / sweat) fade out silently together with the body.
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

    -- Destroy every extra object registered in `elements`.
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
