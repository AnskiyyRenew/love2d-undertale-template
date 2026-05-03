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
snowball.velocity = { x = 0, y = 0 }

local function getCenter(rect)
    return rect.x + rect.width / 2, rect.y + rect.height / 2
end

local function intersectsAABB(ax, ay, aw, ah, bx, by, bw, bh)
    local aCenterX = ax + aw / 2
    local aCenterY = ay + ah / 2
    local bCenterX = bx + bw / 2
    local bCenterY = by + bh / 2

    return math.abs(aCenterX - bCenterX) * 2 < (aw + bw) and
        math.abs(aCenterY - bCenterY) * 2 < (ah + bh)
end

local function bounceAABB(ball, wall, nextX, nextY)
    if not intersectsAABB(nextX, nextY, ball.width, ball.height, wall.x, wall.y, wall.width, wall.height) then
        return nextX, nextY, false
    end

    local ballCenterX = nextX + ball.width / 2
    local ballCenterY = nextY + ball.height / 2
    local wallCenterX = wall.x + wall.width / 2
    local wallCenterY = wall.y + wall.height / 2

    local overlapX = (ball.width + wall.width) / 2 - math.abs(ballCenterX - wallCenterX)
    local overlapY = (ball.height + wall.height) / 2 - math.abs(ballCenterY - wallCenterY)

    if overlapX < overlapY then
        if ballCenterX < wallCenterX then
            nextX = wall.x - ball.width
        else
            nextX = wall.x + wall.width
        end
        snowball.velocity.x = -snowball.velocity.x
    else
        if ballCenterY < wallCenterY then
            nextY = wall.y - ball.height
        else
            nextY = wall.y + wall.height
        end
        snowball.velocity.y = -snowball.velocity.y
    end

    return nextX, nextY, true
end

function SCENE.load()
end

-- This function is called to update the scene.
function SCENE.update(dt)
    -- Update any game logic for this scene here.
    -- For example, you might update animations, handle input, etc.

    ow.Update(dt)
    local obj = ow.FindObject("triggers", "type", "snowball", true)
    if not obj then
        return
    end

    local centerX, centerY = getCenter(obj)
    snowball.layer = obj.y + 2000

    if (ow.getInteractResult("trigger", 1)) then
        -- Push the ball away from the player.
        local dx = centerX - ow.char.currentSprite.x
        local dy = centerY - (ow.char.currentSprite.y + 20)
        snowball._angle = math.atan2(dy, dx)
        snowball.velocity.x = math.cos(snowball._angle) * 10
        snowball.velocity.y = math.sin(snowball._angle) * 10
    end

    local nextX = obj.x + snowball.velocity.x
    local nextY = obj.y + snowball.velocity.y

    for _, wall in pairs(ow.objects.walls) do
        nextX, nextY = bounceAABB(obj, wall, nextX, nextY)
    end

    obj.x = nextX
    obj.y = nextY
    obj.body:setPosition(obj.x + obj.width / 2, obj.y + obj.height / 2)

    if (math.abs(snowball.velocity.x) > 0.1 or math.abs(snowball.velocity.y) > 0.1) then
        -- Friction
        snowball.velocity.x = snowball.velocity.x * 0.95
        snowball.velocity.y = snowball.velocity.y * 0.95
    else
        snowball.velocity.x = 0
        snowball.velocity.y = 0
    end

    local renderX, renderY = getCenter(obj)
    snowball:MoveTo(renderX, renderY)

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