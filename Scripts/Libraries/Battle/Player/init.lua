local path = (...):match("(.-)[^%.]+$")

---Creates a shallow copy of a soul module table so each new soul gets its own instance.
---@param soul table The original soul module to copy
---@return table A new table with the same fields as the original
local function copy_soul(soul)
    local new = {}
    for k, v in pairs(soul) do
        new[k] = v
    end
    return new
end

local Player = {
    _spr_default = "Soul Library Sprites/spr_default_heart.png",
    action = require(path .. "Player.Souls.red"),

    canMove = true,
    souls = {},
    platforms = {},
    platform_ground = false,
    soul = nil,

    hurt_time = 0,
    back_alpha = true,

    name = "Tester",
    lv = 19,
    maxhp = 92,
    hp = 92,
    kr = 0
}

Player.sprite = Sprites.CreateSprite(Player._spr_default, "Player")
Player.sprite:MoveTo(999, 999)
Player.sprite.color = {1, 0, 0}
Player.sprite._hitbox = {4, 4}

function Player.SetSoul(id, args, use_sound)
    if (id == nil) then
        print("[WARNING] Invalid soul name.")
        return
    end
    local _id = id
    local spr = Player.sprite

    if (_id == 1) then
        _id = "red"
        spr.color = {1, 0, 0}
    elseif (_id == 2) then
        _id = "orange"
        spr.color = {1, 0.5, 0}
    elseif (_id == 6) then
        _id = "blue"
        spr.color = {0, 0, 1}
    end
    Player.action = require(path .. "Player.Souls." .. _id)
    Player.action.sprite = Player.sprite
    Player.action.can_move = Player.canMove
    Player.soul = _id
    Player.ClearPlatforms()

    if (use_sound) then
        Audio.PlaySound("snd_ding.wav")
    end
end

function Player.AddParticle()
    local shadow = Sprites.CreateSprite(Player.sprite.path, Player.sprite.layer)
    shadow:MoveTo(Player.sprite:GetPosition())
    shadow.color = Player.sprite.color
    shadow.alpha = Player.sprite.alpha
    shadow.Step = function (self)
        self:MoveTo(Player.sprite:GetPosition())
        self:Scale(
            self.xscale + (2 - self.xscale) / 8,
            self.yscale + (2 - self.yscale) / 8
        )
        self.alpha = self.alpha - 0.05

        if (self.alpha <= 0) then
            self:Destroy()
        end
    end
end

---Creates a new soul with its own sprite and independent update logic.
---Each new soul loads the same soul module as a separate instance,
---so it behaves like the main soul but has its own state and sprite.
---@param id string|number The soul identifier (e.g. "red", "orange", or 1 for red)
---@param args any Optional arguments passed to the soul module
---@param use_sound boolean|nil Whether to play the ding sound
function Player.NewSoul(id, args, use_sound)
    if (id == nil) then
        print("[WARNING] Invalid soul name.")
        return
    end

    local _id = id
    if (_id == 1) then
        _id = "red"
    end

    -- Create a new sprite for this soul
    local sprite = Sprites.CreateSprite(Player._spr_default, "Player")
    sprite:MoveTo(999, 999)
    sprite.color = {1, 0, 0}
    sprite._hitbox = {4, 4}

    -- Load the soul module and create a unique instance for this soul
    local module = require(path .. "Player.Souls." .. _id)
    local soul = copy_soul(module)
    soul.sprite = sprite
    soul.can_move = Player.canMove

    table.insert(Player.souls, soul)

    if (use_sound) then
        Audio.PlaySound("snd_ding.wav")
    end
end

function Player.SetHitBox(width, height, soul)
    local w = (width > 0 and width or 1)
    local h = (height > 0 and height or 1)

    if (not soul) then
        Player.sprite._hitbox = {w, h}
    else
        soul.sprite._hitbox = {w, h}
    end
end

function Player.Heal(amount, use_sound)
    Player.hp = math.min(Player.maxhp, Player.hp + amount)

    if (use_sound) then
        if (amount > 0) then
            Audio.PlaySound("snd_heal.wav")
        else
            Audio.PlaySound("snd_phurt.wav")
        end
    end
end

function Player.Hurt(amount, time, use_sound)
    Player.back_alpha = false
    Player.hp = math.max(0, Player.hp - amount)
    Player.hurt_time = (time or 60)
    Player.sprite.alpha = 0.4

    if (use_sound) then
        if (amount < 0) then
            Audio.PlaySound("snd_heal.wav")
        else
            Audio.PlaySound("snd_phurt.wav")
        end
    end
end

function Player.AddKR(kramount)
    if (not UI.GetKRStarted()) then return end
    if (Player.hp > 1) then
        Player.kr = Player.kr + kramount
        Player.hp = math.max(1, Player.hp - kramount)
    else
        Player.kr = math.max(0, Player.kr - kramount)
    end
end

---Creates a one-way platform for the blue soul.
---The platform only catches the player when its foot crosses the platform's top
---face from above (a classic one-way platform), so the player can still jump up
---through it from below and is never yanked up while standing underneath it.
---@param x number|nil X position (default 320).
---@param y number|nil Y position (default 320).
---@param width number|nil Visual width in pixels (default 50).
---@param args table|nil Optional settings:
---  rotation       (number)        platform angle, default 0
---  mode           (string)        "none" (static) or "move", default "none"
---  speed          ({x = n, y = n}) per-frame movement when mode is "move"
---  color          ({r, g, b})     tint, default {1, 0.3, 1}
---  surface_offset (number)        extra offset from the top edge, default 0
---  surface_tolerance (number)     half-thickness of the catch band, default 2
---  layer          (number|string) sprite layer, default "BelowBullets"
---  active         (boolean)       whether it can catch the player, default true
---  line_color     ({r, g, b})     white highlight line tint, default {1, 1, 1}
---  line_alpha     (number)        highlight line alpha, default 1
---@return table The platform instance.
function Player.BluePlatform(x, y, width, args)
    local args = (args or {})
    local _width = (width or 50)

    local platform = {
        mode = (args.mode or "none"),
        speed = (args.speed or {x = 0, y = 0}),
        rotation = (args.rotation or 0),
        surface_offset = (args.surface_offset or 0),
        surface_tolerance = (args.surface_tolerance or 2),
        active = (args.active ~= false),
        width = _width,
        height = 0,
        line_color = (args.line_color or {1, 1, 1}),
        line_alpha = (args.line_alpha or 1)
    }

    local spr = Sprites.CreateSprite("Soul Library Sprites/platform.png", (args.layer or "BelowBullets"))
    spr.color = (args.color or {1, 0.3, 1})
    spr:MoveTo(x or 320, y or 320)
    spr.xscale = _width / spr.width
    spr.rotation = platform.rotation

    -- White highlight line that always rides a hair above the platform sprite.
    local line = Sprites.CreateSprite("Soul Library Sprites/platformline.png", spr.layer + 0.0001)
    line.color = platform.line_color
    line.alpha = platform.line_alpha
    line.visible = spr.visible
    line.rotation = spr.rotation
    line.xscale = spr.xscale
    line.yscale = spr.yscale
    line._layer_id = spr._layer_id
    line:MoveTo(spr.x, spr.y)
    line:SetStencils(spr._stencils)

    platform.image = spr
    platform.line = line
    platform.height = spr.height * spr.yscale
    platform._last_x = spr.x
    platform._last_y = spr.y
    platform._line_stencils = spr._stencils

    ---Keeps the highlight line glued to the platform sprite.
    function platform:Sync()
        local img, ln = self.image, self.line
        if (not img or not ln) then return end

        ln:MoveTo(img.x, img.y)
        ln.rotation = img.rotation
        ln.xscale = img.xscale
        ln.yscale = img.yscale
        ln.alpha = self.line_alpha
        ln.visible = img.visible
        ln.color = self.line_color
        ln._layer_id = img._layer_id

        local want_layer = img.layer + 0.0001
        if (ln.layer ~= want_layer) then
            ln.layer = want_layer
        end

        if (self._line_stencils ~= img._stencils) then
            ln:SetStencils(img._stencils)
            self._line_stencils = img._stencils
        end
    end

    ---Moves the platform (keeps its sprite and line in sync).
    function platform:MoveTo(nx, ny)
        self.image:MoveTo(nx, ny)
        self:Sync()
    end

    ---Sets the platform's angle.
    function platform:SetRotation(angle)
        self.rotation = (angle or 0)
        self.image.rotation = self.rotation
        self:Sync()
    end

    ---Sets the platform's visual width.
    function platform:SetWidth(w)
        self.width = (w or 50)
        self.image.xscale = self.width / self.image.width
        self.height = self.image.height * self.image.yscale
        self:Sync()
    end

    ---Removes the platform, its sprite and its highlight line from the scene.
    function platform:Destroy()
        if (self.line) then
            self.line:Destroy()
            self.line = nil
        end
        if (self.image) then
            self.image:Destroy()
            self.image = nil
        end
        for i = #Player.platforms, 1, -1 do
            if (Player.platforms[i] == self) then
                table.remove(Player.platforms, i)
                break
            end
        end
        Player.platform_ground = false
    end
    platform.Delete = platform.Destroy

    table.insert(Player.platforms, platform)
    return platform
end

---Removes every blue platform (called when the soul is reset / the wave changes).
function Player.ClearPlatforms()
    for i = #Player.platforms, 1, -1 do
        local platform = Player.platforms[i]
        if (platform.line) then
            platform.line:Destroy()
            platform.line = nil
        end
        if (platform.image) then
            platform.image:Destroy()
            platform.image = nil
        end
        table.remove(Player.platforms, i)
    end
    Player.platform_ground = false
end

---One-way platform collision for the blue soul.
---The player's foot is probed along the sprite's own local "down" (its gravity
---direction) both before and after this frame's movement. A platform catches the
---player only when that foot crosses the platform's top face from above, so the
---player passes through from below and is never snapped up when already under it.
---When caught, the foot is snapped exactly onto the surface.
---@param sprite table  The player sprite.
---@param vertical number The soul's vertical speed (positive = falling).
---@return boolean grounded Whether a platform caught the player this frame.
function Player.BluePlatformCollide(sprite, vertical)
    if (not sprite or not sprite.image) then return false end
    if (#Player.platforms == 0) then return false end
    if ((vertical or 0) < 0) then return false end

    local speed = sprite.speed or {x = 0, y = 0}
    local frame_dx, frame_dy = (speed.x or 0), (speed.y or 0)

    -- The foot sits half the player's (16x16) height below its centre, along the
    -- sprite's local "down".
    local half_h = 8
    local psin = math.sin(math.rad(sprite.rotation or 0))
    local pcos = math.cos(math.rad(sprite.rotation or 0))
    local cur_fx = sprite.x - psin * half_h
    local cur_fy = sprite.y + pcos * half_h
    local prev_fx = cur_fx - frame_dx
    local prev_fy = cur_fy - frame_dy

    for i = #Player.platforms, 1, -1 do
        local platform = Player.platforms[i]
        local img = platform.image

        if (img and img.image and platform.active ~= false) then
            local pw = img.width * (img.xscale or 1)
            local ph = img.height * (img.yscale or 1)

            if (pw > 0 and ph > 0) then
                local cos = math.cos(math.rad(img.rotation or 0))
                local sin = math.sin(math.rad(img.rotation or 0))
                local surface = -ph / 2 + (platform.surface_offset or 0)

                local last_x = (platform._last_x or img.x)
                local last_y = (platform._last_y or img.y)

                -- Foot, current and previous, expressed in platform-local space.
                local pdx, pdy = prev_fx - last_x, prev_fy - last_y
                local ply = pdy * cos - pdx * sin
                local cdx, cdy = cur_fx - img.x, cur_fy - img.y
                local clx = cdx * cos + cdy * sin
                local cly = cdy * cos - cdx * sin

                -- Half-extent of the (possibly rotated) player square on the platform's x axis.
                local rel = math.rad((sprite.rotation or 0) - (img.rotation or 0))
                local ext_x = half_h * (math.abs(math.cos(rel)) + math.abs(math.sin(rel)))

                local overlaps = (clx + ext_x - 8 > -pw / 2) and (clx - ext_x + 8 < pw / 2)

                -- Treat the surface as a thin band instead of an exact line. The
                -- foot is snapped with sin/cos, so on an angled platform it can end
                -- a floating-point hair *below* the surface; with an exact
                -- `ply <= surface` test that state never re-triggers and the player
                -- slowly sinks / slides through. The band keeps resting stable while
                -- still catching fast falls (Slam) via the previous-frame foot.
                local tol = (platform.surface_tolerance or 2)
                local crossed = (ply <= surface + tol) and (cly >= surface - tol)

                if (overlaps and crossed) then
                    -- Snap the foot exactly onto the top face...
                    local snap = surface - cly
                    sprite:Move(-snap * sin, snap * cos)

                    -- ...and ride along if the platform moved sideways this frame.
                    local carry = (img.x - last_x) * cos + (img.y - last_y) * sin
                    sprite:Move(carry * cos, carry * sin)

                    return true
                end
            end
        end
    end

    return false
end

---Updates every blue platform (movement + player collision). Only the blue soul
---is caught; other souls ignore platforms and simply pass through.
---@param dt number|nil
function Player.UpdatePlatforms(dt)
    local platforms = Player.platforms
    if (#platforms == 0) then
        Player.platform_ground = false
        return
    end

    -- Advance moving platforms first (and keep their highlight line glued on), so
    -- the collision below uses their new spot.
    for _, platform in ipairs(platforms) do
        local img = platform.image
        if (img and img.image and platform.mode == "move" and platform.speed) then
            img:Move(platform.speed.x or 0, platform.speed.y or 0)
        end
        if (platform.Sync) then
            platform:Sync()
        end
    end

    local grounded = false
    if (Player.soul == "blue" and Player.action and Player.action.GetSpeed) then
        grounded = Player.BluePlatformCollide(Player.sprite, Player.action.GetSpeed())
        if (grounded and Player.action.Land) then
            Player.action.Land()
        end
    end
    Player.platform_ground = grounded

    -- Remember where the platforms ended up, for next frame's carry / crossing test.
    for _, platform in ipairs(platforms) do
        local img = platform.image
        if (img) then
            platform._last_x = img.x
            platform._last_y = img.y
        end
    end
end

function Player.Update(dt)
    if (Player.hp + Player.kr <= 0) then
        Global.SetVariable("PlayerFinalThings", Player.sprite)
        Scenes.switchTo("scene_gameover")
    end

    if (Player.hurt_time > 0) then
        if (Player.hurt_time % 5 == 0) then
            Player.sprite.alpha = 1 + 0.4 - Player.sprite.alpha
        end
        Player.hurt_time = Player.hurt_time - 1
    else
        if (not Player.back_alpha) then
            Player.sprite.alpha = 1
            Player.back_alpha = true
        end

        for _, b in ipairs(Sprites.images)
        do
            if (b.isBullet) then
                local coll_b = Collisions.FollowShape(b)
                local coll_p = Collisions.FollowShape(Player.sprite)

                coll_p.w, coll_p.h = Player.sprite._hitbox[1], Player.sprite._hitbox[2]

                if (Collisions.RectangleWithRectangle(coll_b, coll_p)) then
                    Battle.OnHit(b)
                    break
                end
            end
        end
    end

    if (Battle.state ~= "DEFENDING") then return end
    if (not Player.canMove) then return end
    Player.action.Update(dt)
    --print(true)

    for i = #Player.souls, 1, -1 do
        local soul = Player.souls[i]
        if (soul and soul.Update) then
            soul.Update(dt)
            soul.sprite.alpha = Player.sprite.alpha
        end
    end

    Player.UpdatePlatforms(dt)
end

return Player