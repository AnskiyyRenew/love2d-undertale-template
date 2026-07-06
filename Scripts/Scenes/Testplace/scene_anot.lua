local size = 13
local SIZE_HEAD = "[fontSize:" .. size .. "]"
local DIALOGUE_HEAD = "[pattern:chinese][font:方正少儿简体.ttf]"
local pst = typers.CreateText({
    SIZE_HEAD .. DIALOGUE_HEAD .. "你好"
}, { 50, 80 }, 200, { 200, 100 }, "manual")

local sprs = {}
local y = 200
local x = 20
for i = 1, 20
do
    if i > 10 then y = 300 end
    if i == 10 then x = 20 end
    local spr = sprites.CreateSprite("bullet.png", 0 + i)
    spr:MoveTo(x, y)
    x = x + 40
    spr:Scale(0.5 + i * 0.1, 0.5 + i * 0.1)
    sprs[i] = spr
end

-- This is a template for creating a new scene in the game.
-- You can use this as a starting point for your own scenes.
local SCENE = {}

-- This is a fake scene for testing purposes.
function SCENE.load()
    -- Load any resources needed for this scene here.
    -- For example, you might load images, sounds, etc.
end

-- This function is called to update the scene.
function SCENE.update(dt)
    -- Update any game logic for this scene here.
    -- For example, you might update animations, handle input, etc.

    for i = 1, #sprs do
        sprs[i].rotation = sprs[i].rotation + 1
    end

    if (keyboard.GetState("left") == 1) then
        size = size - 1
        SIZE_HEAD = "[fontSize:" .. size .. "]"
        pst:SetText(SIZE_HEAD .. DIALOGUE_HEAD .. "你好")
    elseif (keyboard.GetState("right") == 1) then
        size = size + 1
        SIZE_HEAD = "[fontSize:" .. size .. "]"
        pst:SetText(SIZE_HEAD .. DIALOGUE_HEAD .. "你好")
    end
    print("Font Size:" .. size)
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