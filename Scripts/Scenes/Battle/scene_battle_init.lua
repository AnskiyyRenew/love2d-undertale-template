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
Battle.SetEndRoom("scene_end")
Game = Battle.SetGame("Poseur")
Game:AddItem({id = "STABLE", _color = {0.5, 0, 0}, name = "ImNotFood"})
Game:AddItem({id = "STABLE", _color = {0.5, 0, 0}, name = "ImNotFood"})
Game:AddItem({id = "STABLE", _color = {0.5, 0, 0}, name = "ImNotFood"})

-- Give each enemy its own independent animation instance. The animation
-- module is a factory, so every call to InitAnimation creates a fresh
-- instance with its own sprite — enemy #1 and enemy #2 no longer share one.
Game:InitAnimation(1, {320, 140})
Game:InitAnimation(2, {120, 140})
local enemies = Game.enemies

-- Handlers
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
    print("Fleeing")
end

local function EnteringState(oldstate, newstate)
    Battle.defaultEnteringState(oldstate, newstate)
    --print("[Battle] " .. oldstate .. " → " .. newstate)
end

local function OnHit(bullet)
    Player.AddKR(2)
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
end

function scene.clear()
    Layers.clear()
    Battle.Clear()
end

return scene