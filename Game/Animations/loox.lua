-- Loox animation.
-- Contract: Game/Animations/_temp.lua. `require` caches the module, so `New(pos)`
-- is the only way to get an instance; Battle.BindAnimation binds the functions
-- for dot calls (`anim.Foo(...)`).

local Loox = {}

function Loox.New(pos)
    local self = {}

    -- Back-reference to this module's function table. Do not rename it.
    self._class = Loox

    self.running = true
    self.elements = {}
    self.hurting = false
    self.intensity = 16

    Loox.Init(self, pos)

    Battle.BindAnimation(self, Loox)

    return self
end

function Loox.Init(self, pos)
    local _pos = (pos or {320, 180})
    local sprite = Sprites.CreateSprite("Characters/Ruins/spr_loox_0.png", "UI")
    sprite:SetAnimation({
        "Characters/Ruins/spr_loox_0.png",
        "Characters/Ruins/spr_loox_1.png",
        "Characters/Ruins/spr_loox_2.png",
        "Characters/Ruins/spr_loox_1.png",
        "Characters/Ruins/spr_loox_0.png",
        "Characters/Ruins/spr_loox_0.png",
        "Characters/Ruins/spr_loox_0.png",
        "Characters/Ruins/spr_loox_0.png",
        "Characters/Ruins/spr_loox_0.png",
        "Characters/Ruins/spr_loox_0.png",
        "Characters/Ruins/spr_loox_0.png",
        "Characters/Ruins/spr_loox_0.png",
        "Characters/Ruins/spr_loox_0.png",
        "Characters/Ruins/spr_loox_0.png",
    }, 0.08)

    sprite:MoveTo(_pos[1], _pos[2])

    self.sprite = sprite
    self.cpos = {sprite.x, sprite.y}
end

function Loox.Hurt(self)
    self.sprite:Set("Characters/Ruins/spr_looxhurt_0.png")
    self.hurting = true
    self.intensity = 16
end

function Loox.Spare(self)
    self.sprite:Set("Characters/Ruins/spr_looxhurt_0.png")
    self.sprite.alpha = 0.5
end

function Loox.Update(self, dt)
    if (not self.running) then
        return
    end

    -- Default hurt shake: knock the sprite sideways, decaying toward 0.
    if (self.hurting) then
        local p = self.sprite
        p.x = self.cpos[1] + self.intensity
        if (self.intensity > 0) then
            self.intensity = self.intensity - 1
            self.intensity = -self.intensity
        elseif (self.intensity < 0) then
            self.intensity = -self.intensity
        else
            self.hurting = false
        end
    end
end

function Loox.Destroy(self)
    if (not self.sprite) then
        return
    end

    self.sprite:Set("Characters/Ruins/spr_looxhurt_0.png")
    self.sprite:Dust(true, true)
    self.sprite = nil

    for i = #self.elements, 1, -1
    do
        local e = self.elements[i]
        if (e and e.Destroy) then
            e:Destroy()
        end
    end
    self.elements = {}
end

return Loox
