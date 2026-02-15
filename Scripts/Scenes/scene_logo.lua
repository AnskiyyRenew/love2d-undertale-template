local SCENE = {
    PRIORITY = true,
    SAVESHADERS = true
}

audio.ClearAll()

local logo = sprites.CreateSprite("Logo.png", 0)
audio.PlaySound("snd_intro.ogg")

local license = typers.DrawText("[scale=0.5][spaceX=-8][red]UNDERTALE  ©2015 Toby Fox", {5, 445}, 1)
local license2 = typers.DrawText("[scale=0.5][spaceX=-8][purple]SOULENGINE ©2024 Clavo Sophame", {5, 460}, 1)
local version = typers.DrawText("[scale=0.5][spaceX=-8]v" .. _VERSION, {-90, 460}, 1)
local length = version:GetLettersSize()
version.x = 640 - length - 5
_CAMERA_:setAngle(0)
_CAMERA_:setPosition(0, 0)

local time = 0
local text_alpha = 0

function SCENE.load()
end

function SCENE.update(dt)
    if (keyboard.GetState("confirm") == 1) then
        scenes.switchTo("Battle/scene_battle")
    end

    time = time + 1
    if (time >= 180 and time % 60 == 0) then
        text_alpha = 1 - text_alpha
    end
end

local tfont = love.graphics.newFont("Resources/Fonts/determination_mono.ttf", 13)
tfont:setFilter("nearest", "nearest")
function SCENE.draw()
    love.graphics.push()
        love.graphics.setColor(1, 1, 1, text_alpha)
        love.graphics.setFont(tfont)
        love.graphics.print("[Press z or enter]", 250, 320)
    love.graphics.pop()
end

function SCENE.clear()
    tfont:release()

    layers.clear()
    audio.ClearAll()
end

return SCENE