local wave = ImportFile("Battle.Waves")
local EndWave = wave.EndWave
local Arena = Battle.mainarena
Arena:Resize(130, 130)
--Arena:RotateTo(10)

Player.canMove = true
Player.SetSoul(6)

local bones = wave.Import("Attacks.Bones")
local mask = Masks.New("rectangle", 320, 320, 155, 130, 0, 0)

--local a = Arenas.New("minus", "rectangle", 320, 420, 60, 200, 0)
--Border.FadeIn(1)
local p = Player.BluePlatform(320, 350, 50)
--p.image.color = {0.3, 1, 0.3}

local time = 0
function wave.Update(dt)
    mask:Follow(Arena.black)
    bones.Update()

    if (Keyboard.GetState("k") == 1) then
        Player.action.SlamAuto(0, 1, 10)
    elseif (Keyboard.GetState("i") == 1) then
        Player.action.SlamAuto(180, 1, 10)
    end

    time = time + 1
    if (time == 90) then
        --EndWave()
    end
end

return wave