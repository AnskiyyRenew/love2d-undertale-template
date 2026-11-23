local scene = {}

-- Overworld save-data bridge. `DATA` (Game/Logics) holds the live overworld
-- stats, while an encounter module only defines template values. Idempotent:
-- EXP / GOLD are consumed on write-back, so nothing is double-counted.

---Push the overworld save data into the live Player so the battle starts with
---the carried name / LV / HP instead of the Game module's template values.
local function ApplyDataToPlayer()
    Battle.SyncFromOverworld()
end

local data_returned = false

---Write the battle results back into DATA. Runs once per scene clear.
local function ReturnData()
    if (data_returned) then return end
    data_returned = true

    Battle.SyncToOverworld()
end

Battle = ImportFile("Battle")
Battle.SetEndRoom(DATA.room)
Game = Battle.SetGame(Global.GetVariable("OVERWORLD_ENCOUNTER_BATTLE")[2])
ApplyDataToPlayer()
Game:AddItem({id = "STABLE", _color = {0.5, 0, 0}, name = "ImNotFood"})
Game:AddItem({id = "STABLE", _color = {0.5, 0, 0}, name = "ImNotFood"})
Game:AddItem({id = "STABLE", _color = {0.5, 0, 0}, name = "ImNotFood"})

-- InitAnimation is a factory: each enemy gets its own sprite instance.
Game:InitAnimation(1, {320, 140})
Game:InitAnimation(2, {120, 140})
local enemies = Game.enemies

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
    Player.AddKR(2)
end

---Victory handler. Appends the LOVE line only when this battle's EXP crosses
---the next level threshold; the level-up itself happens in ReturnData.
local function Win()
    local next_row = DATA.lv_data[DATA.player.lv + 1]
    local leveled_up = (next_row ~= nil and
                        (DATA.player.exp + (Battle.EXP or 0)) >= next_row.totalExp)

    local extra = nil
    if (leveled_up) then
        extra = {"* Your LOVE increased!"}
    end

    Battle.defaultWin(extra)
end

-- Overrides the battle module reads by name; do not rename.
Battle.HandleActions = HandleActions
Battle.HandleItems = HandleItems
Battle.EnteringState = EnteringState
Battle.HandleFlee = HandleFlee
Battle.FleeUpdate = FleeUpdate
Battle.OnHit = OnHit
Battle.Win = Win



local background = Sprites.CreateSprite("px.png", "Background")
background:Scale(640, 480)
background.color = {0, 0, 0}

function scene.update(dt)
    Battle.Update(dt)
end

function scene.clear()
    ReturnData()
    Layers.clear()
    Battle.Clear()
end

return scene