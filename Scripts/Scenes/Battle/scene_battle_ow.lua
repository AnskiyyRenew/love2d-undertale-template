local scene = {}

-- ---------------------------------------------------------------------------
-- Overworld save-data bridge
--
-- scene_battle_ow is only ever entered from the overworld, so DATA always
-- exists here. The encounter Game module only defines *template* player stats,
-- so the real save data has to win, and the battle results (HP / EXP / GOLD and
-- any level-ups) have to reach DATA again when the scene is left.
--
-- Both halves now live in the Battle library (Battle.SyncFromOverworld /
-- Battle.SyncToOverworld) so EVERY battle scene gets them, not just this one -
-- a game that wired its overworld to another scene used to lose every stat
-- change. Battle.SetGame() already synced on entry and Battle.Clear() syncs on
-- exit; the calls below are kept so this file stays a readable reference for a
-- hand-written bridge scene, and both are idempotent (the engine consumes
-- Battle.EXP / GOLD, so nothing is ever counted twice).
-- ---------------------------------------------------------------------------

---Push the overworld save data into the live Player so the battle starts with
---the carried name / LV / HP instead of the Game module's template values.
local function ApplyDataToPlayer()
    Battle.SyncFromOverworld()
end

local data_returned = false

---Write the battle results back into DATA, applying any earned level-ups.
local function ReturnData()
    if (data_returned) then return end
    data_returned = true

    Battle.SyncToOverworld()
end

-- Import battle module
Battle = ImportFile("Battle")
Battle.SetEndRoom(DATA.room)
Game = Battle.SetGame(Global.GetVariable("OVERWORLD_ENCOUNTER_BATTLE")[2])
ApplyDataToPlayer()
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

---Victory handler. The "* Your LOVE increased!" line is only appended when this
---battle's EXP actually pushes the player past the next level threshold (the
---level-up itself is applied in ReturnData when the scene is cleared).
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

-- Don't touch these.
Battle.HandleActions = HandleActions
Battle.HandleItems = HandleItems
Battle.EnteringState = EnteringState
Battle.HandleFlee = HandleFlee
Battle.FleeUpdate = FleeUpdate
Battle.OnHit = OnHit
Battle.Win = Win



-- Scene backgrounds
local background = Sprites.CreateSprite("px.png", "Background")
background:Scale(640, 480)
background.color = {0, 0, 0}
--background:SetShaders({shader})

function scene.update(dt)
    Battle.Update(dt)
end

function scene.clear()
    ReturnData()
    Layers.clear()
    Battle.Clear()
end

return scene