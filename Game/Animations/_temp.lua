--- Enemy animation template and contract. Real modules (Poseur, loox, sans, ...) point here instead of repeating it.

local MyMonster = {}

function MyMonster.New(pos)
    local self = {}

    self._class = MyMonster

    self.running = true
    self.elements = {}
    self.hurting = false
    self.intensity = 16

    MyMonster.Init(self, pos)

    Battle.BindAnimation(self, MyMonster)

    return self
end

function MyMonster.Init(self, pos)
    local _pos = (pos or {320, 140})
    local sprite = Sprites.CreateSprite("poseur.png", "UI")
    sprite:MoveTo(_pos[1], _pos[2])

    self.sprite = sprite
    self.cpos = {sprite.x, sprite.y}
end

function MyMonster.Hurt(self)
    self.hurting = true
    self.intensity = 16
end

--- OPTIONAL: called when an attack is launched at this enemy, before the hit lands.
--- `data` fields: enemy (this enemy table), damage (planned damage),
--- perfect (true in the perfect zone), offset (distance from it, 0 = perfect),
--- position ({x, y} on screen), attack (the attack pattern instance).
---@param data table
function MyMonster.OnAttack(self, data)
end

function MyMonster.Spare(self)
end

function MyMonster.Update(self, dt)
    if (not self.running) then
        return
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

function MyMonster.Destroy(self)
    if (not self.sprite) then
        return
    end

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

return MyMonster
