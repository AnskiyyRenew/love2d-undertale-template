--[[
    Scripts/Scenes/TEST/scene_wingdings.lua
    Visual check: three EText "typewriters" rendered side by side so you can confirm
    how Wingdings.ttf actually looks:

      1) baseline  : default bondfont (eng=determination_mono.ttf, non=simsun.ttc)
      2) WingBond  : UseBondFont with engfont AND non_engfont = Wingdings.ttf
      3) inline    : the original scene style "[font:Wingdings.ttf]..."

    Run: in Engine/PureConf.lua uncomment
      --Global.SetVariable("FirstRoom", "TEST.scene_wingdings")
    then start the game (or press Z a few times to clear the typers).

    Expected: if the bundled Wingdings.ttf maps ASCII letters to plain letter glyphs,
    line 2 and 3 will look like normal English letters (nearly identical to line 1),
    i.e. NOT the "symbol" wingding style.
]]

local scene = {}
local SAMPLE = "GOT YOU BOTH.\nSTILL DARING TO WRITE\nNONSENSE ON THE BOARD."

-- 1) baseline: default dialogue bondfont
local e1 = Typers.EText.New(SAMPLE, {60, 60}, "GUI")
e1.voices = {}

-- 2) WingBond: both eng & non-eng use Wingdings.ttf
local e2 = Typers.EText.New(SAMPLE, {60, 210}, "GUI")
e2.voices = {}
e2:UseBondFont({
    engfont     = { font = "Wingdings.ttf", size = 27 },
    non_engfont = { font = "Wingdings.ttf", size = 27 },
    engfunc     = function() end,
    non_engfunc = function() end,
})

-- 3) inline tag, mirroring the original scene usage
local e3 = Typers.EText.New("[font:Wingdings.ttf]" .. SAMPLE, {60, 360}, "GUI")
e3.voices = {}

local label_font = SE.graphics.newFont("Resources/Fonts/determination_mono.ttf", 14, "mono")
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
