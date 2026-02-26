oworld = {}

-- Init the oworld.char's data.
-- global:DeleteSaveVariable("Overworld")
-- global:DeleteSaveVariable("CHESTS")
-- global:DeleteSaveVariable("FLAG")

-- Init libraries to update the map.
local sti = require("Scripts.Libraries.STI")
require("Scripts.Libraries.Overworld.ConfigData")

-- Init the overworld's physics oworld.pworld.
local FADEOUT = sprites.CreateSprite("px.png", 10000)
FADEOUT:Scale(99999, 99999)
FADEOUT.color = {0, 0, 0}

oworld.objects = {
    marks = {},
    signs = {},
    walls = {},
    saves = {},
    warps = {},
    triggers = {},
    texts = {},
    chests = {},
    player = {},
}
oworld.LEAVING = false
oworld.POSITION = "down" -- The position of the text box. "up" or "down".
oworld.NEXTSTATE = "Controlling" -- Mark the next state of the oworld.char.
oworld.CSTATE = "Controlling" -- Current state of the oworld.char.
oworld.ENCOUNTER = false
oworld.TIME = 0
oworld.dtTIME = 0
oworld.DEBUG = false
oworld.NAME = ""
oworld.pworld = love.physics.newWorld(0, 0, true)
oworld.configs ={
    debugdraw = true,
    draw = {
        map = true,
        signs = true,
        walls = true,
        saves = true,
        warps = true,
        triggers = true,
        texts = true,
        chests = true,
        player = true,
    },
    colors = {
        mark = {0.5, 0, 0, 0.3},
        sign = {1, 1, 0, 0.3},
        wall = {0.5, 0.5, 0.5, 0.3},
        save = {1, 0.5, 1, 0.3},
        warp = {0, 1, 0, 0.3},
        trigger = {1, 0, 1, 0.3},
        text = {1, 0.5, 0, 0.3},
        chest = {0.3, 1, 1, 0.3},
        ['oworld.char'] = {0, 0, 1, 0.3}
    }
}
oworld.interactions = {
    can_interact = false,
    current_object = nil,
    current_id = 0
}
oworld.char = {
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
    direction = "right",
    animationFrame = 1,
    animationTime = 0,
    isMoving = false,
    collision = {
        body = nil,
        shape = nil,
        fixture = nil
    }
}
oworld.heart = sprites.CreateSprite("Soul Library Sprites/spr_default_heart.png", 100000)
oworld.heart.alpha = 0
oworld.heart.color = {1, 0, 0}
---------------------------------------------------
local layerHandlers = {}

function layerHandlers.triggers(layer)
    local objects = oworld.objects.triggers

    for _, obj in ipairs(layer.objects) do
        local id = obj.properties.id or (#objects + 1)

        local body = love.physics.newBody(
            oworld.pworld,
            (obj.x + obj.width / 2) * 2,
            (obj.y + obj.height / 2) * 2,
            "kinematic"
        )

        local shape = love.physics.newRectangleShape(
            obj.width * 2,
            obj.height * 2
        )

        local fixture = love.physics.newFixture(body, shape, 1)
        fixture:setSensor(true)
        fixture:setUserData({ type = "trigger", id = id })

        table.insert(objects, {
            x = obj.x * 2,
            y = obj.y * 2,
            width = obj.width * 2,
            height = obj.height * 2,
            id = id,
            triggered = 0,
            properties = obj.properties,
            body = body
        })
    end
end

function layerHandlers.marks(layer)
    local objects = oworld.objects.marks
    
    for _, obj in ipairs(layer.objects) do
        local id = obj.properties.id or (#objects + 1)

        table.insert(objects, {
            x = (obj.x) * 2,
            y = (obj.y) * 2,
            direction = obj.properties.direction or "right",
            id = id,
            properties = obj.properties
        })
    end
end

function layerHandlers.chests(layer)
    local objects = oworld.objects

    for _, obj in ipairs(layer.objects) do

        local sprite = sprites.CreateSprite("Scene/Everywhere/spr_chestbox_0.png", 2000 + (obj.y + obj.height/2) * 2)
        sprite:MoveTo(
            (obj.x + obj.width / 2 ) * 2,
            (obj.y + obj.height / 2) * 2
        )
        sprite:Scale(2, 2)

        if (not oworld.configs.draw.chests) then
            sprite.alpha = 0
        end

        local id = obj.properties.id or (#objects.chests + 1)
        local body = love.physics.newBody(oworld.pworld,
            (obj.x + obj.width / 2 ) * 2,
            (obj.y + obj.height / 2) * 2 + 10,
            "kinematic"
        )
        table.insert(objects.chests, {
            x = (obj.x + obj.width/2) * 2,
            y = (obj.y + obj.height/2) * 2,
            width = obj.width * 2,
            height = obj.height * 2,
            id = id,
            give = (obj.properties.give or false),
            properties = obj.properties,
            body = body,
        })
        local shape = love.physics.newRectangleShape(sprite.width * 2, sprite.height / 2 * 2)
        local fixture = love.physics.newFixture(body, shape, 1)
        fixture:setUserData({type = "chest", object = obj, id = id})
    end
end

function layerHandlers.warps(layer)
    local objects = oworld.objects

    for _, obj in ipairs(layer.objects) do
        local body = love.physics.newBody(oworld.pworld,
            (obj.x + obj.width/2) * 2,
            (obj.y + obj.height/2) * 2,
            "kinematic")
        local shape = love.physics.newRectangleShape(
            obj.width  * 2,
            obj.height * 2)
        local fixture = love.physics.newFixture(body, shape, 1)
        fixture:setUserData({type = "warp", object = obj, id = obj.properties.id})
        fixture:setSensor(true)

        table.insert(objects.warps, {
            x = (obj.x) * 2,
            y = (obj.y) * 2,
            width = obj.width * 2,
            height = obj.height * 2,
            id = obj.properties.id,
            properties = obj.properties,
            body = body,
        })
    end
end

function layerHandlers.walls(layer)
    local objects = oworld.objects
    local scale = 2

    local function polygonCentroid(points)
        local A = 0
        local Cx, Cy = 0, 0
        local n = #points
        for i = 1, n do
            local x0, y0 = points[i].x, points[i].y
            local j = (i % n) + 1
            local x1, y1 = points[j].x, points[j].y
            local cross = x0 * y1 - x1 * y0
            A = A + cross
            Cx = Cx + (x0 + x1) * cross
            Cy = Cy + (y0 + y1) * cross
        end
        A = A * 0.5
        if A == 0 then
            local sx, sy = 0, 0
            for _, p in ipairs(points) do sx = sx + p.x; sy = sy + p.y end
            return sx / (#points), sy / (#points)
        end
        Cx = Cx / (6 * A)
        Cy = Cy / (6 * A)
        return Cx, Cy
    end

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
            local body = love.physics.newBody(oworld.pworld, (obj.x) * scale, (obj.y) * scale, "static")
            body:setAngle(angle)

            local verts = {}
            for i, p in ipairs(obj.polygon) do
                table.insert(verts, (p.x - first.x) * scale)
                table.insert(verts, (p.y - first.y) * scale)
            end

            local ok, shape_or_err = pcall(function() return love.physics.newPolygonShape(verts) end)
            if not ok then
                error("创建 PolygonShape 失败: "..tostring(shape_or_err).." (顶点数或凹多边形?)")
            end
            local shape = shape_or_err
            local fixture = love.physics.newFixture(body, shape, 1)
            fixture:setUserData({ type = "wall", object = obj })

            table.insert(objects.walls, {
                x = (obj.x) * 2,
                y = (obj.y) * 2,
                width = obj.width * 2,
                height = obj.height * 2,
                id = obj.properties.id or (#objects.walls + 1),
                properties = obj.properties,
                body = body
            })

        elseif obj.ellipse or obj.circle then
            local w = obj.width or (obj.radius and obj.radius * 2) or 0
            local h = obj.height or (obj.radius and obj.radius * 2) or 0
            local radius = math.min(w, h) / 2

            local cx, cy = w / 2, h / 2
            local rcx, rcy = rotatePoint(cx, cy, angle)
            bodyX_world = (obj.x + rcx) * scale
            bodyY_world = (obj.y + rcy) * scale

            local body = love.physics.newBody(oworld.pworld, bodyX_world, bodyY_world, "static")
            body:setAngle(angle)

            shape = love.physics.newCircleShape(radius * scale)
            local fixture = love.physics.newFixture(body, shape, 1)
            fixture:setUserData({ type = "wall", object = obj })

            table.insert(objects.walls, {
                x = (obj.x) * 2,
                y = (obj.y) * 2,
                width = w * 2,
                height = h * 2,
                id = obj.properties.id or (#objects.walls + 1),
                properties = obj.properties,
                body = body
            })

        else
            local w, h = obj.width or 0, obj.height or 0
            local cx, cy = w / 2, h / 2
            local rcx, rcy = rotatePoint(cx, cy, angle)
            bodyX_world = (obj.x + rcx) * scale
            bodyY_world = (obj.y + rcy) * scale

            local body = love.physics.newBody(oworld.pworld, bodyX_world, bodyY_world, "static")
            body:setAngle(angle)

            shape = love.physics.newRectangleShape(w * scale, h * scale)
            local fixture = love.physics.newFixture(body, shape, 1)
            fixture:setUserData({ type = "wall", object = obj })

            table.insert(objects.walls, {
                x = (obj.x) * 2,
                y = (obj.y) * 2,
                width = w * 2,
                height = h * 2,
                id = obj.properties.id or (#objects.walls + 1),
                properties = obj.properties,
                body = body
            })
        end
    end
end

function layerHandlers.signs(layer)
    local objects = oworld.objects

    for _, obj in ipairs(layer.objects) do
        local sprite = sprites.CreateSprite("Scene/Everywhere/spr_sign.png", 2000 + (obj.y + obj.height/2) * 2)
        sprite:MoveTo(
            (obj.x + obj.width/2) * 2,
            (obj.y + obj.height/2) * 2
        )
        sprite:Scale(2, 2)
        if (not oworld.configs.draw.signs) then
            sprite.alpha = 0
        end
        local id = (obj.properties.id or #objects.signs + 1)
        local body = love.physics.newBody(oworld.pworld,
            (obj.x + obj.width/2) * 2,
            (obj.y + obj.height/2) * 2 + 10,
            "kinematic")
        table.insert(objects.signs, {
            x = (obj.x + obj.width/2) * 2,
            y = (obj.y + obj.height/2) * 2,
            width = obj.width * 2,
            height = obj.height * 2,
            id = id,
            triggered = 0,
            properties = obj.properties,
            body = body
        })
        local shape = love.physics.newRectangleShape(
            sprite.width * 2,
            sprite.height / 2 * 2)
        local fixture = love.physics.newFixture(body, shape, 1)
        fixture:setUserData({type = "sign", object = obj, id = id})
    end
end

function layerHandlers.saves(layer)
    local objects = oworld.objects

    for _, obj in ipairs(layer.objects) do
        local sprite = sprites.CreateSprite("Scene/Everywhere/spr_savepoint_0.png", 2000 + (obj.y + obj.height/2) * 2)
        sprite:SetAnimation({
            "Scene/Everywhere/spr_savepoint_1.png",
            "Scene/Everywhere/spr_savepoint_0.png"
        }, 15)
        sprite:MoveTo(
            (obj.x + obj.width/2) * 2,
            (obj.y + obj.height/2) * 2
        )
        sprite:Scale(2, 2)
        if (not oworld.configs.draw.saves) then
            sprite.alpha = 0
        end
        local id = (obj.properties.id or #objects.signs + 1)
        local body = love.physics.newBody(oworld.pworld,
            (obj.x + obj.width/2) * 2,
            (obj.y + obj.height/2) * 2 + 10,
            "kinematic")
        table.insert(objects.saves, {
            x = (obj.x + obj.width/2) * 2,
            y = (obj.y + obj.height/2) * 2,
            width = obj.width * 2,
            height = obj.height * 2,
            id = id,
            room = obj.properties.room,
            triggered = 0,
            position = {obj.properties.x, obj.properties.y},
            properties = obj.properties,
            body = body
        })
        local shape = love.physics.newRectangleShape(
            sprite.width * 2,
            sprite.height / 2 * 2)
        local fixture = love.physics.newFixture(body, shape, 1)
        fixture:setUserData({type = "save", object = obj, id = id})
    end
end

local function scanLayers(map)
    for _, layer in ipairs(map.layers) do
        print("Scanning layer:", layer.name, layer.type)

        local handler = layerHandlers[layer.name]
        if handler and layer.type == "objectgroup" then
            handler(layer)
        end
    end
end

---------------------------------------------------

function oworld.SetBattleScene(scene, flag)
    oworld.BATTLESCENE = scene
    global:SetVariable("OVERWORLD_KILLFLAG", flag)
end

function oworld.FindObject(type, varname, value, first_only)
    local objects = oworld.objects
    local found_objects = {}

    if (objects[type]) then
        for _, obj in pairs(objects[type]) do
            if (obj.properties and obj.properties[varname] == value) then
                if first_only then
                    return obj
                else
                    found_objects[#found_objects + 1] = obj
                end
            end
        end
    end
    if not first_only then
        return found_objects
    end
end

local exc = sprites.CreateSprite("Overworld/spr_exc.png", 12000)
exc:Scale(2, 2)
if (DATA.player.lv >= 10) then
    exc:Set("Overworld/spr_exc_f.png")
end
exc.alpha = 0

local stat = require("Scripts.Libraries.Overworld.Stat")

local first_direction = ""
local d_pressing = false

-- Init the physcics oworld.pworld functions.
local function isPlayerCollision(dataA, dataB, objectType)
    return (dataA and dataA.type == "oworld.char" and dataB and dataB.type == objectType) or
           (dataB and dataB.type == "oworld.char" and dataA and dataA.type == objectType)
end
local function handleInteraction(dataA, dataB, objectType)
    oworld.interactions.can_interact = true
    oworld.interactions.current_object = objectType
    if (dataA.type == objectType) then oworld.interactions.current_id = dataA.id end
    if (dataB.type == objectType) then oworld.interactions.current_id = dataB.id end

    if (oworld.DEBUG) then
        print("Player collided with " .. objectType)
        print(dataA.id or dataB.id)
    end
end
local function clearInteraction()
    oworld.interactions.current_id = 0
    oworld.interactions.current_object = nil
    oworld.interactions.can_interact = false
end
-- When the oworld.char is colliding with an object, get the object's type and the id number.
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
-- When the oworld.char is not colliding with an object, clear all variables.
local function endContact(a, b)
    local dataA = a:getUserData() or {}
    local dataB = b:getUserData() or {}

    local clearTypes = {"warp", "chest", "sign", "save", "trigger"}
    for _, objType in ipairs(clearTypes) do
        if (isPlayerCollision(dataA, dataB, objType)) then
            clearInteraction()
            break
        end
    end
end

local function RelativePosition(x, y)
    return _CAMERA_.x + x, _CAMERA_.y + y
end

local function CreateBox(x, y, width, height)
    local box = {}

    box.white = sprites.CreateSprite("px.png", 9900)
    box.white:Scale(width + 10, height + 10)
    box.white.color = {1, 1, 1}
    box.white:MoveTo(x, y)

    box.black = sprites.CreateSprite("px.png", 9900.1)
    box.black:Scale(width, height)
    box.black.color = {0, 0, 0}
    box.black:MoveTo(x, y)

    return box
end

local tempbox, temptext, tempchest, nowdt, fadeoutwarp
local savedirection = "down"
local saveposition = {0, 0}
local room_name = ""
local fadeouttime = 0
local invtexts, boxtexts = {}, {}
local box_choosing = 1
oworld.choose_case = 1
function player_choosing_start(case, starty)
    oworld.choose_case = 1
    oworld.choose_obj = case
    oworld.heart.alpha = 1
    oworld.choose_y = starty
end
function player_choosing_update()
    if (oworld) then
        if (oworld.choose_obj == "chestbox") then
            if (keyboard.GetState("left") == 1) then
                oworld.choose_case = 1
            elseif (keyboard.GetState("right") == 1) then
                oworld.choose_case = 2
            end
            if (oworld.choose_case == 1) then
                oworld.heart:MoveTo(RelativePosition(160, oworld.choose_y))
                if (keyboard.GetState("confirm") == 1) then
                    local x, y = RelativePosition(320, 240)
                    tempbox = CreateBox(x, y, 600, 440)
                    tempbox.line = sprites.CreateSprite("px.png", 9901)
                    tempbox.line:Scale(2, 300)
                    tempbox.line.color = {0.5, 0, 0}
                    tempbox.line:MoveTo(RelativePosition(320, 240))
                    tempbox.title = typers.DrawText("[preset=chinese]物品栏             箱子", {RelativePosition(150, 30)}, 9903)
                    oworld.choose_case = 1
                    oworld.choose_obj = "inchestbox"

                    for i = 1, 9
                    do
                        local item = DATA.player.items[i]
                        local t = typers.DrawText(item or "", {RelativePosition(90, 80 + 35 * (i - 1))}, 9990)
                        table.insert(invtexts, t)
                    end
                    for i = 1, 9
                    do
                        local item = tempchest[i]
                        local t = typers.DrawText(item or "", {RelativePosition(390, 80 + 35 * (i - 1))}, 9990)
                        table.insert(boxtexts, t)
                    end
                end
            else
                oworld.heart:MoveTo(RelativePosition(380, oworld.choose_y))
            end
        elseif (oworld.choose_obj == "save") then
            oworld.CSTATE = "Stopping"
            oworld.heart.alpha = 0
            if (keyboard.GetState("confirm") == 1) then
                local x, y = RelativePosition(320, 200)
                tempbox = CreateBox(x, y, 412, 162)
                local tm = global:GetSaveVariable("Overworld")
                local minutes = math.floor(tm.time / 60)
                local seconds = math.floor(tm.time % 60)
                tempbox.text = typers.DrawText(
                    string.format("Chara    LV " .. global:GetSaveVariable("Overworld").player.lv .. "    %02d:%02d", minutes, seconds),
                    {RelativePosition(140, 135)}, 100000
                )
                tempbox.room = typers.DrawText(
                    DATA.room_name,
                    {RelativePosition(140, 185)}, 100000
                )
                tempbox.choe = typers.DrawText(
                    "Save       Cancel",
                    {RelativePosition(165, 235)}, 100000
                )
                oworld.choose_obj = "insave"
            end
        elseif (oworld.choose_obj == "insave") then
            oworld.CSTATE = "Stopping"
            oworld.heart.alpha = 1

            if (keyboard.GetState("left") == 1) then
                oworld.choose_case = 1
            elseif (keyboard.GetState("right") == 1) then
                oworld.choose_case = 2
            end
            oworld.heart:MoveTo(RelativePosition(150 + (oworld.choose_case - 1) * 170, 252))

            if (keyboard.GetState("confirm") == 1) then
                if (oworld.choose_case == 1) then
                    audio.PlaySound("snd_save.wav")
                    oworld.heart.alpha = 0

                    local minutes = math.floor(DATA.time / 60)
                    local seconds = math.floor(DATA.time % 60)
                    DATA.player.lv = battle.Player.lv
                    tempbox.text:SetText(string.format(DATA.player.name .. "    LV " .. DATA.player.lv .. "    %02d:%02d", minutes, seconds))
                    tempbox.text.color = {1, 1, 0}
                    tempbox.text:Reparse()

                    tempbox.room:SetText(room_name)
                    tempbox.room.color = {1, 1, 0}
                    tempbox.room:Reparse()

                    tempbox.choe:SetText("Saved Successfully")
                    tempbox.choe.color = {1, 1, 0}
                    tempbox.choe:Reparse()

                    DATA.room_name = room_name
                    DATA.savedpos = true
                    DATA.position = saveposition
                    DATA.direction = savedirection

                    global:SetSaveVariable("Flag", FLAG)
                    global:SetSaveVariable("Chests", CHESTS)
                    global:SetSaveVariable("Overworld", DATA)

                    oworld.choose_obj = "savequit"
                else
                    tempbox.black:Destroy()
                    tempbox.white:Destroy()
                    tempbox.text:Destroy()
                    tempbox.room:Destroy()
                    tempbox.choe:Destroy()
                    oworld.NEXTSTATE = "Controlling"
                    oworld.choose_obj = nil
                    oworld.choose_case = 1
                    oworld.heart.alpha = 0
                end
            end
        elseif (oworld.choose_obj == "savequit") then
            if (keyboard.GetState("confirm") == 1) then
                tempbox.black:Destroy()
                tempbox.white:Destroy()
                tempbox.text:Destroy()
                tempbox.room:Destroy()
                tempbox.choe:Destroy()
                oworld.NEXTSTATE = "Controlling"
                oworld.choose_obj = nil
                oworld.choose_case = 1
                oworld.heart.alpha = 0
            end
        elseif (oworld.choose_obj == "inchestbox") then
            oworld.CSTATE = "Stopping"
            oworld.heart.alpha = 1

            if (keyboard.GetState("left") == 1) then
                oworld.choose_case = 1
                box_choosing = math.min(box_choosing, #DATA.player.items)
                if (box_choosing < 1) then box_choosing = 1 end
            elseif (keyboard.GetState("right") == 1) then
                oworld.choose_case = 2
                box_choosing = math.min(box_choosing, #tempchest)
                if (box_choosing < 1) then box_choosing = 1 end
            end

            if (keyboard.GetState("up") == 1) then
                audio.PlaySound("snd_menu_0.wav")
                box_choosing = math.max(box_choosing - 1, 1)
            elseif (keyboard.GetState("down") == 1) then
                audio.PlaySound("snd_menu_0.wav")
                if (oworld.choose_case == 1) then
                    box_choosing = math.min(box_choosing + 1, #DATA.player.items)
                elseif (oworld.choose_case == 2) then
                    box_choosing = math.min(box_choosing + 1, #tempchest)
                end
            end

            if (oworld.choose_case == 1) then
                oworld.heart:MoveTo(RelativePosition(50, 97 + 35 * (box_choosing - 1)))
            else
                oworld.heart:MoveTo(RelativePosition(350, 97 + 35 * (box_choosing - 1)))
            end

            if (keyboard.GetState("confirm") == 1) then
                if (oworld.choose_case == 1) then
                    table.insert(tempchest, DATA.player.items[box_choosing])
                    table.remove(DATA.player.items, box_choosing)
                elseif (oworld.choose_case == 2) then
                    table.insert(DATA.player.items, tempchest[box_choosing])
                    table.remove(tempchest, box_choosing)
                end

                for i = 1, 9
                do
                    local item = DATA.player.items[i]
                    local t = invtexts[i]
                    t:SetText(item or "")
                end
                for i = 1, 9
                do
                    local item = tempchest[i]
                    local t = boxtexts[i]
                    t:SetText(item or "")
                end

                if (oworld.choose_case == 1) then
                    box_choosing = math.min(box_choosing, #DATA.player.items)
                elseif (oworld.choose_case == 2) then
                    box_choosing = math.min(box_choosing, #tempchest)
                end
                if (box_choosing < 1) then box_choosing = 1 end
            end

            if (keyboard.GetState("cancel") == 1) then
                for _, v in pairs(invtexts)
                do
                    if (type(v) == "table") then
                        v:Destroy()
                    end
                end
                for _, v in pairs(boxtexts)
                do
                    if (type(v) == "table") then
                        v:Destroy()
                    end
                end
                invtexts = {}
                boxtexts = {}
                box_choosing = 1
                tempbox.white:Destroy()
                tempbox.black:Destroy()
                tempbox.line:Destroy()
                tempbox.title:Destroy()
                tempbox = nil
                oworld.choose_case = 1
                oworld.heart.alpha = 0
                oworld.choose_obj = nil
                oworld.NEXTSTATE = "Controlling"
            end
        end
    end
end

function oworld.SetPlayerSprites(tab)
    if (not tab) then return end
    oworld.char.sprites = tab
end

function oworld.SetFlag(flagname, value) if (not flagname) then return end FLAG[flagname] = value end
function oworld.GetFlag(flagname) if (not flagname) then return nil end return FLAG[flagname] end
function oworld.SetData(dataname, value) if (not dataname) then return end DATA[dataname] = value end
function oworld.GetData(dataname) if (not dataname) then return nil end return DATA[dataname] end

local encstep = require("Scripts.Libraries.Overworld.EncounterStep")
-- encstep.Init(FLAG.ruins_killed, 120, 80, 20)
local encounter_time = 0

---Init this room's encounter logics.
---@param key number Which number you gonna use for killed monsters.
---@param start number The min time for encountering the monster.
---@param range number The max time for encountering the monster.
---@param amount number How many monsters in this area should be killed.
function oworld.InitEncounter(key, start, range, amount)
    encstep.Init(key, start, range, amount)
end

function oworld.InitMusic(file)
    if (not file or file == "") then
        local ins = global:GetVariable("OverworldBGM")
        ins:Destroy()
    else
        if (not global:GetVariable("OverworldBGM")) then
            local mus, ins = audio.PlayMusic(file)
            global:SetVariable("OverworldBGM", ins)
        else
            if (not audio.NameExists(file)) then
                local ins = global:GetVariable("OverworldBGM")
                ins:Destroy()

                local mus, ins = audio.PlayMusic(file)
                global:SetVariable("OverworldBGM", ins)
            end
        end
    end
end

local function resetObjects(objects)
    for k, v in pairs(objects) do
        if type(v) == "table" then
            for i = #v, 1, -1 do
                local obj = v[i]
                if obj.body and not obj.body:isDestroyed() then
                    obj.body:destroy()
                end
                v[i] = nil
            end
        end
    end
end

---Init the scene.
---@param stifile string
---@param name string
function oworld.Init(stifile, name)
    if oworld._initialized then
        print("[InitWorld] Init skipped (already initialized)")
        return
    end
    oworld._initialized = true
    resetObjects(oworld.objects)

    oworld.NAME = (name or stifile:sub(-4, -1))
    DATA.room = "Overworld/" .. name
    global:SetVariable("ROOM", name)
    oworld.MAP = sti(stifile, {"box2d"})
    oworld.MAP.draw_objects = false

    -- Init objects in the layers.
    scanLayers(oworld.MAP)

    -- Init the oworld.char.
    local function findmarker(id)
        for k, v in pairs(oworld.objects.marks) do
            if (v.id == id) then return k end
        end
        return nil
    end
    local startMark = oworld.objects.marks[findmarker(DATA.marker)] or oworld.objects.marks[1]
    oworld.char.direction = startMark.direction
    local sx, sy = startMark.x, startMark.y

    if (DATA.savedpos) then
        sx, sy = unpack(DATA.position)
        oworld.char.direction = DATA.direction
    end

    oworld.char.currentSprite = sprites.CreateSprite(
        oworld.char.sprites[oworld.char.direction][1],
        1
    )
    oworld.char.currentSprite:Scale(2, 2)

    -- Player collision setup
    oworld.char.collision.body = love.physics.newBody(
        oworld.pworld,
        sx * 1,
        sy * 1,
        "dynamic"
    )
    oworld.char.collision.shape = love.physics.newRectangleShape(38, 20)
    oworld.char.collision.fixture = love.physics.newFixture(
        oworld.char.collision.body,
        oworld.char.collision.shape,
        1
    )

    oworld.char.collision.body:setFixedRotation(true)
    oworld.char.collision.fixture:setRestitution(0)
    oworld.char.collision.fixture:setFriction(0.1)
    oworld.char.collision.fixture:setUserData({type = "oworld.char"})

    -- Init the physical world logics.
    oworld.pworld:setCallbacks(beginContact, endContact)
end

---Config the scene. You can decide which elements should be drawn. Or open the debug mode.
---@param configtable table
function oworld.Configs(configtable)
    if (not configtable) then return end
    oworld.configs = configtable
end

--[[

目前已经被使用的按键：上下左右ZXC

Spacebar    - Teleport the player object to the mouse's position.
Q           - Show/Shut off all collision boxes.
A           - Disable all collisions of walls.

]]
local enabled_wallcoll = true
function oworld.DEBUGfuncs()
    if (not oworld.DEBUG) then return end
    if (not oworld.char) then return end

    if (keyboard.GetState("space") == 1) then
        local x, y = keyboard.GetMousePosition()
        local realx, realy = _CAMERA_.x + x, _CAMERA_.y + y
        print(x, y, realx, realy)
        oworld.char.collision.body:setPosition(x, y)
    elseif (keyboard.GetState("q") == 1) then
        oworld.configs.debugdraw = not oworld.configs.debugdraw
    elseif (keyboard.GetState("a") == 1) then
        enabled_wallcoll = not enabled_wallcoll
        oworld.char.collision.fixture:setSensor(enabled_wallcoll)
    end
end

local char_prevX, char_prevY = 0, 0

function oworld.Update(dt)

    stat:Update()
    DATA.time = DATA.time + dt

    if (oworld) then
        oworld.TIME = oworld.TIME + 1
        oworld.dtTIME = oworld.dtTIME + dt
        oworld.pworld:update(dt)
        encstep.run = oworld.ENCOUNTER
        player_choosing_update()

        -- Fade in.
        if (oworld.dtTIME <= 0.5) then
            FADEOUT.alpha = (0.5 - oworld.dtTIME) * 2
        end

        local velbodyx, velbodyy = 0, 0
        if (oworld.CSTATE == "Controlling") then
            if (keyboard.GetState(first_direction) <= 0) then
                first_direction = ""
                --d_pressing = false
            end
            if (keyboard.GetState("left") > 0) then
                if (oworld.char.direction ~= "right") then velbodyx = -2 end
                if (first_direction == "" or not d_pressing) then
                    oworld.char.direction = "left"
                    first_direction = "left"
                    d_pressing = true
                end
            end
            if (keyboard.GetState("right") > 0) then
                if (oworld.char.direction ~= "left") then velbodyx = 2 end
                if (first_direction == "" or not d_pressing) then
                    oworld.char.direction = "right"
                    first_direction = "right"
                    d_pressing = true
                end
            end
            if (keyboard.GetState("up") > 0) then
                if (oworld.char.direction ~= "down") then velbodyy = -2 end
                if (first_direction == "" or not d_pressing) then
                    oworld.char.direction = "up"
                    first_direction = "up"
                    d_pressing = true
                end
            end
            if (keyboard.GetState("down") > 0) then
                if (oworld.char.direction ~= "up") then velbodyy = 2 end
                if (first_direction == "" or not d_pressing) then
                    oworld.char.direction = "down"
                    first_direction = "down"
                    d_pressing = true
                end
            end
        end

        -- Make the sprite follow the fixture.
        if (oworld.char) then
            local char = oworld.char
            if (char.collision.body) then
                char.currentSprite:MoveTo(
                    char.collision.body:getX(),
                    char.collision.body:getY() - 20
                )
            end
            char.collision.body:setLinearVelocity(velbodyx * 100, velbodyy * 100)
            _CAMERA_:setPosition(char.currentSprite.x - 320, char.currentSprite.y - 240)
            FADEOUT:MoveTo(char.currentSprite:GetPosition())

            if (velbodyx ~= 0 or velbodyy ~= 0) then
                oworld.char.animationTime = oworld.char.animationTime + dt
                if oworld.char.animationTime >= 0.16 then
                    oworld.char.animationFrame = oworld.char.animationFrame % #oworld.char.sprites[oworld.char.direction] + 1
                    oworld.char.animationTime = 0
                end
                if (char_prevX ~= oworld.char.currentSprite.x or char_prevY ~= oworld.char.currentSprite.y) then
                    char_prevX = oworld.char.currentSprite.x
                    char_prevY = oworld.char.currentSprite.y
                    oworld.char.isMoving = true
                else
                    oworld.char.isMoving = false
                end

                if (oworld.char.isMoving) then
                    encstep.Update()
                end
            else
                oworld.char.animationFrame = 1
            end

            if (encstep.encountered) then
                oworld.CSTATE = "Stopping"
                exc:MoveTo(
                    oworld.char.currentSprite.x + 0,
                    oworld.char.currentSprite.y - 40
                )
                if (encounter_time == 0) then
                    audio.PlaySound("snd_encounter.wav")
                    exc.alpha = 1
                end
                encounter_time = encounter_time + 1
                if (encounter_time >= 60 and encounter_time <= 90) then
                    exc.alpha = 0
                    oworld.heart:MoveTo(char.currentSprite:GetPosition())
                    if (encounter_time % 5 == 0) then
                        audio.PlaySound("snd_tong.wav")
                        FADEOUT.alpha = 1 - FADEOUT.alpha
                        oworld.heart.alpha = 1 - oworld.heart.alpha
                    end
                elseif (encounter_time == 91) then
                    exc.alpha = 0
                    audio.PlaySound("snd_encounter_fall.wav")
                    tween.CreateTween(
                        function (value)
                            oworld.heart.x = value
                        end,
                        "Linear", "", oworld.heart.x, _CAMERA_.x + 87 - 39, 30
                    )
                    tween.CreateTween(
                        function (value)
                            oworld.heart.y = value
                        end,
                        "Linear", "", oworld.heart.y, _CAMERA_.y + 453, 30
                    )
                elseif (encounter_time == 123) then
                    DATA.savedpos = true
                    DATA.position = {
                        char.currentSprite.x,
                        char.currentSprite.y + 20,
                    }
                    DATA.direction = char.direction
                    if (global:GetVariable("OverworldBGM")) then
                        local ins = global:GetVariable("OverworldBGM")
                        ins:Destroy()
                    end
                    scenes.switchTo(oworld.BATTLESCENE)
                    return
                end
            end

            oworld.char.currentSprite:Set(oworld.char.sprites[oworld.char.direction][oworld.char.animationFrame])
            oworld.char.currentSprite.layer = 2000 + oworld.char.currentSprite.y

            oworld.DEBUGfuncs()
        end

        if (oworld.LEAVING) then
            oworld.CSTATE = "Stopping"
            fadeouttime = fadeouttime + dt
            if (fadeouttime <= 0.5) then
                FADEOUT.alpha = fadeouttime * 2
            else
                DATA.savedpos = false
                scenes.switchTo(oworld.targetscene)
            end
        end
    end
end

-- Debug drawing for physics fixtures
local function drawFixture(fixture)
    if not fixture or not fixture:getShape() then return end

    local shape = fixture:getShape()
    local body = fixture:getBody()
    local shapeType = shape:getType()

    -- Draw fill

    if shapeType == "polygon" then
        love.graphics.polygon("fill", body:getWorldPoints(shape:getPoints()))
    elseif shapeType == "circle" then
        love.graphics.circle("fill", body:getX(), body:getY(), shape:getRadius())
    elseif shapeType == "rectangle" then
        love.graphics.rectangle("fill",
            body:getX() - shape:getWidth()/2,
            body:getY() - shape:getHeight()/2,
            shape:getWidth(),
            shape:getHeight())
    else
        love.graphics.circle("fill", body:getX(), body:getY(), 5)
    end

    -- Draw outline
    love.graphics.setLineWidth(2)

    if (shapeType == "polygon") then
        love.graphics.polygon("line", body:getWorldPoints(shape:getPoints()))
    elseif (shapeType == "circle") then
        love.graphics.circle("line", body:getX(), body:getY(), shape:getRadius())
    elseif (shapeType == "rectangle") then
        love.graphics.rectangle("line",
            body:getX() + shape:getWidth()/2,
            body:getY() - shape:getHeight()/2,
            shape:getWidth(),
            shape:getHeight())
    end

    love.graphics.setLineWidth(1)
end

function oworld.Draw()
    if (oworld.configs.draw.map) then

        love.graphics.push()
            oworld.MAP:draw(-_CAMERA_.x / 2, -_CAMERA_.y / 2, 2 * scale, 2 * scale)
        love.graphics.pop()

    end

    if (oworld.DEBUG) then
        if (not oworld.configs.debugdraw) then return end
        love.graphics.push()

            for _, body in pairs(oworld.pworld:getBodies()) do
                for _, fixture in pairs(body:getFixtures()) do
                    local color = oworld.configs.colors[fixture:getUserData().type] or {1, 1, 1, 0.3}
                    love.graphics.setColor(color)
                    drawFixture(fixture)
                end
            end

        love.graphics.pop()
        love.graphics.setColor(1, 1, 1, 1)
    end
end

---If you wanna get the results when the oworld.char interacts with some objects, use this function.
---If the id argument is nil, then this will return every objects' result.
---@param obj_type string
---@param id number | nil
---@return boolean
function oworld.getInteractResult(obj_type, id)
    if (not oworld) then return false end
    if (not oworld.interactions.current_object) then return false end
    if (oworld.CSTATE ~= "Controlling") then return false end

    local final_type = oworld.interactions.current_object
    local final_id   = oworld.interactions.current_id
    local bool = false

    if (not id) then
        if (final_type == obj_type) then
            bool = true
        end
    else
        if (final_type == obj_type and final_id == id) then
            bool = true
        end
    end

    return bool
end

---Check if two objects are interacting.
---@param obj1 table
---@param obj2 table
---@return boolean
function oworld.TwoObjectsInteract(obj1, obj2)
    return (
        math.abs(obj1.x - obj2.x) * 2 < (obj1.width  + obj2.width) and
        math.abs(obj1.y - obj2.y) * 2 < (obj1.height + obj2.height)
    )
end

---This function will create a new dialog box.
---@param texts table | string
---@param position string | nil Set the position of the text box. "up" or "down". Default is decided by the player's position.(Relative to the screen)
---@return table | false
function oworld.dialogNew(texts, position)
    local text_inst = {}

    if (oworld.CSTATE == "Stopping") then return false end
    oworld.CSTATE = "Stopping"
    -- clearInteraction()

    -- The position argument decides where the text box will appear.
    local posy
    if (not position) then
        posy = (oworld.POSITION == "up") and 80 or 400
    else
        posy = (position == "up") and 80 or 400
    end

    text_inst.white = sprites.CreateSprite("px.png", 80000)
    text_inst.white:Scale(600, 150)
    text_inst.black = sprites.CreateSprite("px.png", 80001)
    text_inst.black:Scale(590, 140)

    text_inst.white:MoveTo(RelativePosition(320, posy))
    text_inst.black:MoveTo(RelativePosition(320, posy))

    text_inst.black.color = {0, 0, 0}
    text_inst.typer = typers.CreateText(texts, {RelativePosition(50, posy - 55)}, 80002, {0, 0}, "manual")

    text_inst.typer.OnComplete = function()
        oworld.heart.alpha = 0
        text_inst.white:Destroy()
        text_inst.black:Destroy()
        oworld.NEXTSTATE = "Controlling"
    end

    return text_inst
end

function oworld.ChestInteract(chest)
    -- Create a dialog box.
    tempchest = CHESTS[chest]
    local posy = (oworld.POSITION == "up") and 80 or 400
    oworld.dialogNew({"* Use the box?[space:2, 38]\n\n        Yes           No[function:player_choosing_start|chestbox," .. posy + 35 .. "]"})
end

function oworld.SaveInteract(texts, room, position, direction)
    room_name = room
    savedirection = direction
    saveposition = position
    DATA.player.hp = math.max(DATA.player.hp, DATA.player.maxhp)
    audio.PlaySound("snd_heal.wav")
    local res = {unpack(texts)}
    res[#res] = res[#res] .. "[function:player_choosing_start|save]"
    oworld.dialogNew(res)
end

function oworld.ChangeScene(scene, mark)
    oworld.LEAVING = true
    oworld.targetscene = scene
    DATA.marker = (mark or 1)
end

---Destroy the oworld.char and the oworld.pworld.
function oworld.Destroy()
    package.loaded["Scripts.Libraries.STI"] = nil
    package.loaded["Scripts.Libraries.Overworld.Stat"] = nil
    package.loaded["Scripts.Libraries.Overworld.EncounterStep"] = nil

    if (oworld.char and oworld.char.collision.body) then
        oworld.char.collision.body:destroy()
        oworld.char.collision.body = nil
    end

    if (oworld.pworld) then
        oworld.pworld:destroy()
        oworld.pworld = nil
    end

    -- Clear all objects.
    oworld.objects = {
        marks = {},
        signs = {},
        walls = {},
        saves = {},
        warps = {},
        triggers = {},
        texts = {},
        chests = {},
        player = {}
    }

    layers.clear()
    oworld = nil
end

return oworld