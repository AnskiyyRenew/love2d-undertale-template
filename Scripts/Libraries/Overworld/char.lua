local path = (...):match("(.-)[^%.]+$")
local world = require(path .. "world")

local char = {
    -- Sprite frames for each walking direction.
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
        },
    },
    currentSprite = nil,
    direction = "right",
    animationFrame = 1,
    animationTime = 0,
    isMoving = false,
    -- Whether the player can move (input is read only while this is true).
    controlling = true,
    collision = {
        body = nil,
        shape = nil,
        fixture = nil,
    },
    -- Spawn position (world coordinates, i.e. already *2 from the Tiled map).
    x = 0,
    y = 0,
}

-- Movement state kept between frames.
local first_direction = ""
local d_pressing = false
local char_prevX, char_prevY = 0, 0

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

---Create the player's sprite and physics body. Call this after the map is
---loaded so the physics world exists and the spawn position is known.
function char.Init()
    -- Make sure the physics world exists.
    world.Init()

    -- Clean up any previous instance.
    char.Destroy()

    -- Create the player sprite.
    char.currentSprite = Sprites.CreateSprite(char.sprites[char.direction][1], "Player")
    char.currentSprite:Scale(2, 2)
    char.currentSprite:MoveTo(char.x, char.y)

    -- Player collision setup.
    char.collision.body = SE.physics.newBody(world.physics_world, char.x, char.y, "dynamic")
    char.collision.shape = SE.physics.newRectangleShape(char.collision.body, 38, 20)
    char.collision.shape:setDensity(1)
    char.collision.shape:setRestitution(0)
    char.collision.shape:setFriction(0.1)
    char.collision.shape:setUserData({type = "oworld.char"})
    char.collision.fixture = char.collision.shape
    char.collision.body:setFixedRotation(true)
end

---Remove the player's physics body and sprite.
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

---Update the player: read input, move the physics body, make the sprite
---follow the fixture and advance the walk animation. Called every frame.
---@param dt number
function char.Update(dt)
    if (not char.currentSprite or not char.collision.body) then return end

    local velbodyx, velbodyy = 0, 0
    if (char.controlling) then
        -- The first pressed direction is remembered until it is released,
        -- so reversing direction requires turning first.
        if (Keyboard.GetState(first_direction) <= 0) then
            first_direction = ""
        end

        if (Keyboard.GetState("left") > 0) then
            if (char.direction ~= "right") then velbodyx = -2 end
            if (first_direction == "" or not d_pressing) then
                char.direction = "left"
                first_direction = "left"
                d_pressing = true
            end
        end
        if (Keyboard.GetState("right") > 0) then
            if (char.direction ~= "left") then velbodyx = 2 end
            if (first_direction == "" or not d_pressing) then
                char.direction = "right"
                first_direction = "right"
                d_pressing = true
            end
        end
        if (Keyboard.GetState("up") > 0) then
            if (char.direction ~= "down") then velbodyy = -2 end
            if (first_direction == "" or not d_pressing) then
                char.direction = "up"
                first_direction = "up"
                d_pressing = true
            end
        end
        if (Keyboard.GetState("down") > 0) then
            if (char.direction ~= "up") then velbodyy = 2 end
            if (first_direction == "" or not d_pressing) then
                char.direction = "down"
                first_direction = "down"
                d_pressing = true
            end
        end
    end

    -- Make the sprite follow the fixture.
    char.currentSprite:MoveTo(
        char.collision.body:getX(),
        char.collision.body:getY() - 20
    )
    char.collision.body:setLinearVelocity(velbodyx * 100, velbodyy * 100)

    if (velbodyx ~= 0 or velbodyy ~= 0) then
        -- Walk animation.
        char.animationTime = char.animationTime + dt
        if char.animationTime >= 0.16 then
            char.animationFrame = char.animationFrame % #char.sprites[char.direction] + 1
            char.animationTime = 0
        end
        if (char_prevX ~= char.currentSprite.x or char_prevY ~= char.currentSprite.y) then
            char_prevX = char.currentSprite.x
            char_prevY = char.currentSprite.y
            char.isMoving = true
        else
            char.isMoving = false
        end
    else
        char.animationFrame = 1
        char.isMoving = false
    end

    char.currentSprite:Set(char.sprites[char.direction][char.animationFrame])
end

return char
