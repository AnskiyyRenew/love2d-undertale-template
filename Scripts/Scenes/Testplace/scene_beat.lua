-- This is a template for creating a new scene in the game.
-- You can use this as a starting point for your own scenes.
local SCENE = {}

local mus, ins = audio.PlayMusic("mus_options_winter.ogg", 1.0, true)
local Beat = require("Scripts.Libraries.Beat")

function setupBasicBeatTracking()
    Beat.SetBPM(140)

    Beat.RegisterEvent("beat", function(current_beat)
        local beat_sound = current_beat % 4 == 1 and "metronome_high.wav" or "metronome_low.wav"
        audio.PlaySound("Beats/" .. beat_sound, 1.0, false)
        print(string.format("第 %d 拍触发！", current_beat))
    end)

    Beat.RegisterEvent("reset", function(beat)
        print(string.format("节拍重置至：%.2f", beat))
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
    Beat.Update(dt)
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
