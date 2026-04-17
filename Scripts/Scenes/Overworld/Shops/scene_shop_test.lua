local SCENE = {}
_CAMERA_:setPosition(0, 0)

-- Player data.
-- Including gold, exp, stats, equipment, and items.
DATA = DATA or global:GetSaveVariable("Overworld")

-- Check if the player has killed the Ruins monsters.
-- Or did something else that should be recorded as a flag.
-- E.G. The shopkeeper will escape if the player has killed monsters.
FLAG = FLAG or global:GetSaveVariable("Flag")

local text_welcome = "* Welcome to the shop!\n* What can I do for you?"
if (FLAG.ruins_killed >= 3) then
    text_welcome = "* You shouldn't be here.\n* Leave before I call the cops."
end

local DIALOGS = {}


-- Logic.
local buttons_main = {}
local buttons_diag = {}
local select_main = 1
local select_diag = 1
local in_main = true

-- Background.
local back_block_white = sprites.CreateSprite("px.png", -1)
back_block_white:Scale(640, 240)
back_block_white.color = {1, 1, 1}
back_block_white.y = 480 - back_block_white.yscale / 2
local back_block_black = sprites.CreateSprite("px.png", 0)
back_block_black:Scale(630, 230)
back_block_black.color = {0, 0, 0}
back_block_black:MoveTo(back_block_white:GetPosition())
local line = sprites.CreateSprite("px.png", 1)
line:Scale(5, 230)
line:MoveTo(430, back_block_black.y)
local heart = sprites.CreateSprite("Soul Library Sprites/spr_default_heart.png", 2)
heart:MoveTo(430, back_block_black.y)
heart.color = {1, 0, 0}

-- Buy, sell, talk, exit.
local buttons_name = {"Buy", "Sell", "Talk", "Exit"}
for i, name in ipairs(buttons_name) do
    local button = typers.DrawText(name, {480, 260 + (i - 1) * 40}, 1)
    table.insert(buttons_main, button)
end

-- data.
local gold = DATA.gold or 0
local pack = DATA.player.items or {}
local text = typers.DrawText(gold .. "G  " .. #pack .. "/8", {460, 430}, 1)

local typer_welcome = typers.CreateText(text_welcome, {30, 260}, 1, {0, 0}, "none")


function SCENE.update(dt)
    if (in_main) then
        if (keyboard.GetState("down") == 1) then
            select_main = math.min(4, select_main + 1)
        elseif (keyboard.GetState("up") == 1) then
            select_main = math.max(1, select_main - 1)
        end
        heart:MoveTo(buttons_main[select_main].x - 20, buttons_main[select_main].y + 17)
    end
end

function SCENE.draw()
end

function SCENE.clear()
    layers.clear()
end

-- Don't touch this(just one line).
return SCENE