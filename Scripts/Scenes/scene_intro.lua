-- This is a template for creating a new scene in the game.
-- You can use this as a starting point for your own scenes.
local SCENE = {}


local function NewCutscene(path, duration, text)
  return {
    path = path or "default.png",
    duration = duration or 3.0,
    text = text or "undefined"
  }
end

local cutscenes = {
  NewCutscene("Cutscene/spr_introimage_0.png", 7.0,
    "[space:1, 2][space:2, 4][speed:0.95][voice:uifont.wav]Long ago, [wait:30]two races\nruled over Earth:\n[wait:30]HUMANS and MONSTERS."
  ),
  NewCutscene("Cutscene/spr_introimage_1.png", 3.5),
  NewCutscene("Cutscene/spr_introimage_2.png", 4.2)
}

local fade = 1.0

--

local cutscene = sprites.CreateSprite(cutscenes[1].path, 0)
cutscene:Scale(2, 2)

local t = typers.CreateText(cutscenes[1].text, { 118, 319 }, 1.1, { 0, 0 }, "none")

local mask = masks.New("rectangle", 320, 170, 400, 220, 0)
cutscene:SetStencils({ mask })

-- In the original Undertale assets,
-- the sprites at the end of the Pacifist Route (such as spr_asrielpanels_0.png) do not have black borders,
-- so their coordinates need to be adjusted as follows.
--
-- Uncomment below as needed
--
-- cutscene:MoveTo(320, 166)


-- This is a fake scene for testing purposes.
function SCENE.load()
  -- Load any resources needed for this scene here.
  -- For example, you might load images, sounds, etc.
end

-- This function is called to update the scene.
local timer = 0
local current_index = 1
local state = "display"

function SCENE.update(dt)
  -- Update any game logic for this scene here.
  -- For example, you might update animations, handle input, etc.
  if state == "finished" then
    return
  end

  timer = timer + dt;

  local current_data = cutscenes[current_index]

  if state == "fade_in" then
    cutscene.alpha = math.min(timer / fade, 1.0)

    if timer >= fade then
      timer = 0
      state = "display"
    end
  elseif state == "display" then
    cutscene.alpha = 1.0

    if timer >= current_data.duration then
      timer = 0
      state = "fade_out"
      t:SetText("")
    end
  elseif state == "fade_out" then
    cutscene.alpha = 1.0 - math.min(timer / fade, 1.0)

    if timer >= fade then
      timer = 0
      current_index = current_index + 1

      if current_index <= #cutscenes then
        cutscene:Set(cutscenes[current_index].path)
        t:SetText(cutscenes[current_index].text)
        state = "fade_in"
      else
        state = "finished"
      end
    end
  end
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
