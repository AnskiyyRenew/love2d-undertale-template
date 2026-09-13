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

-- ---------------------------------------------------------------------------
-- Overworld save-data bridge
--
-- scene_battle_ow is only ever entered from the overworld, so DATA always
-- exists here. The encounter Game module only defines *template* player stats,
-- so the real save data is pushed into the live Player on entry, and the battle
-- results (HP / EXP / GOLD and any level-ups) are written back into DATA when
-- the scene is left.
-- ---------------------------------------------------------------------------

---Push the overworld save data into the live Player so the battle starts with
---the carried name / LV / HP instead of the Game module's template values.
local function ApplyDataToPlayer()
    Player.name = DATA.player.name
    Player.lv = DATA.player.lv
    Player.maxhp = DATA.player.maxhp
    Player.hp = DATA.player.hp
    Player.kr = 0

    UI.barUpdate()
end

local data_returned = false

---Write the battle results back into DATA, applying any earned level-ups.
local function ReturnData()
    if (data_returned) then return end
    data_returned = true

    -- EXP / GOLD earned during the battle.
    DATA.player.exp = DATA.player.exp + (Battle.EXP or 0)
    DATA.player.gold = DATA.player.gold + (Battle.GOLD or 0)

    -- Carry the HP the player finished the battle with.
    DATA.player.hp = math.max(0, math.min(DATA.player.maxhp, Player.hp))

    -- Level up while the total EXP has reached the next threshold.
    while (DATA.lv_data[DATA.player.lv + 1] and
           DATA.player.exp >= DATA.lv_data[DATA.player.lv + 1].totalExp) do
        local old_max = DATA.player.maxhp
        DATA.player.lv = DATA.player.lv + 1

        local row = DATA.lv_data[DATA.player.lv]
        DATA.player.maxhp = row.hp
        DATA.player.atk = row.at
        DATA.player.def = row.df

        -- Undertale-style: the gained max HP is added to the current HP.
        DATA.player.hp = math.min(DATA.player.maxhp, DATA.player.hp + (DATA.player.maxhp - old_max))
    end

    -- Consume the earnings so a second write-back can never double-count.
    Battle.EXP = 0
    Battle.GOLD = 0
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