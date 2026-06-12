-- This is a template for creating a new scene in the game.
-- You can use this as a starting point for your own scenes.
local SCENE = {}

local function NewCutscene(path, duration, text, options)
  options = options or {}
  return {
    path = path or "default.png",
    duration = duration or 3.0,
    text = text or "undefined",
    onDisplayStart = options.onDisplayStart,
    onUpdate = options.onUpdate
  }
end

local cutscenes = {
  NewCutscene("Cutscene/spr_introimage_0.png", 7.0,
    "[space:1, 2][space:2, 4][speed:0.95][voice:uifont.wav]Long ago, [wait:30]two races\nruled over Earth:\n[wait:30]HUMANS and MONSTERS."
  ),
  NewCutscene("Cutscene/spr_introimage_1.png", 3.0,
    "[space:1, 2][space:2, 4][speed:0.95][voice:uifont.wav]We all know what\nhappened next.[wait:30]\nSo..."
  ),
  NewCutscene("Cutscene/spr_introlast_0.png", 4.2, "", {
    onDisplayStart = function(cutscene, sprite)
      sprite:MoveTo(320, -100)
      tween.CreateTween(
        function(value)
          sprite:MoveTo(320, value)
        end,
        "linear", "", 440, -50, 60 * 4.2
      )
    end,

    onUpdate = function(dt, cutscene, sprite)
    end
  })
}

local fade = 1.0

--
local current_index = 1

local sprite = sprites.CreateSprite(cutscenes[current_index].path, 0)
sprite:Scale(2, 2)

local t = typers.CreateText(cutscenes[current_index].text, { 118, 319 }, 1.1, { 0, 0 }, "none")

local mask = masks.New("rectangle", 320, 170, 400, 220, 0)
sprite:SetStencils({ mask })

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
  local first_scene = cutscenes[current_index]
  if first_scene and first_scene.onDisplayStart then
    first_scene.onDisplayStart(first_scene, sprite)
  end
end

-- This function is called to update the scene.
local timer = 0
local state = "display"

function SCENE.update(dt)
  -- Update any game logic for this scene here.
  -- For example, you might update animations, handle input, etc.
  if state == "finished" then
    return
  end

  timer = timer + dt;

  local current_cutscene = cutscenes[current_index]

  if current_cutscene and current_cutscene.onUpdate then
    current_cutscene.onUpdate(dt, current_cutscene, sprite)
  end

  if state == "fade_in" then
    sprite.alpha = math.min(timer / fade, 1.0)

    if timer >= fade then
      timer = 0
      state = "display"
    end
  elseif state == "display" then
    sprite.alpha = 1.0

    if timer >= current_cutscene.duration then
      timer = 0
      state = "fade_out"
      t:SetText("")
    end
  elseif state == "fade_out" then
    sprite.alpha = 1.0 - math.min(timer / fade, 1.0)

    if timer >= fade then
      timer = 0
      current_index = current_index + 1

      if current_index <= #cutscenes then
        local next_cutscene = cutscenes[current_index]

        sprite:Set(next_cutscene.path)
        t:SetText(next_cutscene.text)
        state = "fade_in"

        if next_cutscene.onDisplayStart then
          next_cutscene.onDisplayStart(next_cutscene, sprite)
        end
      else
        state = "finished"
        scenes.switchTo("scene_logo")
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
