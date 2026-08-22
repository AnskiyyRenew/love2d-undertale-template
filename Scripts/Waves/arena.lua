local wave = ImportFile("Battle.Waves")
local EndWave = wave.EndWave
local Arena = Battle.mainarena
Player.canMove = true
Arena:SetThickness(5)

local mask = Masks.New("rectangle", 320, 320, 155, 130, 0, 0)

local logic_table = {
    {"q", function ()
        Arena:Resize(Arena.width + 10, Arena.height + 10)
    end},
    {"w", function ()
        Arena:Resize(Arena.width - 10, Arena.height - 10)
    end},
    {"e", function ()
        Arena:MoveTo(Keyboard.GetMousePosition())
    end},
    {"r", function ()
        Arena:Resize(155, 130)
        Arena:MoveTo(320, 320)
    end},

    {"i", function ()
        Arena:UpSide(40)
    end},
    {"k", function ()
        Arena:DownSide(40)
    end},
    {"j", function ()
        Arena:LeftSide(20)
    end},
    {"n", function ()
        Arena:LeftSide(-20)
    end},
    {"l", function ()
        Arena:RightSide(20)
    end},
    {"m", function ()
        Arena:RightSide(-20)
    end},
}

local time = 0
function wave.Update(dt)
    mask:Follow(Arena.black)
    --print(Player.sprite.speed.x, Player.sprite.speed.y, Player.sprite.is_moving)

    for i = 1, #logic_table
    do
        local l = logic_table[i]
        if (Keyboard.GetState(l[1]) == 1) then
            Camera:shake(3, 30)
            l[2]()
        end
    end

    time = time + 1
    if (time == 680) then
        -- EndWave()
    end
end

return wave