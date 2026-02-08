-- This is a template for creating a new scene in the game.
-- You can use this as a starting point for your own scenes.
local SCENE = {}

-- Load level data
local lvdata = require("Scripts.Libraries.Battle.LevelData")
local lvdata_default = lvdata.getlv("default")

local b = require("Scripts.Libraries.Battle.BattleInit")
battle = b.Init("Scripts.Libraries.Game.Spider")
atkp = require("Scripts.Libraries.Battle.Patterns.template")
b.SetAtkPattern(atkp)

local function HandleActions(enemy_name, action)
    local battle = b.battle
    if not battle or not battle.Enemies then return end
    if (enemy_name == battle.Enemies[1].name) then
        local enemy = battle.Enemies[1]
        if (action == enemy.actions[1]) then
            b.BattleDialogue(localize.Act11)
        elseif (action == enemy.actions[2]) then
            b.BattleDialogue(localize.Act12)
        end
    elseif (enemy_name == battle.Enemies[2].name) then
        local enemy = battle.Enemies[2]
        if (action == enemy.actions[1]) then
            b.BattleDialogue(localize.Act21)
        elseif (action == enemy.actions[2]) then
            b.BattleDialogue(localize.Act22)
        end
    end
end

local function HandleItems(itemID)
    local battle = b.battle
    if not battle then return end
    local inventory = battle.Inventory
    local randomText = {
        "* No."
    }

    b.BattleDialogue({
        "* You found an item...[wait:30]\n  [colorRGB:255, 255, 0]" .. itemID .. "!",
        randomText[love.math.random(1, #randomText)]
    })
end

local function HandleSpare()
    b.battle.STATE = "ACTIONSELECT"
end

local nextwaves = {"wave_test1", "wave_test2", "wave_test3", "wave_test4"}
b.battle.nextwave = "Spider/wave_intro"
local waveProgress = 1
local function DefenseEnding()
    waveProgress = waveProgress + 1
    if (waveProgress > #nextwaves) then waveProgress = 1 end
    b.battle.nextwave = nextwaves[waveProgress]
end

local function OnHit(Bullet)
    local battle = b.battle
    if not battle then return end
    local mode = Bullet['HurtMode']
    if (mode == "normal" or type(mode) == "nil") then
        battle.Player.Hurt(1, 60, true)
        b.AddKR(5)
    elseif (mode == "cyan" or mode == "blue") then
        if (keyboard.GetState("arrows") > 0) then
            battle.Player.Hurt(1, 0, true)
            b.AddKR(1)
        end
    elseif (mode == "orange") then
        if (keyboard.GetState("arrows") <= 0) then
            battle.Player.Hurt(1, 0, true)
            b.AddKR(1)
        end
    elseif (mode == "green") then
        battle.Player.Heal(1)
        Bullet:Destroy()
    end
end

local function winCall()
    local battle = b.battle
    if not battle then return end
    
    -- Calculate rewards
    local exp = 0
    local gold = 0  -- Assuming gold is 0 or needs to be calculated from enemies
    exp = exp + battle.Exp
    gold = gold + battle.Gold

    local lv = battle.Player.lv
    local totalExp = lvdata_default[lv].totalExp + exp
    local newLv = lv
    for i = lv, #lvdata_default do
        if (totalExp >= lvdata_default[i].totalExp) then
            newLv = i
        else
            break
        end
    end
    if (newLv > lv) then
        audio.PlaySound("snd_levelup.wav")
        battle.Player.maxhp = lvdata_default[newLv].hp
        battle.Player.at = lvdata_default[newLv].at
        battle.Player.df = lvdata_default[newLv].df
        battle.Player.lv = newLv
        print("Level Up! New LV: " .. newLv)
        b.BattleDialogue({
            "* You won!\n* You earned " .. exp .. " EXP and " .. gold .. " gold.\n* Your LOVE increased.",
            "[noskip][function:ChangeScene|" .. DATA.room .. "][next]"
        })
    else
        b.BattleDialogue({
            "* You won!\n* You earned " .. exp .. " EXP and " .. gold .. " gold.",
            "[noskip][function:ChangeScene|" .. DATA.room .. "][next]"
        })
    end
end

b.HandleActions = HandleActions
b.HandleItems   = HandleItems
b.HandleSpare   = HandleSpare
b.DefenseEnding = DefenseEnding
b.OnHit         = OnHit
b.WinBattleCall = winCall



local SPIDERLINE = sprites.CreateSprite("px.png", -2)
SPIDERLINE.color = {1, 0, 1}
SPIDERLINE.ypivot = 0
SPIDERLINE.y = 0
local SPIDER = sprites.CreateSprite("Attacks/Muffet/spr_spiderbullet1_0.png", -1)
SPIDER:Scale(2, 2)
SPIDER.y = -0
tween.CreateTween(
    function (value)
        SPIDERLINE.yscale = value
    end,
    "Elastic", "Out", 0, 160, 160
)
tween.CreateTween(
    function (value)
        SPIDERLINE.rotation = value
    end,
    "Elastic", "Out", -90, 0, 240
)

-- This is a fake scene for testing purposes.
function SCENE.load()
    -- Load any resources needed for this scene here.
    -- For example, you might load images, sounds, etc.
end


local time = 0
local blacktop = sprites.CreateSprite("px.png", 1000)
blacktop:Scale(640, 480)
blacktop.color = {0, 0, 0}

local attack = {
    run = false,
    atk = false,
    time = 0,
    randomrot = love.math.random(-3, 3)
}

-- This function is called to update the scene.
function SCENE.update(dt)
    -- Update any game logic for this scene here.
    -- For example, you might update animations, handle input, etc.
    b.Update(dt)
    if (attack.run) then
        if (keyboard.GetState("confirm") == 1) then
            attack.atk = true
        end
    end
    if (b.GetSelectedEnemy() == 1 and b.GetState() == "ATTACKING") then
        attack.run = true
    end

    if (attack.atk) then
        attack.time = attack.time + 1
        if (attack.time == 70) then
            SPIDER.velocity.y = -2
        end
        if (attack.time >= 70) then
            SPIDER.rotation = SPIDER.rotation + attack.randomrot
            SPIDER.velocity.y = SPIDER.velocity.y + 0.2
        end
    end

    time = time + 1

    if (time <= 240) then
        blacktop.alpha = blacktop.alpha - 0.05
        SPIDER.rotation = SPIDERLINE.rotation
        SPIDER:MoveTo(
            SPIDERLINE.x - SPIDERLINE.yscale * math.sin(math.rad(SPIDERLINE.rotation)),
            SPIDERLINE.y + SPIDERLINE.yscale * math.cos(math.rad(SPIDERLINE.rotation))
        )
    end
end

-- This function is called to draw the scene.
-- It is called after the main game loop has finished updating.
function SCENE.draw()
    -- Draw the scene here.
    -- For example, you might draw images, text, etc.
    b.Draw()
end

-- This function is called when the scene is switched away from.
function SCENE.clear()
    -- Clear any resources used by this scene here.
    -- For example, you might unload images, sounds, etc.
    b.Clear()
    package.loaded["Scripts.Libraries.Battle.BattleInit"] = nil
end

-- Don't touch this(just one line).
return SCENE