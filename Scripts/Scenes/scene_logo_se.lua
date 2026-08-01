local scene = {}

local logo = Sprites.CreateSprite("Logo.png")
local time = 0
local alpha = 0

Tween.CreateTween(function (v)
    logo.y = v
end, "Quad", "InOut", 240, -50, 60, 60)
Audio.PlaySound("snd_intro.ogg")

local logoline = Sprites.CreateSprite("px.png", 1)
logoline.alpha = 0.3
logoline.rotation = 30
logoline.x = 300
logoline.y = 230
logoline.color = {0.4, 0, 1}
logoline.yscale = 0
logoline.Step = function (self)
    if (time == 150) then
        Tween.CreateTween(function (v)
            logoline.yscale = v
        end, "Quad", "In", 0, 1000, 50)
    end
    if (time == 180) then
        Audio.PlaySound("snd_ding.wav")
        self.alpha = 0.5
    end
end

local font = SE.graphics.newFont("Resources/Fonts/determination_mono.ttf", 13, "mono")
font:setFilter("nearest", "nearest")
local tip = SE.graphics.newFont("Resources/Fonts/Mars Needs Cunnilingus.ttf", 13, "mono")
tip:setFilter("nearest", "nearest")
local lfont = SE.graphics.newFont("Resources/Fonts/MonsterFriendFore.otf", 48, "mono")
lfont:setFilter("nearest", "nearest")

local left_x = -200
local right_x = 640
local left_y = 200
local right_y = 200
Layers.add_external(function ()
    if (time <= 180) then
        SE.graphics.setFont(lfont)
        SE.graphics.print("SOUL", left_x, left_y)
        SE.graphics.setFont(lfont)
        SE.graphics.print("ENGINE", right_x, right_y)
    else
        SE.graphics.setFont(lfont)
        SE.graphics.setColor(1, 0, 1)
        SE.graphics.print("SOUL", left_x, left_y)
        SE.graphics.setFont(lfont)
        SE.graphics.setColor(0, 1, 1)
        SE.graphics.print("ENGINE", right_x, right_y)
    end
end)

Tween.CreateTween(function (v)
    left_x = v
end, "Quad", "InOut", left_x, 100, 60, 90)
Tween.CreateTween(function (v)
    right_x = v
end, "Quad", "InOut", right_x, 300, 50, 100)
Tween.CreateTween(function (v)
    left_x = v
end, "Quad", "InOut", 100, 120, 30, 150)
Tween.CreateTween(function (v)
    right_x = v
end, "Quad", "InOut", 300, 310, 30, 150)
Tween.CreateTween(function (v)
    left_y = v
end, "Quad", "InOut", left_y, 170, 30, 150)
Tween.CreateTween(function (v)
    right_y = v
end, "Quad", "InOut", right_y, 230, 30, 150)

function scene.update(dt)
    time = time + 1
    if (time >= 180 and time % 60 == 0) then
        alpha = 1 - alpha
    end
    if (time >= 180) then
        left_x = 120 +  2 * math.sin(math.rad(time) * 2)
        left_y = 170 +  2 * math.sin(math.rad(time) * 3)
        right_x = 310 - 2 * math.sin(math.rad(time) * 2)
        right_y = 230 - 2 * math.sin(math.rad(time) * 3)
    end

    if (Keyboard.GetState("confirm") == 1) then
        Scenes.switchTo("Battle.scene_battle")
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