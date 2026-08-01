local scene = {}

local logo = Sprites.CreateSprite("Logo.png")
local time = 0
local alpha = 0

Audio.PlaySound("snd_intro.ogg")
local font = SE.graphics.newFont("Resources/Fonts/determination_mono.ttf", 13, "mono")
font:setFilter("nearest", "nearest")

local tip = SE.graphics.newFont("Resources/Fonts/Mars Needs Cunnilingus.ttf", 13, "mono")
tip:setFilter("nearest", "nearest")

function scene.update(dt)
    time = time + 1
    if (time >= 180 and time % 60 == 0) then
        alpha = 1 - alpha
    end

    if (Keyboard.GetState("confirm") == 1) then
        Scenes.switchTo("Battle.scene_battle_init")
    end
end

function scene.draw()
    SE.graphics.setFont(font)
    SE.graphics.setColor(0.4, 0.4, 0.4, alpha)
    SE.graphics.printf("[PRESS Z OR ENTER]", 0, 320, 640, "center")

    SE.graphics.setFont(font)
    SE.graphics.setColor(1, 0, 0, 1)
    SE.graphics.printf("Undertale By Toby Fox © 2015", 0, 445, 640, "left")

    SE.graphics.setColor(0.4, 0, 1, 1)
    SE.graphics.printf("SoulEngine By Anskiyy © 2024", 0, 460, 640, "left")

    SE.graphics.setColor(1, 1, 1, 1)
    SE.graphics.printf(_VER, 0, 460, 640, "right")
end

function scene.clear()
    Layers.clear()
end

return scene