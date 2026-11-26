local scene = {}

Battle = ImportFile("Battle")
Battle.SetEndRoom("scene_end")
Game = Battle.SetGame("Poseur")
Game:AddItem({id = "STABLE", _color = {0.5, 0, 0}, name = "ImNotFood"})

Game:InitAnimation(1, {320, 140})
Game:InitAnimation(2, {120, 140})
local enemies = Game.enemies

--- Shows the Poseur CHECK description when that action is picked.
---@param enemy table Enemy definition that owns the action table.
---@param action table Chosen action entry from the ACT menu.
local function HandleActions(enemy, action)
    if (enemy.id == "Poseur") then
        if (action.id == "Check") then
            Battle.BattleDialogue(Localize.localizeText("Battle.Actions.Texts." .. enemy.id .. "." .. action.id), "ACTIONSELECT")
        end
    end
end

--- Consumes the chosen item, heals the player and prints the result text.
---@param item table Inventory item that was used.
local function HandleItems(item)
    print("Used " .. item.name)

    Player.Heal(99, true)
    Battle.BattleDialogue({
        "* You ate " .. item.name .. ".",
        "* You recovered 99 HP!"
    }, "ACTIONSELECT")
end

--- Logs the flee attempt; this test battle has no real escape path.
local function HandleFlee()
    print("Flee")
end

--- Per-frame hook for the flee state; currently has no work to do.
---@param dt number Seconds elapsed since the previous frame.
local function FleeUpdate(dt)
end

--- Runs the shared transition logic and logs it to the console.
---@param oldstate string State the battle is leaving.
---@param newstate string State the battle is entering.
local function EnteringState(oldstate, newstate)
    Battle.defaultEnteringState(oldstate, newstate)
    print("[Battle] " .. oldstate .. " → " .. newstate)
end

--- Hurts the player for a fixed amount with extra invulnerability frames.
---@param bullet table Bullet that collided with the player soul.
local function OnHit(bullet)
    Player.Hurt(3, 60, true)
end

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

--- Advances the battle and applies test damage while K is held down.
---@param dt number Seconds elapsed since the previous frame.
function scene.update(dt)
    Battle.Update(dt)

    if (Keyboard.GetState("K") == 1) then
        Player.Hurt(30, 60)
    end
end

--- Releases all layers and resets the battle state.
function scene.clear()
    Layers.clear()
    Battle.Clear()
end

return scene