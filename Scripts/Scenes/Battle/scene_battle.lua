local scene = {}

-- Init layers
Layers.new_layer("BOTTOM", -1000)
Layers.new_layer("Background", -10)
Layers.new_layer("UI", 0)
Layers.new_layer("ArenasExtraW", 10)
Layers.new_layer("ArenasExtraB", 10.01)
Layers.new_layer("UponArena", 11)
Layers.new_layer("BelowPlayer", 12)
Layers.new_layer("Player", 13)
Layers.new_layer("Bullets", 30)
Layers.new_layer("ArenasCoverW", 50)
Layers.new_layer("ArenasCoverB", 50.01)
Layers.new_layer("TopAll", 60)
Layers.new_layer("TOP", 1000)

-- Import battle module
Battle = ImportFile("Battle")
Game = Battle.SetGame("TestMonster")

-- Animations
local sincera = require("Scripts.Game.Animations.Sincera")
sincera.Init()
local spyder = require("Scripts.Game.Animations.Spyder")
spyder.Init()
spyder.Line(520, 0)
local sol = require("Scripts.Game.Animations.Sol")
sol.Init()

-- Register each enemy animation so attack patterns can trigger its Hurt()
-- animation by the enemy's id. Safe even before those modules define Hurt().
Battle.RegisterEnemyAnim("SINCERA", sincera)
Battle.RegisterEnemyAnim("SPIDER", spyder)
Battle.RegisterEnemyAnim("SOL", sol)

function Jser()
    spyder.JumpScare()
end

-- Handlers
local sincera_ = 0
local function HandleActions(enemy, action)
    if (enemy.id == "SOL") then
        if (action.id == "CHECK") then
            Battle.BattleDialogue(Localize.localizeText("Battle.Actions.Texts." .. enemy.id .. "." .. action.id), "ACTIONSELECT")
        elseif (action.id == "TALK") then
            sol.Bounce()
            Battle.BattleDialogue(Localize.localizeText("Battle.Actions.Texts." .. enemy.id .. "." .. action.id), "ACTIONSELECT")
        elseif (action.id == "STARE") then
            sol.Zoom(sol.cube.z - 200, 60)
            sol.RotateFaster()
            Battle.BattleDialogue(Localize.localizeText("Battle.Actions.Texts." .. enemy.id .. "." .. action.id), "ACTIONSELECT")
        elseif (action.id == "IGNORE") then
            sol.Zoom(sol.cube.z + 200, 60)
            Battle.BattleDialogue(Localize.localizeText("Battle.Actions.Texts." .. enemy.id .. "." .. action.id), "ACTIONSELECT")
        end
    elseif (enemy.id == "SINCERA") then
        if (action.id == "CHECK") then
            Battle.BattleDialogue(Localize.localizeText("Battle.Actions.Texts." .. enemy.id .. "." .. action.id), "ACTIONSELECT")
        elseif (action.id == "APPRECIATE") then
            sincera_ = sincera_ + 1
            print(sincera_)
            if (sincera_ == 1) then
                Battle.BattleDialogue(Localize.localizeText("Battle.Actions.Texts.SINCERA.APPRECIATE1"), "ACTIONSELECT")
            else
                Battle.BattleDialogue(Localize.localizeText("Battle.Actions.Texts.SINCERA.APPRECIATE2"), "ACTIONSELECT")
            end
        end
    elseif (enemy.id == "SPIDER") then
        if (action.id == "CHECK") then
            Battle.BattleDialogue(Localize.localizeText("Battle.Actions.Texts." .. enemy.id .. "." .. action.id), "ACTIONSELECT")
        elseif (action.id == "TALK") then
            Battle.BattleDialogue(Localize.localizeText("Battle.Actions.Texts." .. enemy.id .. "." .. action.id), "ACTIONSELECT")
        elseif (action.id == "KNOT") then
            Battle.BattleDialogue(Localize.localizeText("Battle.Actions.Texts." .. enemy.id .. "." .. action.id), "ACTIONSELECT")
            spyder.Bounce()
        end
    end
end

local function HandleFlee()
    local p = (math.random() <= 0.75)

    if (p) then
        Battle.ChangeState("FLEEING")
    end
end

local function FleeUpdate(dt)
    
end

local function EnteringState(oldstate, newstate)
    Battle.defaultEnteringState(oldstate, newstate)
end




Battle.HandleActions = HandleActions
Battle.EnteringState = EnteringState
Battle.HandleFlee = HandleFlee
Battle.FleeUpdate = FleeUpdate





function scene.update(dt)
    Battle.Update(dt)
    sol.Update(dt)
    spyder.Update(dt)
end

function scene.clear()
    Layers.clear()
    Battle.Clear()
end

return scene