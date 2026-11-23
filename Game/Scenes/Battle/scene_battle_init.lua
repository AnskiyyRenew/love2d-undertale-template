local scene = {}

Battle = ImportFile("Battle")
Battle.SetEndRoom("scene_end")
Blasters = ImportFile("Attacks.Blasters")
Game = Battle.SetGame("dummy")
Game:AddItem({id = "STABLE", _color = {0.5, 0, 0}, name = "ImNotFood"})
Game:AddItem({id = "STABLE", _color = {0.5, 0, 0}, name = "ImNotFood"})
Game:AddItem({id = "STABLE", _color = {0.5, 0, 0}, name = "ImNotFood"})

-- InitAnimation is a factory: each enemy gets its own sprite instance.
Game:InitAnimation(1, {320, 140})
local enemies = Game.enemies

local function DefenseEnding()
end

local function HandleActions(enemy, action)
    Battle.BattleDialogue(Localize.localizeText("Battle.Actions.Texts." .. enemy.id .. "." .. action.id), "ACTIONSELECT")
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

local function FleeUpdate(dt)
end

local function EnteringState(oldstate, newstate)
    Battle.defaultEnteringState(oldstate, newstate)
end

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

-- Overrides the battle module reads by name; do not rename.
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

function scene.update(dt)
    Battle.Update(dt)
    Blasters.Update(dt)
end

function scene.clear()
    Layers.clear()
    Battle.Clear()
end

return scene