--  HOW TO USE
--    1. Copy this file and rename it, e.g. Scripts/Game/Animations/Sol.lua
--    2. Replace the placeholders marked with "-- TODO" below.
--    3. Reference it from an encounter:
--       animation = require("Scripts.Game.Animations.MyMonster")
--    4. Instantiate once per enemy in the scene:
--       Game:InitAnimation(i, {x, y})
--
--  CONTRACT
--    * New(pos)      → creates a brand-new, INDEPENDENT instance.
--    * :Init(pos)    → builds the sprites (called by New).
--    * :Update(dt)   → per-frame logic, called by Battle.Update.
--    * :Hurt()       → hit reaction, called by attack patterns.
--    * :Destroy()    → cleans up sprites, called when the enemy dies.
--
--  IMPORTANT
--    * Lua's `require` returns this module ONCE (it is cached). Two enemies of
--      the same type would otherwise share ONE table → they would share one
--      sprite. `New(...)` is the ONLY way to get a usable, per-enemy instance.
--    * NEVER store per-monster state (sprites, timers, flags) at module level.
--      Put everything on `self` so each instance owns its own data.
-- ============================================================================

local MyMonster = {}
MyMonster.__index = MyMonster

function MyMonster.New(pos)
    local self = setmetatable({}, MyMonster)
    self.running = true
    self.x = 0
    self.y = 0
    self.elements = {}
    self.hurting = false
    self.hurttime = 0
    self.intensity = 16
    self:Init(pos)
    return self
end

function MyMonster:Init(pos)
    local _pos = (pos or {320, 140})
    local sprite = Sprites.CreateSprite("poseur.png", "UI")
    sprite:MoveTo(_pos[1], _pos[2])

    self.sprite = sprite
    self.cpos = {sprite.x, sprite.y}
end

function MyMonster:Hurt()
    self.hurting = true
    self.intensity = 16
end

function MyMonster:Spare()
end

function MyMonster:Update(dt)
    if (not self.running or not self.sprite) then
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
        end
    end
    -- <====================
end

function MyMonster:Destroy()
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
