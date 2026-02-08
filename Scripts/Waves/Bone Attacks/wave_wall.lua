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

local bones = require("Scripts.Libraries.Attacks.Bones")
local time = 0
local mask = masks.New("rectangle", 320, 320, 155, 130, 0, 1)

function wave.update(dt)
    mask:Follow(Arena.black)
    bones:Update()

    time = time + 1

    if (time == 60) then
        local wall = bones:Wall(Arena, "Sans", 40, 30, 10, "left", 10, 13, {
            In = "SineOut",     Out = "BackIn",
            It = 15,            Ot  = 60
        })
        wall:SetStencils({mask})
        table.insert(wave.objects, wall)
        local wall = bones:Wall(Arena, "Sans", 40, 30, 10, "right", 10, 13, {
            In = "SineOut",     Out = "BackIn",
            It = 15,            Ot  = 60
        })
        wall:SetStencils({mask})
        table.insert(wave.objects, wall)
        local wall = bones:Wall(Arena, "Sans", 40, 30, 10, "up", 10, 13, {
            In = "SineOut",     Out = "BackIn",
            It = 15,            Ot  = 60
        })
        wall:SetStencils({mask})
        table.insert(wave.objects, wall)
        local wall = bones:Wall(Arena, "Sans", 40, 30, 50, "down", 10, 13, {
            In = "SineOut",     Out = "BackIn",
            It = 15,            Ot  = 60
        })
        wall:SetStencils({mask})
        table.insert(wave.objects, wall)
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