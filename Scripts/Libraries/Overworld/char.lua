local path = (...):match("(.-)[^%.]+$")
local world = require(path .. "world")

local char = {
    sprites = {
        up = {
            "Overworld/Frisk/spr_f_maincharau_0.png",
            "Overworld/Frisk/spr_f_maincharau_1.png",
            "Overworld/Frisk/spr_f_maincharau_2.png",
            "Overworld/Frisk/spr_f_maincharau_3.png",
        },
        down = {
            "Overworld/Frisk/spr_f_maincharad_0.png",
            "Overworld/Frisk/spr_f_maincharad_1.png",
            "Overworld/Frisk/spr_f_maincharad_2.png",
            "Overworld/Frisk/spr_f_maincharad_3.png",
        },
        left = {
            "Overworld/Frisk/spr_f_maincharal_0.png",
            "Overworld/Frisk/spr_f_maincharal_1.png",
            "Overworld/Frisk/spr_f_maincharal_0.png",
            "Overworld/Frisk/spr_f_maincharal_1.png",
        },
        right = {
            "Overworld/Frisk/spr_f_maincharar_0.png",
            "Overworld/Frisk/spr_f_maincharar_1.png",
            "Overworld/Frisk/spr_f_maincharar_0.png",
            "Overworld/Frisk/spr_f_maincharar_1.png",
        }
    },
    currentSprite = nil,
    direction = DATA.direction,
    animationFrame = 1,
    animationTime = 0,
    isMoving = false,
    -- Input is only read while this is true.
    controlling = true,
    -- Whether the Frisk Dance easter egg is enabled.
    friskdance = (Global and Global.GetVariable and Global.GetVariable("EnableFriskDance")) or false,
    frisk_dancing = false,
    -- Frisk Dance direction flip timer (UP <-> DOWN every 1/30s).
    friskDanceTime = 0,
    mainstate = "",
    collision = {
        body = nil,
        shape = nil,
        fixture = nil,
    },
    -- Spawn position in world coordinates (already *2 from the Tiled map).
    x = 0,
    y = 0,
}

local first_direction = ""
local d_pressing = false
local char_prevX, char_prevY = 0, 0
-- Last physics-body position, used to detect a player pressed against a wall.
local body_lastX, body_lastY = nil, nil
-- Tolerance (world units) when deciding whether the body moved between frames:
-- a resting contact jitters slightly, a walking player covers ~3.3 units.
local DANCE_STILL_EPS = 0.5

---Replace the whole sprite table.
---@param tab table
function char.SetPlayerSprites(tab)
    if (not tab) then return end
    char.sprites = tab
end

---Set the player's spawn position and (optionally) direction.
---@param x number
---@param y number
---@param direction string | nil
function char.SetPosition(x, y, direction)
    char.x = x or char.x
    char.y = y or char.y
    if (direction) then
        char.direction = direction
    end
end

--- Create the player's sprite and physics body. Call after the map is loaded.
function char.Init()
    world.Init()

    char.Destroy()

    char.currentSprite = Sprites.CreateSprite(char.sprites[char.direction][1], "Player")
    char.currentSprite:Scale(2, 2)
    char.currentSprite:MoveTo(char.x, char.y)
    print(char.currentSprite:GetPosition())

    char.collision.body = SE.physics.newBody(world.physics_world, char.x, char.y, "dynamic")
    char.collision.shape = SE.physics.newRectangleShape(char.collision.body, 38, 20)
    char.collision.shape:setDensity(1)
    char.collision.shape:setRestitution(0)
    -- Low friction so the player slides along sloped / diagonal walls. Box2D
    -- mixes contact friction as sqrt(player * wall), so both must stay low.
    char.collision.shape:setFriction(0.01)
    char.collision.shape:setUserData({type = "oworld.char"})
    char.collision.fixture = char.collision.shape
    char.collision.body:setFixedRotation(true)

    -- Reset the wall-blocked tracking for the fresh body.
    body_lastX, body_lastY = nil, nil
end

--- Remove the player's physics body and sprite.
function char.Destroy()
    if (char.collision.body and not char.collision.body:isDestroyed()) then
        char.collision.body:destroy()
    end
    char.collision.body = nil
    char.collision.shape = nil
    char.collision.fixture = nil

    if (char.currentSprite) then
        char.currentSprite:Destroy()
        char.currentSprite = nil
    end
end

--- Update the player: read input, move the body, follow the fixture and advance
--- the walk animation. Called every frame.
---@param dt number
function char.Update(dt)
    if (not char.currentSprite or not char.collision.body) then return end

    local velbodyx, velbodyy = 0, 0

    -- Detect whether the body stayed in place since last frame (wall contact).
    local bx, by = char.collision.body:getX(), char.collision.body:getY()
    local prevX, prevY = body_lastX, body_lastY
    body_lastX, body_lastY = bx, by
    local moved_x = (prevX == nil) or (math.abs(bx - prevX) > DANCE_STILL_EPS)
    -- Vertical stillness is what keeps the Frisk Dance alive.
    local moved_y = (prevY == nil) or (math.abs(by - prevY) > DANCE_STILL_EPS)
    local blocked = (not moved_x and not moved_y)

    if (char.controlling) then
        -- The first pressed direction is remembered until released, so reversing
        -- requires turning first.
        if (Controller.GetState(first_direction) <= 0) then
            first_direction = ""
        end

        if (Controller.GetState("left") > 0) then
            if (char.direction ~= "right") then velbodyx = -2 end
            if (first_direction == "" or not d_pressing) then
                char.direction = "left"
                first_direction = "left"
                d_pressing = true
            end
        end
        if (Controller.GetState("right") > 0) then
            if (char.direction ~= "left") then velbodyx = 2 end
            if (first_direction == "" or not d_pressing) then
                char.direction = "right"
                first_direction = "right"
                d_pressing = true
            end
        end
        if (Controller.GetState("up") > 0) then
            if (char.direction ~= "down") then velbodyy = -2 end
            if (first_direction == "" or not d_pressing) then
                char.direction = "up"
                first_direction = "up"
                d_pressing = true
            end
        end
        if (Controller.GetState("down") > 0) then
            if (char.direction ~= "up") then velbodyy = 2 end
            if (first_direction == "" or not d_pressing) then
                char.direction = "down"
                first_direction = "down"
                d_pressing = true
            end
        end

        local up_held = Controller.GetState("up") > 0
        local down_held = Controller.GetState("down") > 0
        local was_dancing = char.frisk_dancing
        if (char.friskdance and up_held and down_held) then
            -- Start: standing still while pushing up into a wall. Once started,
            -- the body must stay still on Y; sliding left/right is allowed.
            -- `velbodyy < 0` can only be required to start: while dancing the
            -- facing flips to "down" every other flip.
            char.frisk_dancing = (not moved_y) and (was_dancing or (blocked and velbodyy < 0))
        else
            char.frisk_dancing = false
        end
        if (was_dancing and not char.frisk_dancing) then
            -- Cancelled: stop the flip timer and face up again.
            char.direction = "up"
            char.friskDanceTime = 0
        end

        if (char.frisk_dancing) then
            -- Keep pushing up so the collision holds the body still on Y.
            velbodyy = -2
            Step.UpdateTime()
        end
    else
        if (char.frisk_dancing) then
            char.direction = "up"
        end
        char.frisk_dancing = false
    end

    char.currentSprite:MoveTo(
        char.collision.body:getX(),
        char.collision.body:getY() - 20
    )
    char.collision.body:setLinearVelocity(velbodyx * 100, velbodyy * 100)

    if (char.frisk_dancing) then
        -- Advance the walk frame and flip UP/DOWN every 1/30s; the body stays
        -- glued to the wall.
        char.animationTime = char.animationTime + dt
        if (char.animationTime >= 0.18) then
            char.animationFrame = char.animationFrame % #char.sprites[char.direction] + 1
            char.animationTime = 0
        end
        char.friskDanceTime = char.friskDanceTime + dt
        if (char.friskDanceTime >= (1 / 30)) then
            char.friskDanceTime = 0
            char.direction = (char.direction == "up") and "down" or "up"
        end
        char.isMoving = true
    elseif (velbodyx ~= 0 or velbodyy ~= 0) then
        char.animationTime = char.animationTime + dt
        if char.animationTime >= 0.18 then
            char.animationFrame = char.animationFrame % #char.sprites[char.direction] + 1
            char.animationTime = 0
        end
        if (char_prevX ~= char.currentSprite.x or char_prevY ~= char.currentSprite.y) then
            char_prevX = char.currentSprite.x
            char_prevY = char.currentSprite.y
            char.isMoving = true
            Step.UpdateTime()
        else
            char.isMoving = false
        end
    else
        char.isMoving = false
    end

    -- Only swap the texture while moving; otherwise stand idle on frame 1.
    if (char.isMoving) then
        char.currentSprite:Set(char.sprites[char.direction][char.animationFrame])
    elseif (char.animationFrame ~= 1) then
        char.animationFrame = 1
        char.currentSprite:Set(char.sprites[char.direction][1])
    end
end

return char
