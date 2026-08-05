local map = {
    current = "",
    _initialized = false,

    _debug_drawed = false,
    objects = {
        marks = {},
        triggers = {},
        walls = {},
        saves = {},
        signs = {},
        warps = {},
        chests = {},

        unknowns = {}
    }
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
local sti = ImportFile("STI")

local function scan_layers(_map)
    for _, layer in ipairs(_map.layers)
    do
        if (layer.type == "objectgroup") then
            for _, obj in ipairs(layer.objects)
            do
                table.insert(map.objects[layer.name], obj)
            end
        end
    end
end

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
            SE.graphics.translate(math.floor(320 - Camera.x), math.floor(240 - Camera.y))

            for name, objects in pairs(map.objects) do
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
        --   map._map:draw(320 - Camera.x, 240 - Camera.y, 2, 2)
        --   screen = 2 * (world + 320 - Camera.x)
        local wx = canvas_x / 2 - 320 + Camera.x
        local wy = canvas_y / 2 - 240 + Camera.y

        -- Snap the camera so the world point under the mouse is the view center.
        -- The view center (screen 320, 240) shows world (Camera.x - 160, Camera.y - 120).
        Camera.x, Camera.y = wx + 160, wy + 120
    end
end

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

    map.current = lua_file
    map._map = sti(map.current, {"box2d"})
    map._map.draw_objects = false
    scan_layers(map._map)

    map._debug = Overworld.debug
    debug_drawer()

    map._mapper = Layers.add_external(function ()
        map._map:draw(320 - Camera.x, 240 - Camera.y, 2, 2)
    end, "Map")
end

function map.Update(dt)
    map._debug = Overworld.debug
    debug_keyboards(dt)
    debug_drawer()
end

return map

