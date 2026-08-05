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
Game = Battle.SetGame("Poseur")
Game:AddItem({id = "STABLE", _color = {0.5, 0, 0}, name = "ImNotFood"})

-- Give each enemy its own independent animation instance. The animation
-- module is a factory, so every call to InitAnimation creates a fresh
-- instance with its own sprite — enemy #1 and enemy #2 no longer share one.
Game:InitAnimation(1, {320, 140})
Game:InitAnimation(2, {120, 140})
local enemies = Game.enemies

-- Handlers
local function HandleActions(enemy, action)
    if (enemy.id == "Poseur") then
        if (action.id == "Check") then
            Battle.BattleDialogue(Localize.localizeText("Battle.Actions.Texts." .. enemy.id .. "." .. action.id), "ACTIONSELECT")
        end
    end
end

local function HandleItems(item)
    print("Used " .. item.name)
    Battle.BattleDialogue({
        "* Wow"
    }, "ACTIONSELECT")
end

local function HandleFlee()
    print("Flee")
end

local function FleeUpdate(dt)
    print("Fleeing")
end

local function EnteringState(oldstate, newstate)
    Battle.defaultEnteringState(oldstate, newstate)
    --print("[Battle] " .. oldstate .. " → " .. newstate)
end

local function OnHit(bullet)
    Player.Hurt(3, 60)
end

-- Don't touch these.
Battle.HandleActions = HandleActions
Battle.HandleItems = HandleItems
Battle.EnteringState = EnteringState
Battle.HandleFlee = HandleFlee
Battle.FleeUpdate = FleeUpdate
Battle.OnHit = OnHit



-- Scene backgrounds
local shader = ImportFile("Gradiant", "shader")
shader:send("topLeftColor", {1, 0, 1, 0.5})
shader:send("bottomLeftColor", {1, 0, 1, 0.5})
shader:send("topRightColor", {0, 1, 1, 0.5})
shader:send("bottomRightColor", {0, 1, 1, 0.5})
shader:send("angle", 20)
local background = Sprites.CreateSprite("px.png", "Background")
background:Scale(640, 480)
--background.color = {0, 0, 0}
background:SetShaders({shader})

function scene.update(dt)
    Battle.Update(dt)

    if (Keyboard.GetState("K") == 1) then
        Player.Hurt(30, 60)
    end
end

function scene.clear()
    Layers.clear()
    Battle.Clear()
end

return scene