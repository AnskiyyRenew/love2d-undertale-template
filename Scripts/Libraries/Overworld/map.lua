local path = (...):match("(.-)[^%.]+$")
local world = require(path .. "world")
local char = require(path .. "char")

local map = {
    current = "",
    char = char,
    _initialized = false,
    world = world,

    _debug_drawed = false,
    -- Runtime objects placed from the map layers (physics bodies + data).
    objects = {
        marks = {},
        triggers = {},
        walls = {},
        saves = {},
        signs = {},
        warps = {},
        chests = {},

        unknowns = {}
    },
    -- Raw Tiled objects, kept only for the debug drawer.
    debug_objects = {},
}
local debug_attris = {
    -- color, angle
    -- angle is a RELATIVE base angle (degrees); the final display rotation
    -- also adds the object's own `rotation` from the map.
    marks = {{0.5, 1, 1}, 45},
    triggers = {{0.3, 1, 0.3}, 0},
    walls = {{1, 0.3, 0.3}, 0},
    saves = {{1, 1, 0}, 45},
    signs = {{0.4, 0, 1}, 0},
    warps = {{1, 0, 1}, 0},
    chests = {{1, 0.5, 0}, 0},
    unknowns = {{0.5, 0, 0}, 0}
}
local obj_sprites = {}
local sti = ImportFile("STI")

---------------------------------------------------
-- Object layer handlers: place runtime objects + physics bodies.
---------------------------------------------------
local layerHandlers = {}

function layerHandlers.triggers(layer)
    local objects = map.objects.triggers

    for _, obj in ipairs(layer.objects) do
        local id = obj.properties.id or (#objects + 1)

        local body = SE.physics.newBody(
            world.physics_world,
            (obj.x + obj.width / 2) * 2,
            (obj.y + obj.height / 2) * 2,
            "kinematic"
        )

        local shape = SE.physics.newRectangleShape(body, obj.width * 2, obj.height * 2)
        -- The shape itself is the fixture in this engine.
        shape:setDensity(1)
        shape:setSensor(true)

        -- Runtime object entry; referenced from the fixture userData so the
        -- interaction system can read its properties (e.g. an "rr" key).
        local entry = {
            x = obj.x * 2,
            y = obj.y * 2,
            width = obj.width * 2,
            height = obj.height * 2,
            id = id,
            triggered = 0,
            properties = obj.properties,
            body = body,
            fixture = shape,
        }

        shape:setUserData({ type = "trigger", id = id, object = entry })

        table.insert(objects, entry)
    end
end

function layerHandlers.marks(layer)
    local objects = map.objects.marks

    for _, obj in ipairs(layer.objects) do
        local id = obj.properties.id or (#objects + 1)

        table.insert(objects, {
            x = (obj.x) * 2,
            y = (obj.y) * 2,
            direction = obj.properties.direction or "right",
            id = id,
            properties = obj.properties,
        })
    end
end

function layerHandlers.chests(layer)
    local objects = map.objects.chests

    for _, obj in ipairs(layer.objects) do
        local sprite = Sprites.CreateSprite("Scene/Everywhere/spr_chestbox_0.png", "BelowPlayer")
        sprite:MoveTo(
            (obj.x + obj.width / 2 ) * 2,
            (obj.y + obj.height / 2) * 2
        )
        sprite:Scale(2, 2)
        table.insert(obj_sprites, sprite)

        local id = obj.properties.id or (#objects + 1)
        local body = SE.physics.newBody(world.physics_world,
            (obj.x + obj.width / 2 ) * 2,
            (obj.y + obj.height / 2) * 2 + 10,
            "kinematic"
        )

        local shape = SE.physics.newRectangleShape(body, sprite.width * 2, sprite.height / 2 * 2)
        shape:setDensity(1)
        shape:setUserData({type = "chest", object = obj, id = id})

        table.insert(objects, {
            x = (obj.x + obj.width/2) * 2,
            y = (obj.y + obj.height/2) * 2,
            width = obj.width * 2,
            height = obj.height * 2,
            id = id,
            give = (obj.properties.give or false),
            properties = obj.properties,
            body = body,
            fixture = shape,
            sprite = sprite,
        })
    end
end

function layerHandlers.warps(layer)
    local objects = map.objects.warps

    for _, obj in ipairs(layer.objects) do
        local body = SE.physics.newBody(world.physics_world,
            (obj.x + obj.width/2) * 2,
            (obj.y + obj.height/2) * 2,
            "kinematic")
        local shape = SE.physics.newRectangleShape(body, obj.width * 2, obj.height * 2)
        shape:setDensity(1)
        shape:setSensor(true)
        shape:setUserData({type = "warp", object = obj, id = obj.properties.id})

        table.insert(objects, {
            x = (obj.x) * 2,
            y = (obj.y) * 2,
            width = obj.width * 2,
            height = obj.height * 2,
            id = obj.properties.id,
            properties = obj.properties,
            body = body,
            fixture = shape,
        })
    end
end

function layerHandlers.walls(layer)
    local objects = map.objects.walls
    local scale = 2

    local function rotatePoint(px, py, angle)
        local ca = math.cos(angle)
        local sa = math.sin(angle)
        return px * ca - py * sa, px * sa + py * ca
    end

    for _, obj in ipairs(layer.objects) do
        local rotDeg = obj.rotation or 0
        local angle = math.rad(rotDeg)

        local bodyX_world, bodyY_world
        local shape

        if obj.polygon and #obj.polygon >= 3 then
            local first = obj.polygon[1]
            local body = SE.physics.newBody(world.physics_world, (obj.x) * scale, (obj.y) * scale, "static")
            body:setAngle(angle)

            local verts = {}
            for i, p in ipairs(obj.polygon) do
                table.insert(verts, (p.x - first.x) * scale)
                table.insert(verts, (p.y - first.y) * scale)
            end

            local ok, shape_or_err = pcall(function() return SE.physics.newPolygonShape(verts) end)
            local shape = shape_or_err
            shape:setDensity(1)
            shape:setUserData({ type = "wall", object = obj })

            table.insert(objects, {
                x = (obj.x) * 2,
                y = (obj.y) * 2,
                width = obj.width * 2,
                height = obj.height * 2,
                id = obj.properties.id or (#objects + 1),
                properties = obj.properties,
                body = body,
                fixture = shape,
            })

        elseif obj.ellipse or obj.circle then
            local w = obj.width or (obj.radius and obj.radius * 2) or 0
            local h = obj.height or (obj.radius and obj.radius * 2) or 0
            local radius = math.min(w, h) / 2

            local cx, cy = w / 2, h / 2
            local rcx, rcy = rotatePoint(cx, cy, angle)
            bodyX_world = (obj.x + rcx) * scale
            bodyY_world = (obj.y + rcy) * scale

            local body = SE.physics.newBody(world.physics_world, bodyX_world, bodyY_world, "static")
            body:setAngle(angle)

            shape = SE.physics.newCircleShape(body, radius * scale)
            shape:setDensity(1)
            shape:setUserData({ type = "wall", object = obj })

            table.insert(objects, {
                x = (obj.x) * 2,
                y = (obj.y) * 2,
                width = w * 2,
                height = h * 2,
                id = obj.properties.id or (#objects + 1),
                properties = obj.properties,
                body = body,
                fixture = shape,
            })

        else
            local w, h = obj.width or 0, obj.height or 0
            local cx, cy = w / 2, h / 2
            local rcx, rcy = rotatePoint(cx, cy, angle)
            bodyX_world = (obj.x + rcx) * scale
            bodyY_world = (obj.y + rcy) * scale

            local body = SE.physics.newBody(world.physics_world, bodyX_world, bodyY_world, "static")
            body:setAngle(angle)

            shape = SE.physics.newRectangleShape(body, w * scale, h * scale)
            shape:setDensity(1)
            shape:setUserData({ type = "wall", object = obj })

            table.insert(objects, {
                x = (obj.x) * 2,
                y = (obj.y) * 2,
                width = w * 2,
                height = h * 2,
                id = obj.properties.id or (#objects + 1),
                properties = obj.properties,
                body = body,
                fixture = shape,
            })
        end
    end
end

function layerHandlers.signs(layer)
    local objects = map.objects.signs

    for _, obj in ipairs(layer.objects) do
        local sprite = Sprites.CreateSprite("Scene/Everywhere/spr_sign.png", "BelowPlayer")
        sprite:MoveTo(
            (obj.x + obj.width/2) * 2,
            (obj.y + obj.height/2) * 2
        )
        sprite:Scale(2, 2)
        table.insert(obj_sprites, sprite)

        local id = (obj.properties.id or #objects + 1)
        local body = SE.physics.newBody(world.physics_world,
            (obj.x + obj.width/2) * 2,
            (obj.y + obj.height/2) * 2 + 10,
            "kinematic")

        local shape = SE.physics.newRectangleShape(body, sprite.width * 2, sprite.height / 2 * 2)
        shape:setDensity(1)
        shape:setUserData({type = "sign", object = obj, id = id})

        table.insert(objects, {
            x = (obj.x + obj.width/2) * 2,
            y = (obj.y + obj.height/2) * 2,
            width = obj.width * 2,
            height = obj.height * 2,
            id = id,
            triggered = 0,
            properties = obj.properties,
            body = body,
            fixture = shape,
            sprite = sprite,
        })
    end
end

function layerHandlers.saves(layer)
    local objects = map.objects.saves

    for _, obj in ipairs(layer.objects) do
        local sprite = Sprites.CreateSprite("Scene/Everywhere/spr_savepoint_0.png", "BelowPlayer")
        sprite:SetAnimation({
            "Scene/Everywhere/spr_savepoint_1.png",
            "Scene/Everywhere/spr_savepoint_0.png"
        }, 0.2)
        sprite:MoveTo(
            (obj.x + obj.width/2) * 2,
            (obj.y + obj.height/2) * 2
        )
        sprite:Scale(2, 2)
        table.insert(obj_sprites, sprite)

        local id = (obj.properties.id or #objects + 1)
        local body = SE.physics.newBody(world.physics_world,
            (obj.x + obj.width/2) * 2,
            (obj.y + obj.height/2) * 2 + 10,
            "kinematic")

        local shape = SE.physics.newRectangleShape(body, sprite.width * 2, sprite.height / 2 * 2)
        shape:setDensity(1)
        shape:setUserData({type = "save", object = obj, id = id})

        table.insert(objects, {
            x = (obj.x + obj.width/2) * 2,
            y = (obj.y + obj.height/2) * 2,
            width = obj.width * 2,
            height = obj.height * 2,
            id = id,
            room = obj.properties.room,
            triggered = 0,
            position = {obj.properties.x, obj.properties.y},
            properties = obj.properties,
            body = body,
            fixture = shape,
            sprite = sprite,
        })
    end
end

local function scan_layers(_map)
    for _, layer in ipairs(_map.layers) do
        if (layer.type == "objectgroup") then
            -- Keep the raw Tiled objects for the debug drawer.
            local debug_list = map.debug_objects[layer.name]
            if (not debug_list) then
                debug_list = {}
                map.debug_objects[layer.name] = debug_list
            end
            for _, obj in ipairs(layer.objects) do
                table.insert(debug_list, obj)
            end

            -- Place the runtime objects / physics bodies.
            local handler = layerHandlers[layer.name]
            if (handler) then
                handler(layer)
            end
        end
    end
end

---------------------------------------------------

local function draw_object_debug(obj, color, base_angle)
    local x, y = obj.x or 0, obj.y or 0
    local w, h = obj.width or 0, obj.height or 0
    -- relative base angle + the object's own rotation (e.g. a 90deg / 60deg wall)
    local angle = (base_angle or 0) + (obj.rotation or 0)

    SE.graphics.push()
    SE.graphics.translate(x, y)
    SE.graphics.rotate(math.rad(angle))

    if (obj.shape == "point" or (w <= 0 and h <= 0)) then
        -- Point marker: cross at the object position
        local s = 4
        SE.graphics.setColor(color[1], color[2], color[3])
        SE.graphics.line(-s, 0, s, 0)
        SE.graphics.line(0, -s, 0, s)
    else
        -- Rectangle: translucent fill + colored outline
        SE.graphics.setColor(color[1], color[2], color[3], 0.25)
        SE.graphics.rectangle("fill", 0, 0, w, h)
        SE.graphics.setColor(color[1], color[2], color[3], 1)
        SE.graphics.rectangle("line", 0, 0, w, h)
    end

    SE.graphics.pop()
end

local function debug_drawer()
    if (map._debug and not map._debug_drawed) then
        map._debugger = Layers.add_external(function ()
            SE.graphics.push()
            SE.graphics.origin()
            SE.graphics.scale(2, 2)
            SE.graphics.translate(math.floor((320 - Camera.x) / 2), math.floor((240 - Camera.y) / 2))

            for name, objects in pairs(map.debug_objects) do
                local attrs = debug_attris[name] or debug_attris.unknowns
                for _, obj in ipairs(objects) do
                    draw_object_debug(obj, attrs[1], attrs[2] or 0)
                end
            end

            SE.graphics.pop()

            SE.graphics.origin()
            local mx, my = Keyboard.GetMousePosition()
            SE.graphics.rectangle("line", mx - 320, my - 240, mx + 320, my + 240)
        end, "DEBUG")
        map._debug_drawed = true
    end
end

local function debug_keyboards(dt)
    if (Keyboard.GetState("space") == 1) then
        -- Convert window pixel position -> canvas coordinate (0-640, 0-480)
        local mx, my = SE.mouse.getPosition()
        local canvas_x = (mx - DrawX) / ScreenScale
        local canvas_y = (my - DrawY) / ScreenScale

        -- Convert canvas coordinate -> map world coordinate, matching the map draw:
        --   map._map:draw((320 - Camera.x) / 2, (240 - Camera.y) / 2, 2, 2)
        --   screen = 2 * world + 320 - Camera.x
        local wx = (canvas_x - 320 + Camera.x) / 2
        local wy = (canvas_y - 240 + Camera.y) / 2

        -- Snap the camera so the world point under the mouse is the view center.
        -- The view center (screen 320, 240) shows world (Camera.x / 2, Camera.y / 2).
        Camera.x = wx * 2
        Camera.y = wy * 2
    end
end

---------------------------------------------------

---Destroy every physics body owned by the map objects.
local function resetObjects(objects)
    for k, v in pairs(objects) do
        if (type(v) == "table") then
            for i = #v, 1, -1 do
                local obj = v[i]
                if (obj and obj.body and not obj.body:isDestroyed()) then
                    obj.body:destroy()
                end
                v[i] = nil
            end
        end
    end
end

---Load a map: place every object's physics body and place the player.
---@param lua_file string
function map.Init(lua_file)
    if (map._initialized) then
        print("[InitWorld] Init skipped (already initialized)")
        return
    end
    map._initialized = true
    if (
        not lua_file or
        type(lua_file) ~= "string"
    ) then
        print("[Overworld - Maps] Error: Invalid lua file path.")
        return
    end

    -- Make sure the physics world is ready.
    world.Init()

    map.current = lua_file
    map._map = sti(map.current, {"box2d"})
    map._map.draw_objects = false

    -- Init objects in the layers (physics bodies + runtime data).
    scan_layers(map._map)

    map._debug = Overworld.debug
    debug_drawer()

    map._mapper = Layers.add_external(function ()
        -- STI draws the map canvas at the screen origin (it calls lg.origin()),
        -- so the translate must compensate the camera: screen = 2 * world + 320 - Camera.x.
        map._map:draw((320 - Camera.x) / 2, (240 - Camera.y) / 2, 2, 2)
    end, "Map")

    -- Place the player at the first mark.
    local startMark = map.objects.marks[1]
    if (startMark) then
        char.SetPosition(startMark.x, startMark.y, startMark.direction)
    end
    char.Init()
end

function map.Update(dt)
    world.Update(dt)
    char.Update(dt)

    -- Make the camera follow the player (bounds are applied by Camera:Update).
    if (char.currentSprite) then
        Camera:setPosition(char.currentSprite.x, char.currentSprite.y)

        for i = #obj_sprites, 1, -1
        do
            local s = obj_sprites[i]
            if (s.y > char.currentSprite.y) then
                s.layer = "UponPlayer"
            else
                s.layer = "BelowPlayer"
            end
        end
    end

    map._debug = Overworld.debug
    debug_keyboards(dt)
    debug_drawer()
end

---Clean up all map objects, physics bodies and external draws.
function map.Destroy()
    resetObjects(map.objects)
    for _, t in pairs(map.debug_objects) do
        for i = #t, 1, -1 do
            t[i] = nil
        end
    end
    map.debug_objects = {}

    if (map._mapper) then
        Layers.remove_external(map._mapper)
        map._mapper = nil
    end
    if (map._debugger) then
        Layers.remove_external(map._debugger)
        map._debugger = nil
    end
    map._debug_drawed = false
    map._map = nil
    map._initialized = false

    char.Destroy()
end

-- Expose the player module so other code can reach it, e.g. `Map.char` or
-- `Char = overworld.map.char` in init.lua.
map.char = char

return map
