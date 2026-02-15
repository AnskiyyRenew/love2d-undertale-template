-- This is a template for creating a new scene in the game.
-- You can use this as a starting point for your own scenes.
local SCENE = {}

-- global:DeleteSaveVariable("Overworld")
-- global:DeleteSaveVariable("Flag")

-- _CAMERA_:setBounds(280 - 320, 300 - 240, 280 + 320, 300 + 240)
local ow = require("Scripts.Libraries.Overworld.InitWorld")
ow.InitMusic("mus_house1.ogg")
ow.Init("Maps/snowball.lua", "scene_ow_new")
ow.DEBUG = true
ow.ENCOUNTER = false
ow.InitEncounter(FLAG.ruins_killed, 80, 40, 3)
ow.SetBattleScene("Battle/scene_battle_ow")

local sign_checked = 1
local snowball = sprites.CreateSprite("Scene/Snowdin/spr_rollsnow_0.png", 0)
snowball:Scale(4, 4)
snowball._speed = 0
snowball._angle = 0

local function bounceAABB(ball, wall)
    local xx, yy = wall.body:getPosition()
    local dx = ball.x - xx
    local dy = ball.y - yy
    
    local overlapX = dx - math.abs(dx)
    local overlapY = dy - math.abs(dy)

    if overlapX < overlapY then
        snowball.velocity.x = -snowball.velocity.x
    else
        snowball.velocity.y = -snowball.velocity.y
    end
    
    if (
        math.abs(ball.x - wall.x) < (ball.width + wall.width) / 2 and
        math.abs(ball.y - wall.y) < (ball.height + wall.height) / 2
    ) then
        print("Collision detected between ball and wall!")
    end
end

function SCENE.load()
end

-- This function is called to update the scene.
function SCENE.update(dt)
    -- Update any game logic for this scene here.
    -- For example, you might update animations, handle input, etc.

    ow.Update(dt)
    local obj = ow.FindObject("triggers", "type", "snowball", true)
    local xx, yy = obj.body:getPosition()
    snowball.layer = obj.y + 2000

    print("Snowball position:", obj.x, obj.y)

    if (ow.getInteractResult("trigger", 1)) then
        -- Push the ball away from the player
        -- Infact, it's the snowball's object.
        local dx = obj.x - ow.char.currentSprite.x
        local dy = obj.y - (ow.char.currentSprite.y + 20)
        snowball._angle = math.atan2(dy, dx)
        snowball.velocity = {
            x = math.cos(snowball._angle) * 10,
            y = math.sin(snowball._angle) * 10
        }
    end

    for _, wall in pairs(ow.objects.walls) do
        local snowball_x, snowball_y = snowball:GetPosition()
        local wall_x, wall_y = wall.body:getPosition()
        print("Snowball position:", snowball_x, snowball_y)
        print("Wall position:", wall_x, wall_y)
        print("Snowball size:", obj.width, obj.height)
        print("Wall size:", wall.width, wall.height)


        if oworld.TwoObjectsInteract(obj, wall) then

            bounceAABB(obj, wall)
            print("bounce")
        end
    end


    obj.x = obj.x + snowball.velocity.x
    obj.y = obj.y + snowball.velocity.y
    obj.body:setPosition(obj.x, obj.y)
    if (math.abs(snowball.velocity.x) > 0.1 or math.abs(snowball.velocity.y) > 0.1) then
        -- Friction
        snowball.velocity.x = snowball.velocity.x * 0.95
        snowball.velocity.y = snowball.velocity.y * 0.95
    else
        snowball.velocity.x = 0
        snowball.velocity.y = 0
    end
    snowball:MoveTo(obj.x, obj.y)

    if (ow.NEXTSTATE ~= nil) then
        ow.CSTATE = ow.NEXTSTATE
        ow.NEXTSTATE = nil
    end
end

-- This function is called to draw the scene.
-- It is called after the main game loop has finished updating.
function SCENE.draw()
    -- Draw the scene here.
    -- For example, you might draw images, text, etc.
    ow.Draw()
end

-- This function is called when the scene is switched away from.
function SCENE.clear()
    -- Clear any resources used by this scene here.
    -- For example, you might unload images, sounds, etc.
    package.loaded["Scripts.Libraries.Overworld.InitWorld"] = nil

    layers.clear()
    ow.Destroy()
end

-- Don't touch this(just one line).
return SCENE