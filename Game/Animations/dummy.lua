--- Dummy animation. Not used by Game/Encounter/dummy.lua, which points at Poseur.lua.

local Dummy = {}

function Dummy.New(pos)
    local self = {}

    self._class = Dummy

    self.running = true
    self.elements = {}
    self.hurting = false
    self.intensity = 16
    self.time = 0

    Dummy.Init(self, pos)

    Battle.BindAnimation(self, Dummy)

    return self
end

function Dummy.Init(self, pos)
    local _pos = (pos or {320, 200})
    local sprite = Sprites.CreateSprite("Characters/Ruins/spr_migosp_0.png", "UI")

    sprite:MoveTo(_pos[1], _pos[2])

    self.hurt_image = "Characters/Ruins/spr_migosphurt_0.png"
    self.sprite = sprite
    self.cpos = {sprite.x, sprite.y}
end

function Dummy.Hurt(self)
    self.sprite:Set(self.hurt_image)
    self.hurting = true
    self.intensity = 16
end

function Dummy.Spare(self)
    self.sprite:Set(self.hurt_image)
    self.sprite.alpha = 0.5
end

function Dummy.Update(self, dt)
    if (not self.running) then
        return
    end

    self.time = self.time + 1
    if (self.time == 10) then
        self.sprite:Set("Characters/Ruins/spr_migosp_0.png")
    elseif (self.time >= 30 + math.random(40)) then
        self.sprite:SetAnimation({
            "Characters/Ruins/spr_migosp_0.png",
            "Characters/Ruins/spr_migosp_1.png"
        }, 0.25)
        self.time = 0
    end

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

function Dummy.Destroy(self)
    if (not self.sprite) then
        return
    end

    self.sprite:Set(self.hurt_image)
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

return Dummy
