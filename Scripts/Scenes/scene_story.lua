-- This is a template for creating a new scene in the game.
-- You can use this as a starting point for your own scenes.
local SCENE = {}


local cutscene = sprites.CreateSprite("Cutscene/spr_introimage_0.png", 0)
cutscene:Scale(2, 2)

-- In the original Undertale assets,
-- the sprites at the end of the Pacifist Route (such as spr_asrielpanels_0.png) do not have black borders,
-- so their coordinates need to be adjusted as follows.
--
-- Uncomment below as needed
--
-- cutscene:MoveTo(320, 166)


local mask = masks.New("rectangle", 320, 170, 400, 220, 0)

cutscene:SetStencils({ mask })

local t = typers.CreateText({
  "[space:1, 2][space:2, 4][speed:0.95][voice:uifont.wav]Long ago, [wait:30]two races\nruled over Earth:\n[wait:30]HUMANS and MONSTERS."
}, { 118, 319 }, 1.1, { 0, 0 }, "manual")


-- This is a fake scene for testing purposes.
function SCENE.load()
  -- Load any resources needed for this scene here.
  -- For example, you might load images, sounds, etc.
end

-- This function is called to update the scene.
function SCENE.update(dt)
  -- Update any game logic for this scene here.
  -- For example, you might update animations, handle input, etc.
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
