local wave = ImportFile("Battle.Waves")
local EndWave = wave.EndWave
local Arena = Battle.mainarena
Player.canMove = true
Player.SetSoul(2)

local mask = Masks.New("rectangle", 320, 320, 155, 130, 0, 0)
local bullet = Sprites.CreateSprite("bullet.png", "Bullets")
bullet:Scale(4, 4)
bullet:MoveTo(320, 320)
bullet:SetStencils({mask})
bullet.isBullet = true
table.insert(wave.objects, bullet)

local time = 0
function wave.Update(dt)
    mask:Follow(Arena.black)
    --print(Player.sprite.speed.x, Player.sprite.speed.y, Player.sprite.is_moving)

    time = time + 1
    if (time == 120) then
        EndWave()
    end
end

return wave