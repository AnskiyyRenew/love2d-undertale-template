local path = (...):match("(.-)[^%.]+$")

---Shallow copy of a soul module table, so each new soul gets its own instance.
---@param soul table The original soul module to copy
---@return table A new table with the same fields as the original
local function copy_soul(soul)
    local new = {}
    for k, v in pairs(soul) do
        new[k] = v
    end
    return new
end

local SOUL_ROOTS = {"Game.Souls.", path .. "Player.Souls."}

--- Describe a module name as a project-relative file path, for filesystem probes.
---@param module_name string e.g. "Game.Souls.red"
---@return string e.g. "Game/Souls/red.lua"
local function soulModulePathOf(module_name)
    return (module_name:gsub("%.", "/")) .. ".lua"
end

--- Test whether a module's file actually exists on disk.
--- LÖVE 11 returns a table from getInfo, LÖVE 12 the info directly.
---@param module_name string
---@return boolean
local function soulModuleExists(module_name)
    local file_path = soulModulePathOf(module_name)

    local ok, info = pcall(function()
        return SE.filesystem.getInfo and SE.filesystem.getInfo(file_path)
    end)
    if (ok and info) then return true end

    local readable, content = pcall(love.filesystem.read, file_path, 1)
    return (readable and content ~= nil)
end

--- The soul resolved by the last requireSoul() call.
---
--- Player.action IS the soul module table, so state a soul writes on itself
--- survives in package.loaded and would leak into the next battle. The old
--- module is dropped before a new one loads, like SceneManager does.
---@type string|nil
local current_soul_id = nil

--- Drop a soul module from package.loaded so the next require re-executes it.
--- Both roots are cleared: the file may live in either one.
---@param id string|nil Soul name; nil and "" are no-ops.
local function unloadSoulModule(id)
    if (not id) or (id == "") then return end
    for _, root in ipairs(SOUL_ROOTS) do
        package.loaded[root .. id] = nil
    end
end

--- Require a soul module, Game area first.
---
--- A broken Game copy is always reported, even when the engine copy then loads:
--- the override is broken and the author needs to know. Both the previous and
--- the incoming module are unloaded first, so every call gets a fresh table.
---@param id string Soul name (e.g. "red", "orange", "blue").
---@return table The soul module.
local function requireSoul(id)
    if (not id) or (id == "") then
        error("[Player] Invalid soul name.", 0)
    end

    unloadSoulModule(current_soul_id)
    unloadSoulModule(id)
    current_soul_id = id

    local found_module = nil
    local first_error = nil
    local first_error_module = nil

    for _, root in ipairs(SOUL_ROOTS) do
        local module_name = root .. id

        if (soulModuleExists(module_name)) then
            found_module = found_module or module_name

            local ok, loaded = pcall(require, module_name)
            if (ok and loaded) then
                if (first_error) then
                    print("[Player] WARNING: '" .. tostring(first_error_module) ..
                        "' exists but failed to load; using " .. module_name .. " instead.")
                    print("[Player]   " .. tostring(first_error))
                elseif (root ~= SOUL_ROOTS[1]) then
                    print("[Player] WARNING: soul '" .. id .. "' not found in " ..
                        SOUL_ROOTS[1] .. " (fell back to " .. module_name .. ").")
                end
                return loaded
            end

            if (not first_error) then
                first_error = loaded
                first_error_module = module_name
            end
        end
    end

    if (found_module) then
        error(first_error, 0)
    end

    error("[Player] soul '" .. tostring(id) .. "' not found (looked in " ..
        SOUL_ROOTS[1] .. ", " .. SOUL_ROOTS[2] .. ").", 0)
end

---Hand a freshly loaded soul module its sprite and let it initialise itself.
---The contract lives in Souls/_temp.lua; a soul without Init() still runs, with
---`sprite` / `can_move` bound here instead.
---@param module table The soul module that was just required.
---@param sprite table The sprite this soul drives.
---@param can_move boolean Mirrors Player.canMove at switch time.
---@param args table|nil Extra arguments from SetSoul / NewSoul.
---@return table module The same module, for chaining.
local function initSoul(module, sprite, can_move, args)
    if (module.Init) then
        module.Init(sprite, can_move, args)
    else
        print("[Player] WARNING: this soul has no Init(); binding sprite/can_move " ..
            "from the engine side (contract: Souls/_temp.lua).")
        module.sprite = sprite
        module.can_move = (can_move ~= false)
    end
    return module
end

local Player = {
    _spr_default = "Soul Library Sprites/spr_default_heart.png",
    action = requireSoul("red"),

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
Player.sprite._hitbox = {2, 2}

---Switches the player's soul. The soul sets itself up through its own `Init`
---(sprite, tint, starting state) - see initSoul above.
---@param id string|number Soul name, or the numeric shortcuts 1 / 2 / 6.
---@param args table|nil Forwarded to the soul's Init.
---@param use_sound boolean|nil Play the switch sound.
function Player.SetSoul(id, args, use_sound)
    if (id == nil) then
        print("[WARNING] Invalid soul name.")
        return
    end
    local _id = id

    if (_id == 1) then
        _id = "red"
    elseif (_id == 2) then
        _id = "orange"
    elseif (_id == 6) then
        _id = "blue"
    end

    Player.soul = _id
    Player.action = initSoul(requireSoul(_id), Player.sprite, Player.canMove, args)

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

---Creates a new soul with its own sprite and independent state, driven by the
---same soul module as the main soul.
---@param id string|number The soul identifier (e.g. "red", "orange", or 1 for red)
---@param args table|nil Forwarded to the soul's Init.
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

    local sprite = Sprites.CreateSprite(Player._spr_default, "Player")
    sprite:MoveTo(999, 999)
    sprite.color = {1, 0, 0}
    sprite._hitbox = {4, 4}

    local module = initSoul(requireSoul(_id), sprite, Player.canMove, args)
    local soul = copy_soul(module)

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

---Pick the collision shape of a soul sprite: "ellipse" or "rect" (the default).
---A round soul tested as an ellipse ignores the four empty corners of its box.
---Synonyms work too ("circle" / "oval", "rectangle" / "box").
---@param shape string|nil "ellipse" or "rect"; nil means "rect".
---@param soul table|nil The soul object from Player.NewSoul; nil = main soul.
---@return boolean ok False when `shape` is not a known shape name.
function Player.SetHitboxShape(shape, soul)
    local spr = soul and soul.sprite or Player.sprite
    if (not spr) then return false end
    return spr:SetHitboxShape(shape)
end

---Switch the soul sprite(s) to perfect-pixel collision (see Sprites.SetPPCollision).
---For the 16x16 heart this is a wider hit area than the default 4x4 test box.
---@param enabled boolean
---@return boolean ok Whether a usable tiling was found.
---@return integer count How many collision rectangles it produced.
function Player.SetPerfectPixel(enabled)
    local ok, count = Player.sprite:SetPPCollision(enabled)

    for _, soul in ipairs(Player.souls) do
        if (soul.sprite) then
            soul.sprite:SetPPCollision(enabled)
        end
    end

    return ok, count
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

---Creates a one-way platform. Only a soul that opted in with
---`use_platforms = true` is caught (see Player.UpdatePlatforms), and only when
---its foot crosses the top face from above.
---@param x number|nil X position (default 320).
---@param y number|nil Y position (default 320).
---@param width number|nil Visual width in pixels (default 50).
---@param args table|nil rotation / mode ("move" also carries the player along) /
---  speed {x, y} / color / surface_offset / surface_tolerance (catch band
---  half-thickness) / layer / active / line_color / line_alpha.
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
---@param angle number
    function platform:SetRotation(angle)
        self.rotation = (angle or 0)
        self.image.rotation = self.rotation
        self:Sync()
    end

---Sets the platform's visual width.
---@param w number
    function platform:SetWidth(w)
        self.width = (w or 50)
        self.image.xscale = self.width / self.image.width
        self.height = self.image.height * self.image.yscale
        self:Sync()
    end

    function platform:SetStencils(stencils)
        self.image:SetStencils(stencils)
        self.line:SetStencils(stencils)
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

---One-way platform collision, soul-agnostic: a soul opts in with
---`use_platforms = true` (Player.UpdatePlatforms then calls this every frame),
---or calls it directly from its own Update.
---The foot is probed along the sprite's local "down" before and after this
---frame's movement, and is caught only when it crosses the top face from above.
---@param sprite table  The player sprite.
---@param vertical number The soul's vertical speed (positive = falling).
---@return boolean grounded Whether a platform caught the player this frame.
function Player.BluePlatformCollide(sprite, vertical)
    if (not sprite or not sprite.image) then return false end
    if (#Player.platforms == 0) then return false end
    if ((vertical or 0) < 0) then return false end

    local speed = sprite.speed or {x = 0, y = 0}
    local frame_dx, frame_dy = (speed.x or 0), (speed.y or 0)

    local half_h = math.max(2, ((sprite.height or 16) * (sprite.yscale or 1)) / 2)
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

                local pdx, pdy = prev_fx - last_x, prev_fy - last_y
                local ply = pdy * cos - pdx * sin
                local cdx, cdy = cur_fx - img.x, cur_fy - img.y
                local clx = cdx * cos + cdy * sin
                local cly = cdy * cos - cdx * sin

                local rel = math.rad((sprite.rotation or 0) - (img.rotation or 0))
                local ext_x = half_h * (math.abs(math.cos(rel)) + math.abs(math.sin(rel)))

                local overlaps = (clx + ext_x - 4 > -pw / 2) and (clx - ext_x + 4 < pw / 2)

                local tol = (platform.surface_tolerance or 2)
                local crossed = (ply <= surface + tol) and (cly >= surface - tol)

                if (overlaps and crossed) then
                    local snap = surface - cly
                    sprite:Move(-snap * sin, snap * cos)

                    if (platform.mode == "move") then
                        local carry = (img.x - last_x) * cos + (img.y - last_y) * sin
                        sprite:Move(carry * cos, carry * sin)
                    end

                    return true
                end
            end
        end
    end

    return false
end

local PLATFORM_FIELD = "use_platforms"

---Does the ACTIVE soul want to be caught by the one-way platforms?
---Absent field falls back to the blue soul, so an untouched blue.lua still works.
---@return boolean
local function soulUsesPlatforms()
    local action = Player.action

    if (action and action[PLATFORM_FIELD] ~= nil) then
        return (action[PLATFORM_FIELD] == true)
    end

    return (Player.soul == "blue")
end

---Updates every blue platform (movement + player collision).
---Only a soul that sets `action.use_platforms = true` is caught. Extra souls from
---Player.NewSoul are not driven here; they can call BluePlatformCollide from
---their own Update.
---@param dt number|nil
function Player.UpdatePlatforms(dt)
    local platforms = Player.platforms
    if (#platforms == 0) then
        Player.platform_ground = false
        return
    end

    for _, platform in ipairs(platforms) do
        local img = platform.image
        if (img and img.image and platform.speed) then
            img:Move(platform.speed.x or 0, platform.speed.y or 0)
        end
        if (platform.Sync) then
            platform:Sync()
        end
        if (platform.Step) then
            platform:Step()
        end
    end

    local grounded = false
    local action = Player.action

    if (soulUsesPlatforms() and action and action.GetSpeed) then
        grounded = Player.BluePlatformCollide(Player.sprite, action.GetSpeed())
        if (grounded and action.Land) then
            action.Land()
        end
    end
    Player.platform_ground = grounded

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
                local coll_p = Sprites.GetHitbox(Player.sprite)

                if (Collisions.ShapeWithShape(coll_b, coll_p)) then
                    local pp = Sprites.PPCollide(b, Player.sprite)
                    if (pp == nil or pp == true) then
                        Battle.OnHit(b)
                        break
                    end
                end
            end
        end
    end

    if (Battle.state ~= "DEFENDING") then return end
    if (not Player.canMove) then return end
    Player.action.Update(dt)

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
