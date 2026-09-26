--  ENEMY ANIMATION — TEMPLATE AND CONTRACT
--  ============================================================================
--  This file is the ONLY place the animation contract is written down. Every
--  real animation module (Poseur.lua, loox.lua, sans.lua, ...) points here
--  instead of repeating it.
--
--  THE THREE RULES
--    1. Plain table, NO metatable. `New(pos)` returns an independent instance
--       (a plain table) that owns ALL the state; the module owns ALL the
--       functions. `New` then calls `Battle.BindAnimation(self, MyMonster)`,
--       which hangs a thin closure over each function ON the instance — so the
--       instance drives itself, and `_class` still points back at its module.
--    2. DOT ONLY, no `self` at the call site. Everything outside this file —
--       the engine, waves, ACT handlers — writes `anim.Foo(...)`:
--           anim.SetFace(3)     anim.Update(dt)     anim.cpos[1] = 100
--       A colon call (`anim:Foo(...)`) would smuggle the instance in a SECOND
--       time and raises a clear error where it is written: one call form, not two.
--       Inside this file the functions keep the usual `self` parameter
--       (`function MyMonster.Foo(self, ...)`) and call each other by module name
--       (`MyMonster.Foo(self, ...)`), so the state being touched is always
--       visible right next to the code that touches it.
--    3. Sprites are engine objects, so they stay colon-style:
--       `sprite:Set(...)`, `sprite:Dust(...)`.
--
--  HOW TO USE THIS FILE
--    1. Copy it and rename it after your monster, e.g. Game/Animations/Sol.lua
--    2. Rename the module local `MyMonster` below to the SAME name, everywhere
--       in the file. A stale `MyMonster` left behind in a real monster is the
--       single most common way these files become unreadable.
--    3. Replace the placeholders marked with "-- TODO".
--    4. Point an encounter at it:
--       animation = require("Game.Animations.Sol")
--    5. Instantiate once per enemy, from the scene:
--       local anim = Game:InitAnimation(i, {x, y})
--       From here on, drive it with dot calls straight on the instance:
--           anim.SetFace(3)      anim.Update(dt)      anim.cpos[1] = 100
--
--  THE CALLBACKS (module-side signatures; callers write `anim.Foo(...)`)
--    * New(pos)               → creates a brand-new, INDEPENDENT instance.
--    * Init(self, pos)        → builds the sprites (called by New).
--    * Update(self, dt)       → per-frame logic, called by Battle.Update.
--    * Hurt(self)             → hit reaction, called by attack patterns.
--    * OnAttack(self, data)   → (optional) attack-launched signal; see stub.
--    * Spare(self)            → plays the spare reaction (MERCY → Spare).
--    * Destroy(self)          → cleans up sprites, called when the enemy dies.
--
--  ENGINE-PROVIDED FIELDS (refreshed on every instance each frame)
--    * self.enemy    → the enemy table from the encounter (id, name, hp, maxhp,
--                      canspare, killable, actions, and any custom fields).
--    * self.canspare → shortcut for self.enemy.canspare
--    * self.killable → shortcut for self.enemy.killable
--    * self.hp / self.maxhp
--    * self.dead     → true once HP reached 0 AND the enemy is killable.
--                      Use this in Update to switch to a death animation.
--
--  IMPORTANT
--    * Lua's `require` returns this module ONCE (it is cached). Two enemies of
--      the same type would otherwise share ONE table → they would share one
--      sprite. `New(...)` is the ONLY way to get a usable, per-enemy instance.
--    * NEVER store per-monster state (sprites, timers, flags) at module level.
--      Put everything on `self` so each instance owns its own data.
-- ============================================================================

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

    -- Required: binds this module's functions onto the instance, so callers
    -- write `anim.Foo(...)`. `New` itself is never bound, and calling this
    -- twice is a no-op.
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

--- OPTIONAL: called the moment an attack is LAUNCHED at this enemy, before the
--- hit lands. Implement it to react (brace / dodge / telegraph / counter, ...).
--- `data` may contain:
---   data.enemy    → this enemy table
---   data.damage   → planned damage for the hit
---   data.perfect  → true when the timing landed in the perfect zone
---   data.offset   → distance from the perfect zone (0 = perfect)
---   data.position → {x, y} of the enemy on screen
---   data.attack   → the attack pattern instance
function MyMonster.OnAttack(self, data)
end

function MyMonster.Spare(self)
end

function MyMonster.Update(self, dt)
    if (not self.running) then
        return
    end

    -- ====================>
    -- TODO: put your monster's animation code here.
    --
    -- Example: react to engine-provided state
    --   if (self.canspare) then ... end            -- spareable?
    --   if (self.dead) then                        -- HP hit 0 and killable
    --       self.sprite:SetAnimation({"death_0.png", "death_1.png"}, 0.1)
    --   end

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
    -- <====================
end

function MyMonster.Destroy(self)
    if (not self.sprite) then
        return
    end

    -- TODO: play a death effect here, e.g. sprite:Dust(true, true)
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

return MyMonster
