local scene = {}

Battle = ImportFile("Battle")
Battle.SetEndRoom("scene_end")
Game = Battle.SetGame("Poseur")
Game:AddItem({id = "STABLE", _color = {0.5, 0, 0}, name = "ImNotFood"})

-- InitAnimation is a factory: each enemy gets its own sprite instance.
Game:InitAnimation(1, {320, 140})
Game:InitAnimation(2, {120, 140})
local enemies = Game.enemies

local function HandleActions(enemy, action)
    if (enemy.id == "Poseur") then
        if (action.id == "Check") then
            Battle.BattleDialogue(Localize.localizeText("Battle.Actions.Texts." .. enemy.id .. "." .. action.id), "ACTIONSELECT")
        end
    end
end

local function HandleItems(item)
    print("Used " .. item.name)

    Player.Heal(99, true)
    Battle.BattleDialogue({
        "* You ate " .. item.name .. ".",
        "* You recovered 99 HP!"
    }, "ACTIONSELECT")
end

local function HandleFlee()
    print("Flee")
end

local function FleeUpdate(dt)
end

local function EnteringState(oldstate, newstate)
    Battle.defaultEnteringState(oldstate, newstate)
    print("[Battle] " .. oldstate .. " → " .. newstate)
end

local function OnHit(bullet)
    Player.Hurt(3, 60, true)
end

-- Overrides the battle module reads by name; do not rename.
Battle.HandleActions = HandleActions
Battle.HandleItems = HandleItems
Battle.EnteringState = EnteringState
Battle.HandleFlee = HandleFlee
Battle.FleeUpdate = FleeUpdate
Battle.OnHit = OnHit



local shader = ImportFile("Gradiant", "shader")
shader:send("topLeftColor", {1, 0, 0, 0.5})
shader:send("bottomLeftColor", {1, 0, 1, 0.5})
shader:send("topRightColor", {0, 1, 1, 0.5})
shader:send("bottomRightColor", {0, 1, 1, 0.5})
shader:send("angle", 20)
local background = Sprites.CreateSprite("px.png", "Background")
background:Scale(640, 480)

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