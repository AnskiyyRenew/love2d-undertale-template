local wave = ImportFile("Battle.Waves")
local EndWave = wave.EndWave
local Arena = Battle.mainarena
Player.canMove = true

local mask = Masks.New("rectangle", 320, 320, 155, 130, 0, 0)

local time = 0
function wave.Update(dt)
    mask:Follow(Arena.black)

    time = time + 1
    if (time == 680) then
        -- EndWave()
    end
end

return wave