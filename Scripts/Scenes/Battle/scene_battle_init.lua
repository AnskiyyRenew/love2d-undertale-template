local scene = {}

Battle = ImportFile("Battle")
Battle.SetEndRoom("scene_end")
Blasters = ImportFile("Attacks.Blasters")
Game = Battle.SetGame("dummy")
Game:AddItem({id = "STABLE", _color = {0.5, 0, 0}, name = "ImNotFood"})
Game:AddItem({id = "STABLE", _color = {0.5, 0, 0}, name = "ImNotFood"})
Game:AddItem({id = "STABLE", _color = {0.5, 0, 0}, name = "ImNotFood"})

Game:InitAnimation(1, {320, 140})
Game:InitAnimation(2, {120, 140})
local enemies = Game.enemies

--- Placeholder ending hook for the defense phase; intentionally empty.
local function DefenseEnding()
end

--- Routes the selected ACT entry to its localized dialogue line and reopens ACT.
---@param enemy table Enemy definition that owns the action table.
---@param action table Chosen action entry from the ACT menu.
local function HandleActions(enemy, action)
    Battle.BattleDialogue(Localize.localizeText("Battle.Actions.Texts." .. enemy.id .. "." .. action.id), "ACTIONSELECT")
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

--- Animates the soul running away, then marks the battle as finished.
local function HandleFlee()
    Audio.PlaySound("snd_flee.wav")
    local legs_ = Sprites.CreateSprite("Soul Library Sprites/spr_heartgtfo_0.png", Player.sprite.layer)
    legs_.color = Player.sprite.color
    legs_:MoveTo(Player.sprite:GetPosition())
    legs_.y = legs_.y + 6
    legs_.velocity.x = -1
    legs_:SetAnimation({
        "Soul Library Sprites/spr_heartgtfo_1.png",
        "Soul Library Sprites/spr_heartgtfo_0.png"
    }, 0.1)

    Player.sprite.y = Player.sprite.y - 6
    Player.sprite.velocity.x = -1
    Battle.FullDialogue({
        "* 我跑路了."
    }, function ()
        Battle._end = true
    end)
end

--- Per-frame hook for the flee state; currently has no work to do.
---@param dt number Seconds elapsed since the previous frame.
local function FleeUpdate(dt)
end

--- Delegates every battle state change to the shared default handler.
---@param oldstate string State the battle is leaving.
---@param newstate string State the battle is entering.
local function EnteringState(oldstate, newstate)
    Battle.defaultEnteringState(oldstate, newstate)
end

--- Applies bullet damage according to its hurt mode and the arrow keys held.
---@param bullet table Bullet that collided with the player soul.
local function OnHit(bullet)
    local damage = 1
    local color = (bullet["HurtMode"] or "normal")
    color = color:lower()

    if (color == "normal") then
        Player.Hurt(damage)
    elseif (color == "blue" or color == "cyan") then
        if (Controller.GetState("arrows") > 0) then
            Player.Hurt(damage)
        end
    elseif (color == "orange") then
        if (Controller.GetState("arrows") <= 0) then
            Player.Hurt(damage)
        end
    end
end

Battle.DefenseEnding = DefenseEnding
Battle.HandleActions = HandleActions
Battle.HandleItems = HandleItems
Battle.EnteringState = EnteringState
Battle.HandleFlee = HandleFlee
Battle.FleeUpdate = FleeUpdate
Battle.OnHit = OnHit

local shader = ImportFile("Gradiant", "shader")
shader:send("topLeftColor", {1, 0, 1, 0.5})
shader:send("bottomLeftColor", {1, 0, 1, 0.5})
shader:send("topRightColor", {0, 1, 1, 0.5})
shader:send("bottomRightColor", {0, 1, 1, 0.5})
shader:send("angle", 20)
local background = Sprites.CreateSprite("px.png", "Background")
background:Scale(640, 480)
background.color = {0, 0, 0}
background:SetShaders({shader})

--- Advances the battle and keeps the blaster attack pattern in sync.
---@param dt number Seconds elapsed since the previous frame.
function scene.update(dt)
    Battle.Update(dt)
    Blasters.Update(dt)
end

--- Releases all layers and resets the battle state.
function scene.clear()
    Layers.clear()
    Battle.Clear()
end

return scene