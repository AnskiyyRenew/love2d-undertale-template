-- This is a template for creating a new scene in the game.
-- You can use this as a starting point for your own scenes.
local SCENE = {}

local mus, ins = audio.PlayMusic("mus_options_winter.ogg", 1.0, true)
local beat = require("Scripts.Libraries.Beat")

local beat_t = typers.DrawText("Beat", { 0, 200 }, 1)
local bar_t = typers.DrawText("Bar", { 0, 280 }, 1)

function setupBasicBeatTracking()
    beat.SetBPM(140)

    beat.RegisterEvent("beat", function(current_beat)
        local beat_sound = current_beat % 4 == 1 and "metronome_high.wav" or "metronome_low.wav"
        audio.PlaySound("Beats/" .. beat_sound, 1.0, false)
        print(string.format("Triggered on the %d beat!", current_beat))
    end)

    beat.RegisterEvent("reset", function(beat)
        print(string.format("Beat reset to: %.2f", beat))
    end)
end

-- This is a fake scene for testing purposes.
function SCENE.load()
    -- Load any resources needed for this scene here.
    -- For example, you might load images, sounds, etc.
end

setupBasicBeatTracking()
-- This function is called to update the scene.
function SCENE.update(dt)
    -- Update any game logic for this scene here.
    -- For example, you might update animations, handle input, etc.
    beat.Update(dt)
    local int, frac = beat.GetBeat()

    beat_t:SetText("beat --- int: " .. int .. "; frac: " .. frac)

    local b, bb, b_frac = beat.GetBar()
    bar_t:SetText("bar: " .. b .. "." .. bb .. " --- " .. b_frac)
end

-- This function is called to draw the scene.
-- It is called after the main game loop has finished updating.
function SCENE.draw()
    -- Draw the scene here.
    -- For example, you might draw images, text, etc.
end

-- This function is called when the scene is switched away from.
function SCENE.clear()
    -- Clear any resources used by this scene here.
    -- For example, you might unload images, sounds, etc.
    layers.clear()
end

-- Don't touch this(just one line).
return SCENE
