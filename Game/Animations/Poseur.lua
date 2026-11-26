--- Poseur animation — the monster of the sample encounter.

local PoseurAnim = {}

function PoseurAnim.New(pos)
    local self = {}

    self._class = PoseurAnim

    self.running = true
    self.elements = {}

    self.hurting = false
    self.intensity = 16

    PoseurAnim.Init(self, pos)

    Battle.BindAnimation(self, PoseurAnim)

    return self
end

function PoseurAnim.Init(self, pos)
    local _pos = (pos or {320, 140})
    local poseur = Sprites.CreateSprite("poseur.png", "UI")
    poseur:MoveTo(_pos[1], _pos[2])

    --[[local glow = ImportFile("Glow", "shader")
    glow:send("glow_color", {1, 1, 1})
    glow:send("glow_intensity", 1)
    glow:send("threshold", 0.06)
    glow:send("tex_size", {poseur.width, poseur.height})
    poseur:SetShaders({glow})]]

    self.cpos = {poseur.x, poseur.y}
    self.poseur = poseur
end

function PoseurAnim.Hurt(self)
    if (not self.poseur) then
        return
    end

    self.hurting = true
    self.intensity = 16
end

function PoseurAnim.Spare(self)
    if (not self.poseur) then
        return
    end

    self.poseur.alpha = 0.5
end

function PoseurAnim.Update(self, dt)
    if (not self.running) then
        return
    end

    if (self.hurting) then
        local p = self.poseur
        p.x = self.cpos[1] + self.intensity
        if (self.intensity > 0) then self.intensity = self.intensity - 1; self.intensity = -self.intensity
        elseif (self.intensity < 0) then self.intensity = -self.intensity end
    end
end

function PoseurAnim.Destroy(self)
    if (not self.poseur) then
        return
    end

    local _flag = Global.GetVariable("FLAG_KILLING_COUNTER")
    if (_flag) then
        FLAG[_flag] = FLAG[_flag] + 1
    end

    self.poseur:Dust(true, true)
    for i = #self.elements, 1, -1
    do
        local e = self.elements[i]
        if (e and e.Destroy) then
            e:Destroy()
        end
    end
    self.elements = {}
end

return PoseurAnim
