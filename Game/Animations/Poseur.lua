-- Poseur animation — the monster of the sample encounter.
--
-- Contract and style rules live in Game/Animations/_temp.lua — read that first.
-- Short version: plain table, NO metatable; every function is declared with a
-- dot and takes the instance as its first argument; `New(pos)` returns a plain
-- instance that carries `_class` back to this module and gets these functions
-- bound onto it (Battle.BindAnimation), so the engine, the attack patterns and
-- the mercy menu all write `anim.Foo(...)` on the instance.
-- Everything inside this file calls the module by name (`PoseurAnim.Foo(self, ...)`).
-- Sprites stay colon-style (`sprite:Set(...)`, `sprite:Dust(...)`).
--
-- This module is a FACTORY: `require` returns the module once (Lua caches it in
-- `package.loaded`), so `New(pos)` is the only way to get a usable instance.
-- Every enemy gets its OWN sprite and its own state, which means two enemies of
-- the same type no longer share one table.

local PoseurAnim = {}

-- Create a brand-new, independent Poseur animation instance.
function PoseurAnim.New(pos)
    local self = {}

    -- Back-reference to this module's function table. Do not rename it.
    self._class = PoseurAnim

    self.running = true
    self.elements = {}

    self.hurting = false
    self.intensity = 16

    PoseurAnim.Init(self, pos)

    -- The instance drives itself from here on (`anim.SetFace(3)`) — see
    -- Battle.BindAnimation for the rule.
    Battle.BindAnimation(self, PoseurAnim)

    return self
end

-- Create the sprites.
function PoseurAnim.Init(self, pos)
    local _pos = (pos or {320, 140})
    local poseur = Sprites.CreateSprite("poseur.png", "UI")
    poseur:MoveTo(_pos[1], _pos[2])

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

    -- Put your monster's animation code here.
    if (self.hurting) then
        local p = self.poseur
        p.x = self.cpos[1] + self.intensity
        if (self.intensity > 0) then self.intensity = self.intensity - 1; self.intensity = -self.intensity
        elseif (self.intensity < 0) then self.intensity = -self.intensity end
    end
end

-- Destroy the anim.
-- You can also use `sprite:Dust` function here.
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
