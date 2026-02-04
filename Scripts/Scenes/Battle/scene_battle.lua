-- This is a template for creating a new scene in the game.
-- You can use this as a starting point for your own scenes.
local SCENE = {}
local b = require("Scripts.Libraries.Battle.BattleInit")
battle = b.Init("Scripts.Libraries.Game.Encounter")
atkp = require("Scripts.Libraries.Battle.Patterns.template")
b.SetAtkPattern(atkp)

local function HandleActions(enemy_name, action)
    local battle = b.battle
    if not battle or not battle.Enemies then return end
    if (enemy_name == battle.Enemies[1].name) then
        local enemy = battle.Enemies[1]
        if (action == enemy.actions[1]) then
            b.BattleDialogue(localize.Act11)
        elseif (action == enemy.actions[2]) then
            b.BattleDialogue(localize.Act12)
        end
    elseif (enemy_name == battle.Enemies[2].name) then
        local enemy = battle.Enemies[2]
        if (action == enemy.actions[1]) then
            b.BattleDialogue(localize.Act21)
        elseif (action == enemy.actions[2]) then
            b.BattleDialogue(localize.Act22)
        end
    end
end

local function HandleItems(itemID)
    local battle = b.battle
    if not battle then return end
    local inventory = battle.Inventory
    local randomText = {
        "* No."
    }

    b.BattleDialogue({
        "* You found an item...[wait:30]\n  [colorRGB:255, 255, 0]" .. itemID .. "!",
        randomText[love.math.random(1, #randomText)]
    })
end

local function HandleSpare()
    b.battle.STATE = "ACTIONSELECT"
end

local nextwaves = {"wave_test1", "wave_test2", "wave_test3", "wave_test4"}
b.battle.nextwave = "wave_test4"
local waveProgress = 1
local function DefenseEnding()
    waveProgress = waveProgress + 1
    if (waveProgress > #nextwaves) then waveProgress = 1 end
    b.battle.nextwave = nextwaves[waveProgress]
end

local function OnHit(Bullet)
    local battle = b.battle
    if not battle then return end
    local mode = Bullet['HurtMode']
    if (mode == "normal" or type(mode) == "nil") then
        battle.Player.Hurt(1, 60, true)
        b.AddKR(5)
    elseif (mode == "cyan" or mode == "blue") then
        if (keyboard.GetState("arrows") > 0) then
            battle.Player.Hurt(1, 0, true)
            b.AddKR(1)
        end
    elseif (mode == "orange") then
        if (keyboard.GetState("arrows") <= 0) then
            battle.Player.Hurt(1, 0, true)
            b.AddKR(1)
        end
    elseif (mode == "green") then
        battle.Player.Heal(1)
        Bullet:Destroy()
    end
end

b.HandleActions = HandleActions
b.HandleItems   = HandleItems
b.HandleSpare   = HandleSpare
b.DefenseEnding = DefenseEnding
b.OnHit         = OnHit





-- This is a fake scene for testing purposes.
function SCENE.load()
    -- Load any resources needed for this scene here.
    -- For example, you might load images, sounds, etc.
end

-- This function is called to update the scene.
function SCENE.update(dt)
    -- Update any game logic for this scene here.
    -- For example, you might update animations, handle input, etc.
    b.Update(dt)
    if (b.GetSelectedEnemy() == 1 and b.GetState() == "ATTACKING") then
        print("Selected Poseur")
    end
end

-- This function is called to draw the scene.
-- It is called after the main game loop has finished updating.
function SCENE.draw()
    -- Draw the scene here.
    -- For example, you might draw images, text, etc.
    b.Draw()
end

-- This function is called when the scene is switched away from.
function SCENE.clear()
    -- Clear any resources used by this scene here.
    -- For example, you might unload images, sounds, etc.
    b.Clear()
    package.loaded["Scripts.Libraries.Battle.BattleInit"] = nil
end

-- Don't touch this(just one line).
return SCENE