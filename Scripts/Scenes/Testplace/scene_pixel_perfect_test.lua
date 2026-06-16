-- This is a template for creating a new scene in the game.
-- You can use this as a starting point for your own scenes.
local SCENE = {}

local SPR_ENEMY_TEST = sprites.CreateSprite("Cutscene/spr_charaphoto_0.png", -1)


local SPR_1X = sprites.CreateSprite("bullet.png", -1)
SPR_1X.y = 110

local SPR_2X = sprites.CreateSprite("bullet.png", -1)
SPR_2X.y = 160
SPR_2X:Scale(2, 2)

local SPR_MOVE = sprites.CreateSprite("bullet.png", -1)
SPR_MOVE.x = 200
SPR_MOVE.y = 110

local SPR_MOVE_2X = sprites.CreateSprite("bullet.png", -1)
SPR_MOVE_2X.x = 200
SPR_MOVE_2X.y = 160
SPR_MOVE_2X:Scale(2, 2)

local SPR_SCALE = sprites.CreateSprite("bullet.png", -1)
SPR_SCALE.x = 440
SPR_SCALE.y = 110

local SPR_SCALE_2X = sprites.CreateSprite("bullet.png", -1)
SPR_SCALE_2X.x = 440
SPR_SCALE_2X.y = 160
SPR_SCALE_2X:Scale(2, 2)

local beat_t = typers.DrawText("SRY but this image size \nhappens to be odd =)", { 50, 300 }, 1)
-- This is a fake scene for testing purposes.
function SCENE.load()
    -- Load any resources needed for this scene here.
    -- For example, you might load images, sounds, etc.
end

-- This function is called to update the scene.
function SCENE.update(dt)
    -- Update any game logic for this scene here.
    -- For example, you might update animations, handle input, etc.
    SPR_1X.rotation = SPR_1X.rotation + 1
    SPR_2X.rotation = SPR_1X.rotation

    local t = math.rad(SPR_1X.rotation)
    SPR_MOVE.x = 200 + math.sin(t) * 80
    SPR_MOVE_2X.x = SPR_MOVE.x
    SPR_SCALE.xscale = 1 + math.sin(t) * 0.6
    SPR_SCALE.yscale = SPR_SCALE.xscale
    SPR_SCALE_2X.xscale = 2 + math.sin(t) * 1.2
    SPR_SCALE_2X.yscale = SPR_SCALE_2X.xscale
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
