--  HOW TO USE
--    1. Copy this file and rename it, e.g. Game/Animations/Sol.lua
--    2. Replace the placeholders marked with "-- TODO" below.
--    3. Reference it from an encounter:
--       animation = require("Game.Animations.MyMonster")
--    4. Instantiate once per enemy in the scene:
--       Game:InitAnimation(i, {x, y})
--
--  CONTRACT  (plain tables, NO metatable — every function uses a dot and takes
--             the instance as its first argument)
--    * New(pos)               → creates a brand-new, INDEPENDENT instance.
--    * Init(self, pos)        → builds the sprites (called by New).
--    * Update(self, dt)       → per-frame logic, called by Battle.Update.
--    * Hurt(self)             → hit reaction, called by attack patterns.
--    * OnAttack(self, data)   → (optional) attack-launched signal.
--    * Spare(self)            → plays the spare reaction (MERCY → Spare).
--    * Destroy(self)          → cleans up sprites, called when the enemy dies.
--
--  HOW CALLERS REACH THE FUNCTIONS
--    Instances are plain tables carrying `_class` → this module, so from an
--    instance everything is one lookup away:
--        local anim = enemy.animation
--        anim._class.Hurt(anim)          -- engine does exactly this
--    Sprites stay colon-style (`sprite:Set(...)`, `sprite:Dust(...)`).
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

    -- Back-reference to the function table (see "HOW CALLERS REACH..." above).
    self._class = MyMonster

    self.running = true
    self.x = 0
    self.y = 0
    self.elements = {}
    self.hurting = false
    self.hurttime = 0
    self.intensity = 16

    MyMonster.Init(self, pos)
    return self
end

function MyMonster.Init(self, pos)
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

function MyMonster.Hurt(self)
    self.sprite:Set("Characters/Ruins/spr_looxhurt_0.png")
    self.hurting = true
    self.intensity = 16
end

function MyMonster.Spare(self)
    self.sprite:Set("Characters/Ruins/spr_looxhurt_0.png")
    self.sprite.alpha = 0.5
end

function MyMonster.Update(self, dt)
    if (not self.running) then
        return
    end

    -- ====================>
    -- TODO: put your monster's animation code here.

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
            --[[self.sprite:SetAnimation({
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
                "Characters/Ruins/spr_loox_0.png",
            }, 0.08)]]
        end
    end
    -- <====================
end

function MyMonster.Destroy(self)
    if (not self.sprite) then
        return
    end

    -- TODO: play a death effect here, e.g. sprite:Dust(true, true)
    self.sprite:Set("Characters/Ruins/spr_looxhurt_0.png")
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
