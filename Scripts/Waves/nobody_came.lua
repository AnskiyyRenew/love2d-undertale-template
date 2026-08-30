local wave = ImportFile("Battle.Waves")
local EndWave = wave.EndWave
local Arena = Battle.mainarena
Player.canMove = false
Player.sprite.visible = false
Arena:Resize(565, 130)

local mask = Masks.New("rectangle", 320, 320, 155, 130, 0, 0)
local text = Typers.EText.New(Localize.localizeText("Overworld.Text.NobodyCame"), {60, 270}, "UponArena")
text:UseBondFont({
    engfont = {font = "determination_mono.ttf", size = 27},
    non_engfont = {font = "simsun.ttc", size = 13},
    engfunc = function()
        text.scale = 0.5
        text.pos.offset[1] = text.pos.offset[1] + 0
        text.pos.relative[1] = 4
        text.pos.relative[2] = 0
    end,
    non_engfunc = function()
        text.scale = 1
        text.pos.offset[1] = text.pos.offset[1] + 2
        text.pos.relative[1] = 4
        text.pos.relative[2] = 4
    end
})
text._onComplete = function ()
    Battle._end = true
end

local time = 0
function wave.Update(dt)
    mask:Follow(Arena.black)

    time = time + 1
    if (time == 680) then
        -- EndWave()
    end
end

return wave