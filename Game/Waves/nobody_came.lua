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
    --- Repositions the text for English glyphs.
    engfunc = function()
        text.scale = 0.5
        text.pos.offset[1] = text.pos.offset[1] + 0
        text.pos.relative[1] = 4
        text.pos.relative[2] = 0
    end,
    --- Repositions the text for non-English glyphs.
    non_engfunc = function()
        text.scale = 1
        text.pos.offset[1] = text.pos.offset[1] + 2
        text.pos.relative[1] = 4
        text.pos.relative[2] = 4
    end
})
--- Ends the battle once the dialogue has finished typing.
text._onComplete = function ()
    Battle._end = true
end

local time = 0
--- Keeps the mask on the arena and advances the wave timer each frame.
---@param dt number Delta time in seconds.
function wave.Update(dt)
    mask:Follow(Arena.black)

    time = time + 1
    if (time == 680) then
    end
end

return wave