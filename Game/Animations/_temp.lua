-- Enemy animation template and contract. Real modules (Poseur, loox, sans, ...)
-- point here instead of repeating it.
--
-- Rules:
--   1. Plain table, no metatable. `New(pos)` returns an independent instance that
--      owns all state; the module owns all functions. `New` calls
--      `Battle.BindAnimation(self, MyMonster)`, which binds each function onto
--      the instance, so the instance drives itself and `_class` points back here.
--   2. Dot only at the call site: `anim.Foo(...)`, never `anim:Foo(...)` (a colon
--      call would pass the instance a second time). Inside this file functions
--      keep `self` and call each other as `MyMonster.Foo(self, ...)`.
--   3. Sprites are engine objects: `sprite:Set(...)`, `sprite:Dust(...)`.
--
-- Using it: copy, rename `MyMonster` everywhere, fill the `-- TODO` spots, point
-- an encounter at the module, then instantiate once per enemy with
-- `Game:InitAnimation(i, {x, y})`.
--
-- Callbacks (callers write `anim.Foo(...)`):
--   New(pos), Init(self, pos), Update(self, dt), Hurt(self),
--   OnAttack(self, data) (optional), Spare(self), Destroy(self).
--
-- Engine-provided fields, refreshed every frame:
--   self.enemy (id, name, hp, maxhp, canspare, killable, actions, custom fields),
--   self.canspare, self.killable, self.hp / self.maxhp,
--   self.dead (HP 0 and killable — use it to switch to a death animation).
--
-- IMPORTANT: never store per-monster state (sprites, timers, flags) at module
-- level — put it on `self`, or every enemy of that type shares it.

local MyMonster = {}

function MyMonster.New(pos)
    local self = {}

    -- Back-reference to this module's function table. Do not rename it.
    self._class = MyMonster

    self.running = true
    self.elements = {}
    self.hurting = false
    self.intensity = 16

    MyMonster.Init(self, pos)

    -- Required: binds the module functions for dot calls (`anim.Foo(...)`).
    -- `New` is never bound; calling this twice is a no-op.
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
function MyMonster.OnAttack(self, data)
end

function MyMonster.Spare(self)
end

function MyMonster.Update(self, dt)
    if (not self.running) then
        return
    end

    -- TODO: put your monster's animation code here. For example:
    --   if (self.canspare) then ... end
    --   if (self.dead) then self.sprite:SetAnimation({"death_0.png", ...}, 0.1) end

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
