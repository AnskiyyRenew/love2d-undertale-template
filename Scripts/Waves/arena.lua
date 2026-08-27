local wave = ImportFile("Battle.Waves")
local EndWave = wave.EndWave
local Arena = Battle.mainarena
Arena.target.rotation = 0
Player.canMove = true
Player.SetSoul(6)

Arenas.New("minus", "rectangle", 320, 420, 50, 150, 0)
local mask = Masks.New("rectangle", 320, 320, 155, 130, 0, 0)

local time = 0
function wave.Update(dt)
    mask:Follow(Arena.black)
    --print(Player.sprite.speed.x, Player.sprite.speed.y, Player.sprite.is_moving)

    time = time + 1
    if (time == 120) then
        --EndWave()
    end
end

return wave