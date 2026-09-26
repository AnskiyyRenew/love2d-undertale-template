-- Dummy animation.
--
-- NOTE: this is NOT the animation of Game/Encounter/dummy.lua — that encounter
-- points at Game/Animations/Poseur.lua. Rename this file to whatever monster it
-- actually belongs to before wiring it up.
--
-- Contract and style rules live in Game/Animations/_temp.lua — read that first.
-- Short version: plain table, NO metatable; every function is declared with a
-- dot and takes the instance as its first argument; `New(pos)` returns a plain
-- instance that carries `_class` back to this module and gets these functions
-- bound onto it (Battle.BindAnimation), so callers write `anim.SetFace(3)`.
-- Everything inside this file calls the module by name (`Dummy.Foo(self, ...)`).
-- Sprites stay colon-style (`sprite:Set(...)`).

local Dummy = {}

function Dummy.New(pos)
    local self = {}

    -- Back-reference to this module's function table. Do not rename it.
    self._class = Dummy

    self.running = true
    self.elements = {}
    self.hurting = false
    self.intensity = 16
    self.time = 0

    Dummy.Init(self, pos)

    -- The instance drives itself from here on (`anim.SetFace(3)`) — see
    -- Battle.BindAnimation for the rule.
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

    -- Idle: reset to frame 0, then blink through the 2-frame sheet at a random
    -- interval.
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

function Dummy.Destroy(self)
    if (not self.sprite) then
        return
    end

    self.sprite:Set(self.hurt_image)
    self.sprite:Dust(true, true)
    self.sprite = nil

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

return Dummy
