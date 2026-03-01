-- This is a template for creating a new scene in the game.
-- You can use this as a starting point for your own scenes.
local SCENE = {}

-- This is a fake scene for testing purposes.
function SCENE.load()
    -- Load any resources needed for this scene here.
    -- For example, you might load images, sounds, etc.
end

local mask1 = masks.New("rectangle", 320, 240, 400, 400, 0)

local shader = love.graphics.newShader("Scripts/Shaders/gradient")
shader:send("color_tl", {1, 0, 1, 0.3})
shader:send("color_tr", {1, 1, 1, 1})
shader:send("color_br", {1, 1, 1, 1})
shader:send("color_bl", {1, 1, 1, 1})

local typ = typers.DrawText("This is a sentence", {320, 240}, 1)
typ:SetStencils({mask1})
typ:SetShaders({shader})

-- This function is called to update the scene.
function SCENE.update(dt)
    -- Update any game logic for this scene here.
    -- For example, you might update animations, handle input, etc.

    mask1.x, mask1.y = keyboard.GetMousePosition()
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