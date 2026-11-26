local wave = ImportFile("Battle.Waves")
local EndWave = wave.EndWave
local Arena = Battle.mainarena
Player.canMove = true

local mask = Masks.New("rectangle", 320, 320, 155, 130, 0, 0)

local time = 0
--- Runs once per frame while the wave is active; keeps the mask on the arena.
---@param dt number Delta time in seconds.
function wave.Update(dt)
    mask:Follow(Arena.black)

    time = time + 1
end

return wave