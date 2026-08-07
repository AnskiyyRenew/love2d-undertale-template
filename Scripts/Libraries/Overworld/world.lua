local world = {}

world.interactions = {
    can_interact = false,
    current_object = nil,
    current_id = 0,
    current_obj = nil,
    -- Every object the player is currently touching (used by getTouchResult).
    touching = {},
}

-- Check whether one side of a contact is the player ("oworld.char") and the
-- other side is the given object type (warp / chest / sign / save / trigger).
local function isPlayerCollision(dataA, dataB, objectType)
    return (dataA and dataA.type == "oworld.char" and dataB and dataB.type == objectType) or
           (dataB and dataB.type == "oworld.char" and dataA and dataA.type == objectType)
end

-- When the oworld.char is colliding with an object, remember its type and id.
local function handleInteraction(dataA, dataB, objectType)
    world.interactions.can_interact = true
    world.interactions.current_object = objectType
    -- Keep a reference to the collided object so callers can read its properties
    -- (e.g. getInteractResult(obj_type, value, "rr")).
    local obj = dataA.object or dataB.object
    world.interactions.current_obj = obj
    if (dataA.type == objectType) then world.interactions.current_id = dataA.id end
    if (dataB.type == objectType) then world.interactions.current_id = dataB.id end

    -- Track the object in the multi-touch list so getTouchResult can see all of
    -- them at once. Deduplicate: the same object may fire beginContact more
    -- than once, so only add it if it isn't already in the list.
    local found = false
    for i = 1, #world.interactions.touching do
        if (world.interactions.touching[i].object == obj) then
            found = true
            break
        end
    end
    if (not found) then
        table.insert(world.interactions.touching, {
            type = objectType,
            id = world.interactions.current_id,
            object = obj,
        })
    end

    if (Overworld and Overworld.debug) then
        print("Player collided with " .. objectType)
        print(dataA.id or dataB.id)
    end
end

-- When the oworld.char stops colliding with an object, remove it from the
-- touched list. If the player still touches other objects, keep the first one
-- as the "current" interaction so getInteractResult keeps working.
local function clearInteraction(dataA, dataB, objectType)
    local obj = dataA.object or dataB.object
    for i = #world.interactions.touching, 1, -1 do
        local t = world.interactions.touching[i]
        if (t.object == obj and t.type == objectType) then
            table.remove(world.interactions.touching, i)
            break
        end
    end

    if (#world.interactions.touching == 0) then
        world.interactions.current_id = 0
        world.interactions.current_object = nil
        world.interactions.current_obj = nil
        world.interactions.can_interact = false
    else
        local t = world.interactions.touching[1]
        world.interactions.current_object = t.type
        world.interactions.current_id = t.id
        world.interactions.current_obj = t.object
        world.interactions.can_interact = true
    end
end

-- beginContact: the player started touching an object.
local function beginContact(a, b)
    if (not a or not b) then return end
    local fixtureA, fixtureB = a, b
    local dataA = fixtureA:getUserData() or {}
    local dataB = fixtureB:getUserData() or {}

    local interactionTypes = {"warp", "chest", "sign", "save", "trigger"}
    for _, objType in ipairs(interactionTypes) do
        if (isPlayerCollision(dataA, dataB, objType)) then
            handleInteraction(dataA, dataB, objType)
            break
        end
    end
end

-- endContact: the player stopped touching an object.
local function endContact(a, b)
    if (not a or not b) then return end
    local dataA = a:getUserData() or {}
    local dataB = b:getUserData() or {}

    local clearTypes = {"warp", "chest", "sign", "save", "trigger"}
    for _, objType in ipairs(clearTypes) do
        if (isPlayerCollision(dataA, dataB, objType)) then
            clearInteraction(dataA, dataB, objType)
            break
        end
    end
end

---Create the physics world and register the collision callbacks.
function world.Init()
    if (world.physics_world and not world.physics_world:isDestroyed()) then
        return
    end

    world.physics_world = SE.physics.newWorld(0, 0, true)
    world.physics_world:setCallbacks(beginContact, endContact)

    world.interactions = {
        can_interact = false,
        current_object = nil,
        current_id = 0,
        current_obj = nil,
        touching = {},
    }
end

---Step the physics world. Called every frame from map.Update.
function world.Update(dt)
    if (world.physics_world and not world.physics_world:isDestroyed()) then
        world.physics_world:update(dt)
    end
end

---Destroy the physics world (and every body/fixture inside it).
function world.Destroy()
    if (world.physics_world and not world.physics_world:isDestroyed()) then
        world.physics_world:destroy()
    end
    world.physics_world = nil

    world.interactions = {
        can_interact = false,
        current_object = nil,
        current_id = 0,
        current_obj = nil,
        touching = {},
    }
end

return world
