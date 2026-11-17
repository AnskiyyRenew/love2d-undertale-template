--[[
    Visual test for typer mask (stencil) and shader support.
    Blocks 2 / 4 clip the text to a moving rect, 3 / 4 are desaturated,
    5 is an EText dialogue typer with WaveDistort.
    Run: set Global "FirstRoom" to "TEST.scene_typerfx".
]]

local scene = {}

local SAMPLE = "CLIPPED BY A MOVING MASK"

-- 1) baseline
local plain = Typers.InstText.New(SAMPLE, {320, 70}, 0)
plain:SetAlign("center")

-- 2) mask only
local clipped = Typers.InstText.New(SAMPLE, {320, 140}, 0)
clipped:SetAlign("center")
local box = Masks.New("rectangle", 320, 140, 150, 34, 0, 0)
clipped:SetStencils({box})

-- 3) shader only
local gray = ImportFile("ColorFilter", "shader")
gray:send("grayscale", 1)
gray:send("tint_color", {0.7, 0.8, 1})

local shaded = Typers.InstText.New(SAMPLE, {320, 210}, 0)
shaded:SetAlign("center")
shaded:SetShaders({gray})

-- 4) both
local combined = Typers.InstText.New(SAMPLE, {320, 280}, 0)
combined:SetAlign("center")
local box2 = Masks.New("rectangle", 320, 280, 150, 34, 0, 0)
combined:SetShaders({gray})
combined:SetStencils({box2})

-- 5) dialogue typer
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
