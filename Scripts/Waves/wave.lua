local wave = ImportFile("Battle.Waves")
local EndWave = wave.EndWave
local Arena = Battle.mainarena
local bones = wave.Import("Attacks.Bones")
Player.canMove = true

local mask = Masks.New("rectangle", 320, 320, 155, 130, 0, 0)
local a = Arenas.New("minus", "rectangle", 320, 380, 50, 50, 0)
Player.SetSoul("blue")

local time = 0
function wave.Update(dt)
    bones.Update(dt)
    mask:Follow(Arena.black)

    time = time + 1
    if (time == 50) then
        EndWave()
    end
end

return wave