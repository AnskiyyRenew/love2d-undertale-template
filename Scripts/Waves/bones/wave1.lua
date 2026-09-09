local wave = ImportFile("Battle.Waves")
local EndWave = wave.EndWave
local Arena = Battle.mainarena
Arena:Resize(130, 130)
Arena:RotateTo(10)

Player.canMove = true
Player.SetSoul(6)

local bones = wave.Import("Attacks.Bones")
local mask = Masks.New("rectangle", 320, 320, 155, 130, 0, 0)

local a = Arenas.New("minus", "rectangle", 320, 420, 60, 200, 0)
Border.FadeIn()

local time = 0
function wave.Update(dt)
    mask:Follow(Arena.black)
    bones.Update()

    if (Keyboard.GetState("k") == 1) then
        Player.action.Slam(0, 1, 10)
    end

    time = time + 1
    if (time == 30) then
        EndWave()
    end
end

return wave