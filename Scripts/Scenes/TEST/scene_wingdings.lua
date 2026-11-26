--- Visual test of Wingdings.ttf in three forms: default bondfont, UseBondFont with eng + non-eng = Wingdings, and an inline [font:...] tag.

local scene = {}
local SAMPLE = "GOT YOU BOTH.\nSTILL DARING TO WRITE\nNONSENSE ON THE BOARD."

local e1 = Typers.EText.New(SAMPLE, {60, 60}, "GUI")
e1.voices = {}

local e2 = Typers.EText.New(SAMPLE, {60, 210}, "GUI")
e2.voices = {}
e2:UseBondFont({
    engfont     = { font = "Wingdings.ttf", size = 27 },
    non_engfont = { font = "Wingdings.ttf", size = 27 },
    engfunc     = function() end,
    non_engfunc = function() end,
})

local e3 = Typers.EText.New("[font:Wingdings.ttf]" .. SAMPLE, {60, 360}, "GUI")
e3.voices = {}

local label_font = Fonts.New("determination_mono.ttf", 14, "mono")
label_font:setFilter("nearest", "nearest")

local labels = {
    "1) baseline  (determination_mono.ttf)",
    "2) UseBondFont eng+non = Wingdings.ttf",
    "3) inline [font:Wingdings.ttf]",
}

local done = false

function scene.update(dt)
    if (not done and Controller.GetState("confirm") == 1) then
        pcall(function() e1:Destroy() end)
        pcall(function() e2:Destroy() end)
        pcall(function() e3:Destroy() end)
        done = true
        print("[scene_wingdings] cleared typers (press F5 / F2 to switch rooms).")
    end
end

function scene.draw()
    SE.graphics.setFont(label_font)
    SE.graphics.setColor(0.85, 0.85, 0.9, 1)
    for i, text in ipairs(labels) do
        SE.graphics.print(text, 60, 30 + (i - 1) * 150)
    end
    SE.graphics.setColor(0.5, 0.5, 0.55, 1)
    SE.graphics.print("Z/Enter xN clears the typers | F5 reload | F8 DevTool", 60, 462)
end

function scene.clear()
    pcall(function() e1:Destroy() end)
    pcall(function() e2:Destroy() end)
    pcall(function() e3:Destroy() end)
    Layers.clear()
end

return scene
