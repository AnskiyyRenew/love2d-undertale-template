local Arena = battle.mainarena
local Player = battle.Player

local wave = {
    ENDED = false,
    objects = {}
}

local function EndWave()
    wave.ENDED = true
    arenas.clear()
    for i = #wave.objects, 1, -1 do
        local obj = wave.objects[i]
        obj:Destroy()
        table.remove(wave.objects, i)
    end
end

Arena:Resize(155, 130)
Player.sprite:MoveTo(320, 320)

local mask = masks.New("rectangle", 320, 320, 155, 130, 0, 1)

local poseur = sprites.CreateSprite("poseur.png", global:GetVariable("LAYER"))
poseur.isBullet = true
poseur.rotation = 30

--local bul = sprites.CreateSprite("px.png", global:GetVariable("LAYER"))
--bul:Scale(5, 200)
--bul:MoveTo(320, 320)
--bul.color = {1, 0, 0}
--bul.isBullet = true

function wave.update(dt)
    mask:Follow(Arena.black)
    poseur.rotation = poseur.rotation + 2
    poseur:Scale(
        1 + 0.5 * math.sin(love.timer.getTime() * 3),
        1 + 0.5 * math.sin(love.timer.getTime() * 5)
    )

    if (keyboard.GetState("J") == 1) then
        Player.hp = Player.maxhp
    end

    for i = #wave.objects, 1, -1 do
        local obj = wave.objects[i]
        if (obj.logic) then
            obj:logic(dt)
        end
    end
end

function wave.draw()
end

return wave