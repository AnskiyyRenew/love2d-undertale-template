Layers.new_layer("Background", -100)
Layers.new_layer("Map", 0)
Layers.new_layer("BelowPlayer", 49)
Layers.new_layer("Player", 50)
Layers.new_layer("UponPlayer", 51)
Layers.new_layer("GUI", 80)
Layers.new_layer("TOP", 100)
Layers.new_layer("DEBUG", 200)

local path = (...):match("(.-)[^%.]+$")
local overworld = {
    map = require(path .. "Overworld.map"),
    inst = {},
    interacts = {},
    ui_prefer = "down",

    debug = false,
}

-- One-frame lock: set when a dialog's typewriter finishes so that the same
-- "confirm" press which closed the dialog cannot instantly re-trigger the
-- interaction (which would otherwise cause an infinite dialog loop).
local dialog_just_closed = false
-- Tracks whether the lock was set in the current frame (by _onComplete) so that
-- overworld.Update keeps it for the rest of this frame and only clears it at
-- the start of the next frame.
local dialog_lock_pending = false

Overworld = overworld
Map = overworld.map
World = overworld.map.world
Char = overworld.map.char

local blacktop = Sprites.CreateSprite("px.png", "TOP")
blacktop:Scale(1000, 1000)
blacktop.color = {0, 0, 0}
blacktop:MoveTo(Camera.x, Camera.y)
blacktop._decay = true
blacktop.Step = function (self)
    if (self._decay) then
        self.alpha = self.alpha - 0.05
        if (self.alpha <= 0) then
            self._decay = false
        end
    else
        if (self.alpha >= 1) then
            self._decay = true
        end
    end
end

function GetRelativePos(x, y)
    local function clamp(v, max, min)
        return (math.max(math.min(max, v), min))
    end

    local rx = clamp(Camera.x, (Camera.max_x or math.huge), (Camera.min_x or -math.huge))
    local ry = clamp(Camera.y, (Camera.max_y or math.huge), (Camera.min_y or -math.huge))
    return rx - 320 + x, ry - 240 + y
end

function SpawnBlock(x, y, width, height, thickness)
    local block = {
        x = x,
        y = y,
        w = width,
        h = height,
        t = thickness,
    }

    local white = Sprites.CreateSprite("px.png", "GUI")
    white:Scale(block.w + thickness * 2, block.h + thickness * 2)
    white:MoveTo(block.x, block.y)
    local black = Sprites.CreateSprite("px.png", "GUI")
    black.color = {0, 0, 0}
    black:Scale(block.w, block.h)
    black:MoveTo(block.x, block.y)

    block.Destroy = function ()
        white:Destroy()
        black:Destroy()
        block = nil
    end

    return block
end

function overworld.Init(lua_file)
    overworld.map.Init(lua_file)
end

function overworld.SetMusic(mpath)
    if (not Audio.FindMusic(mpath)) then
        local mus
        mus, overworld.inst = Audio.PlayMusic(mpath)
    end
end

---If you wanna get the results when the overworld.char interacts with some objects, use this function.
---If the id argument is nil, then this will return every objects' result.
---If extra_key is nil, the object is matched by its "id" property. If extra_key
---is a property name (string), the object is matched by that property's value
---instead (e.g. getInteractResult("trigger", 1, "rr") matches the trigger whose
---rr == 1) and the property value is returned.
---@param obj_type string
---@param id number | string | nil
---@param extra_key string | number | nil
---@return boolean | any
function overworld.getInteractResult(obj_type, id, extra_key)
    -- If a dialog just finished this frame, swallow EVERY interaction result for
    -- the rest of the frame so the same confirm press that completed the
    -- typewriter can't re-trigger any of them (this applies to every call made
    -- this frame, not just the first one).
    if (dialog_just_closed) then
        return false
    end
    if (not Char.controlling) then return end

    local interactions = overworld.map.world.interactions
    if (not interactions) then return false end
    if (not interactions.current_object) then return false end
    -- NOTE: no CSTATE / dialog state machine exists yet, so the reference's
    -- "Controlling" guard is intentionally omitted. Add it back once a dialog
    -- state is introduced.

    local final_type = interactions.current_object
    if (final_type ~= obj_type) then return false end

    -- id not given: only require the object type to match.
    if (id == nil) then
        return true
    end

    -- No extra_key (or a numeric extra_key): match by the object's id.
    if (not extra_key or type(extra_key) == "number") then
        return (interactions.current_id == id)
    end

    -- extra_key is a property name: match the collided object's property value.
    local obj = interactions.current_obj
    if (not obj or not obj.properties) then return false end
    local value = obj.properties[extra_key]
    if (value == id) then
        return value
    end
    return false
end

---Like getInteractResult, but checks EVERY object the player is currently
---touching at once (not just the last collision). This avoids the problem where
---overlapping triggers overwrite each other. Returns true if any touched object
---of obj_type matches: by id (extra_key nil / number) or by a property value
---(extra_key = property name, e.g. getTouchResult("trigger", 1, "rr")).
---@param obj_type string
---@param id number | string | nil
---@param extra_key string | number | nil
---@return boolean
function overworld.getTouchResult(obj_type, id, extra_key)
    local interactions = overworld.map.world.interactions
    if (not interactions) then return false end

    local touching = interactions.touching or {}
    for _, t in ipairs(touching) do
        if (t.type == obj_type) then
            -- id not given: any touched object of this type matches.
            if (id == nil) then
                return true
            end

            -- Match by id, or by a property value when extra_key is a name.
            if (not extra_key or type(extra_key) == "number") then
                if (t.id == id) then
                    return true
                end
            else
                local obj = t.object
                if (obj and obj.properties and obj.properties[extra_key] == id) then
                    return true
                end
            end
        end
    end
    return false
end

---Find a placed object on the current map and return its runtime object table
---(which contains x, y, id, properties, etc.). This searches the GLOBAL object
---registry, so the object does NOT need to be touched or interacted with — as
---long as it was placed/spawned on the map it is included. Parameters work the
---same as getInteractResult / getTouchResult: extra_key nil/number matches by
---id, extra_key string matches by the object property of that name (e.g.
---FindObject("trigger", 1, "rr")). Returns nil if no matching object is found.
---@param obj_type string
---@param id number | string | nil
---@param extra_key string | number | nil
---@return table | nil
function overworld.FindObject(obj_type, id, extra_key)
    -- Search the global registry: every object placed/spawned on the current map.
    local objects = overworld.map.objects
    if (not objects) then return nil end

    local list = objects[obj_type .. "s"]
    if (not list) then return nil end

    for _, obj in ipairs(list) do
        -- id not given: return the first object of this type.
        if (id == nil) then
            return obj
        end

        -- Match by id, or by a property value when extra_key is a name.
        if (not extra_key or type(extra_key) == "number") then
            if (obj.id == id) then
                return obj
            end
        else
            if (obj.properties and obj.properties[extra_key] == id) then
                return obj
            end
        end
    end
    return nil
end

function overworld.dialogNew(texts, position)
    if (not Char.controlling) then return end
    Char.controlling = false
    dialog_just_closed = false -- a new dialog clears any stale frame lock
    dialog_lock_pending = false
    local pos = (position or overworld.ui_prefer)
    local y = (pos == "down" and 400 or 80)

    local _x, _y = GetRelativePos(320, y)
    print(_x, _y)

    local dialog = {
        block = SpawnBlock(_x, _y, 590, 140, 5)
    }
    local _text = Typers.EText.New(texts, {GetRelativePos(50, y - 55)}, "GUI")
    _text._onComplete = function ()
        Char.controlling = true
        dialog.block.Destroy()
        -- Lock every interaction for the rest of this frame so the confirm
        -- press that closed the dialog can't re-trigger any of them.
        dialog_just_closed = true
        dialog_lock_pending = true
    end
    dialog.text = _text

    return dialog
end

function overworld.Update(dt)
    -- Release the one-frame dialog lock at the start of a NEW frame. If the
    -- lock was just set this frame (dialog_lock_pending is true, because
    -- _onComplete ran before this update), keep it active for the rest of the
    -- frame so every getInteractResult call this frame stays blocked.
    if (not dialog_lock_pending) then
        dialog_just_closed = false
    end
    dialog_lock_pending = false

    overworld.map.Update(dt)
end

function overworld.Draw()
end

function overworld.Clear()
    Map.Destroy()

    local content = {"char", "map", "world", "stat", "init"}
    for i = 1, #content
    do
        package.loaded["Scripts.Libraries.Overworld." .. content[i]] = nil
    end

    dialog_just_closed = false
end

return overworld