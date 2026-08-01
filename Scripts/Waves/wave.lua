local wave = ImportFile("Battle.Waves")
local EndWave = wave.EndWave
local Arena = Battle.mainarena
local bones = wave.Import("Attacks.Bones")
Player.canMove = true

local mask = Masks.New("rectangle", 320, 320, 155, 130, 0, 0)

local bullet = Sprites.CreateSprite("bullet.png", "Bullets")
bullet:Scale(4, 4)
bullet:MoveTo(math.random(220, 420), math.random(240, 400))
bullet:SetStencils({mask})
bullet.isBullet = true
table.insert(wave.objects, bullet)

local time = 0
function wave.Update(dt)
    bones.Update(dt)
    mask:Follow(Arena.black)

    time = time + 1
    if (time == 680) then
        EndWave()
    end
end

return wave