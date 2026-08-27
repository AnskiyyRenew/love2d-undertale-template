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
        if (Player.kr == 0) then
            Player.hp = math.max(0, Player.hp - kramount)
        end
        Player.kr = math.max(0, Player.kr - kramount)
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
end

return Player