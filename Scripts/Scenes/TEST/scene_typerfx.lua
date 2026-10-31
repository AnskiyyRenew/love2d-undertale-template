--[[
    Scripts/Scenes/TEST/scene_typerfx.lua
    Visual check for the typer mask (stencil) and shader support.

    Five blocks, top to bottom:
      1) InstText, no effects            - baseline, must look untouched
      2) InstText + SetStencils({rect})  - text is clipped to a moving rectangle
      3) InstText + SetShaders({Gray})   - whole block desaturated, one surface
      4) InstText + mask + shader        - both at once
      5) EText + SetShaders({Wave})      - dialogue typer, animated wave

    Run: in Engine/PureConf.lua uncomment
      --Global.SetVariable("FirstRoom", "TEST.scene_typerfx")
    then start the game.

    Expected: block 2 only shows the part of the text inside the moving box;
    block 3 is grey while the others stay white; block 4 does both; block 5
    ripples as it types. Blocks 1, 2 and 4 keep crisp pixel glyphs (the glyphs
    are baked 1:1, so nothing should blur or shift by a pixel).
]]

local scene = {}

local SAMPLE = "CLIPPED BY A MOVING MASK"

-- ------------------------------------------------------------------ 1) baseline
local plain = Typers.InstText.New(SAMPLE, {320, 70}, 0)
plain:SetAlign("center")

-- ------------------------------------------------------------------ 2) mask only
local clipped = Typers.InstText.New(SAMPLE, {320, 140}, 0)
clipped:SetAlign("center")
local box = Masks.New("rectangle", 320, 140, 150, 34, 0, 0)
clipped:SetStencils({box})

-- ------------------------------------------------------------------ 3) shader only
local gray = ImportFile("ColorFilter", "shader")
gray:send("grayscale", 1)
gray:send("tint_color", {0.7, 0.8, 1})

local shaded = Typers.InstText.New(SAMPLE, {320, 210}, 0)
shaded:SetAlign("center")
shaded:SetShaders({gray})

-- ------------------------------------------------------------------ 4) both
local combined = Typers.InstText.New(SAMPLE, {320, 280}, 0)
combined:SetAlign("center")
local box2 = Masks.New("rectangle", 320, 280, 150, 34, 0, 0)
combined:SetShaders({gray})
combined:SetStencils({box2})

-- ------------------------------------------------------------------ 5) dialogue typer
local wave = ImportFile("WaveDistort", "shader")
wave:send("time", 0)
wave:send("amplitude", 0.06)
wave:send("frequency", 0.08)
wave:send("speed", 2)
wave:send("tex_size", {320, 40})

local dialog = Typers.EText.New("&A WAVE OVER DIALOGUE TEXT", {150, 380}, 0)
dialog.voices = {}
dialog:SetShaders({wave})

local label_font = Fonts.New("determination_mono.ttf", 14, "mono")
label_font:setFilter("nearest", "nearest")

local labels = {
    "1) InstText baseline",
    "2) InstText + SetStencils (moving rect)",
    "3) InstText + SetShaders (ColorFilter)",
    "4) InstText + both",
    "5) EText + SetShaders (WaveDistort)",
}

local time = 0
local done = false

function scene.update(dt)
    time = time + dt

    -- Swing both masks across the text so the clipping is obvious.
    box.x = 320 + math.sin(time * 1.6) * 220
    box2.x = 320 + math.sin(time * 1.6 + math.pi) * 220

    wave:send("time", time)
end

function scene.draw()
    SE.graphics.setFont(label_font)
    SE.graphics.setColor(0.85, 0.85, 0.9, 1)
    for i, text in ipairs(labels) do
        SE.graphics.print(text, 20, 8 + (i - 1) * 66)
    end
    SE.graphics.setColor(0.5, 0.5, 0.55, 1)
    SE.graphics.print("F5 reload | F8 DevTool", 20, 462)
end

function scene.clear()
    pcall(function() plain:Destroy() end)
    pcall(function() clipped:Destroy() end)
    pcall(function() shaded:Destroy() end)
    pcall(function() combined:Destroy() end)
    pcall(function() dialog:Destroy() end)
    Layers.clear()
end

return scene
