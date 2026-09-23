-- Poseur animation factory.
--
-- STYLE — no metatables, dot notation only.
--   * Every function is declared with a dot and takes the instance as its
--     first argument: `PoseurAnim.Hurt(self)`.
--   * `New(pos)` returns a PLAIN table (no metatable). It carries `_class`,
--     pointing back at this module, so any caller can find the functions from
--     the instance alone:  `anim._class.Hurt(anim)`.
--   * The engine does exactly that — Battle.Update calls
--     `anim._class.Update(anim, dt)`, attack patterns call
--     `anim._class.Hurt(anim)` / `anim._class.OnAttack(anim, data)`, the mercy
--     menu calls `anim._class.Spare(anim)` / `anim._class.Destroy(anim)`.
--   * Sprites are still engine objects → keep the colon there
--     (`sprite:Set(...)`, `sprite:Dust(...)`).
--
-- This module is a FACTORY: `require` returns the module once (Lua caches it
-- in `package.loaded`), so `New(...)` is the only way to get a usable anim.
-- Every enemy gets its OWN instance (own sprite + own state) by calling
-- `New(pos)`, which means two enemies of the same type no longer share a
-- single `anim` table — updating or destroying one can't touch the other.

local PoseurAnim = {}

-- Create a brand-new, independent Poseur animation instance.
function PoseurAnim.New(pos)
    local self = {}

    -- Back-reference to the function table. This is the whole "class" link.
    self._class = PoseurAnim

    self.running = true
    self.x = 0
    self.y = 0
    self.elements = {}

    self.hurting = false
    self.hurttime = 0
    self.intensity = 16

    PoseurAnim.Init(self, pos)
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
    --===================>
    if (self.hurting) then
        local p = self.poseur
        p.x = self.cpos[1] + self.intensity
        if (self.intensity > 0) then self.intensity = self.intensity - 1; self.intensity = -self.intensity
        elseif (self.intensity < 0) then self.intensity = -self.intensity end
    end
    --<===================
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
