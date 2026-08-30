Layers.new_layer("Background", -100)
Layers.new_layer("Map", 0)
Layers.new_layer("BelowPlayer", 49)
Layers.new_layer("Player", 50)
Layers.new_layer("UponPlayer", 51)
Layers.new_layer("GUI", 80)
Layers.new_layer("TOP", 100)
Layers.new_layer("DEBUG", 200)
DATA = DATA or require("Scripts.Game.Logics")
FLAG = DATA.flags
CHEST = DATA.chests
ITEMS = require("Scripts.Game.Logics.items")
DATA.room = Scenes.name_current

local path = (...):match("(.-)[^%.]+$")
local overworld = {
    _alpha = 0,
    _pages = {
        save = require(path .. "Overworld.Pages.save"),
        chest = require(path .. "Overworld.Pages.chest")
    },
    map = require(path .. "Overworld.map"),
    stat = require(path .. "Overworld.stat"),
    inst = {},
    interacts = {},
    ui_prefer = "down",

    _enc = {
        _type = "default",
        _init = false,
        time = 0,

        _scene = "",
        _game  = ""
    },
    _friskdance = Global.GetVariable("EnableFriskDance"),
    target_scene = "",
    _leaving = false,

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
function overworld.JustOnDialog()
    dialog_just_closed = true
    dialog_lock_pending = true
end


Overworld = overworld
Map = overworld.map
World = overworld.map.world
Char = overworld.map.char
-- Drive the Frisk Dance ("屠杀之舞") toggle through the dedicated
-- overworld._friskdance variable (read from the "EnableFriskDance" flag).
Char.friskdance = overworld._friskdance
Stat = overworld.stat
Save = overworld._pages.save
Chest = overworld._pages.chest
Step = require(path .. "Overworld.encounter")

local function clamp(v, max, min)
    return (math.max(math.min(max, v), min))
end

function GetRelativePos(x, y)
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

    block.Destroy = function (self)
        white:Destroy()
        black:Destroy()
        block = nil
    end

    return block
end

function overworld.Init(lua_file)
    overworld.map.Init(lua_file)
end

function overworld.CalcNextEXP()
    local next_total = DATA.lv_data[DATA.player.lv + 1].totalExp
    return next_total - DATA.player.exp
end

function overworld.onConfirm(type_name, id, sub_key, func)
    local key = nil
    local callback = sub_key

    if (func) then
        key = sub_key
        callback = func
    end

    if (type(callback) ~= "function") then
        error("overworld.onConfirm: callback must be a function")
    end

    local can_interact = overworld.getInteractResult(type_name, id)
    if (key) then
        can_interact = can_interact and overworld.getInteractResult(type_name, id, key)
    end

    if (can_interact and Controller.GetState("confirm") == 1) then
        callback()
    end
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
    -- Stop the player immediately so the camera stays put for this frame. If
    -- this is called before map.Update (e.g. from a sprite Step), zeroing the
    -- velocity before the physics step prevents the one-frame slide that would
    -- otherwise make GetRelativePos anchor the dialog one frame behind.
    if (Char.collision.body) then
        Char.collision.body:setLinearVelocity(0, 0)
    end
    dialog_just_closed = false -- a new dialog clears any stale frame lock
    dialog_lock_pending = false
    local pos = (position or overworld.ui_prefer)
    local y = (pos == "down" and 400 or 80)

    local _x, _y = GetRelativePos(320, y)
    local dialog = {
        block = SpawnBlock(_x, _y, 590, 140, 5)
    }
    local _text = Typers.EText.New(texts, {GetRelativePos(50, y - 55)}, "GUI")
    _text._onComplete = function ()
        Char.controlling = true
        dialog.block:Destroy()
        -- Lock every interaction for the rest of this frame so the confirm
        -- press that closed the dialog can't re-trigger any of them.
        dialog_just_closed = true
        dialog_lock_pending = true
    end
    dialog.text = _text

    return dialog
end

function overworld.ChangeScene(scene, mark, direction)
    if (not Char.controlling) then return end
    Char.controlling = false

    overworld._leaving = true
    overworld.target_scene = scene

    DATA.room = Scenes.name_current
    DATA.marker = (mark or 1)
    DATA.direction = (direction or "down")
    DATA.savedpos = false
    Global.SetVariable("OVERWORLD_NOBODYCAME", false)
end

function overworld.SaveInteract(texts, location, position, direction)
    DATA.player.hp = math.max(DATA.player.hp, DATA.player.maxhp)
    Audio.PlaySound("snd_heal.wav")
    local dialog = overworld.dialogNew(texts)
    if (not dialog) then return end

    dialog.text._onComplete = function ()
        dialog.block:Destroy()
        dialog_just_closed = true
        dialog_lock_pending = true
        Save.Show()
    end

    -- Save
    DATA.room = Scenes.name_current
    DATA.room_name = (location or "Unknown place")
    DATA.position = position
    DATA.direction = direction
    DATA.savedpos = true
end

function overworld.ChestInteract(chest)
    local _chest = chest
    if (chest == nil or chest == "") then
        _chest = "chest"
    end

    Chest.Show(_chest)
end

function overworld.InitEncounter(flag, start, range, amount)
    Step.Init(flag, start, range, amount)
    Global.SetVariable("FLAG_KILLING_COUNTER", flag)
end

function overworld.SetBattleScene(scene, game)
    Global.SetVariable("OVERWORLD_ENCOUNTER_BATTLE", {scene, game})
end

function overworld.Encounter(type)
    Char.controlling = false
    overworld._enc._init = true
    overworld._enc._type = (type or "default")
    Audio.PlaySound("snd_encounter.wav")
end

function overworld.Update(dt)
    -- Time
    DATA.time = DATA.time + dt

    -- Release the one-frame dialog lock at the start of a NEW frame. If the
    -- lock was just set this frame (dialog_lock_pending is true, because
    -- _onComplete ran before this update), keep it active for the rest of the
    -- frame so every getInteractResult call this frame stays blocked.
    if (not dialog_lock_pending) then
        dialog_just_closed = false
    end
    dialog_lock_pending = false

    -- stat runs BEFORE map on purpose: it opens the menu and zeroes the
    -- player's velocity before the physics step inside map.Update, so the body
    -- (and camera) does not slide forward one frame while the menu is being
    -- positioned. map.Update then moves the player and makes the camera follow;
    -- GetRelativePos (used by dialogs, which are created after this update)
    -- reads the freshly-followed camera, keeping stat and dialogs on the same
    -- frame.
    overworld.stat.Update(dt)
    overworld.map.Update(dt)

    Save.Update()
    Chest.Update()
    Step.Update()

    -- encounter
    if (overworld._enc._init) then
        if (overworld._enc._type == "default") then
            if (overworld._enc.time == 0) then
                local exc = Sprites.CreateSprite("Overworld/spr_exc.png", "GUI")
                exc:MoveTo(Char.currentSprite.x, Char.currentSprite.y - 40)
                exc:Scale(2, 2)
                if (DATA.player.lv >= 10) then
                    exc:Set("Overworld/spr_exc_f.png")
                end

                local blink_out = Sprites.CreateSprite("px.png", "TOP")
                blink_out:Scale(1500, 1500)
                blink_out:MoveTo(Char.currentSprite:GetPosition())
                blink_out.color = {0, 0, 0}
                blink_out.alpha = 0

                local heart = Sprites.CreateSprite("Soul Library Sprites/spr_default_heart.png", "TOP")
                heart.alpha = 0
                heart.color = {1, 0, 0}
                heart.Step = function (self)
                    local time = overworld._enc.time
                    if (time >= 60 and time % 5 == 0 and time <= 90) then
                        exc.alpha = 0
                        blink_out.alpha = 1 - blink_out.alpha
                        heart.alpha = 1 - heart.alpha
                        heart:MoveTo(Char.currentSprite:GetPosition())
                        Audio.PlaySound("snd_tong.wav")
                    end
                    if (time == 90) then
                        Audio.PlaySound("snd_encounter_fall.wav")
                        Tween.CreateTween(
                            function (value)
                                self.x = value
                            end,
                            "Linear", "", self.x, Camera.x - 320 + 87 - 39, 30
                        )
                        Tween.CreateTween(
                            function (value)
                                self.y = value
                            end,
                            "Linear", "", self.y, Camera.y - 240 + 453, 30
                        )
                    elseif (time == 130) then
                        DATA.savedpos = true
                        DATA.position = {
                            Char.currentSprite.x,
                            Char.currentSprite.y + 20,
                        }
                        DATA.direction = Char.direction

                        local _bdata = Global.GetVariable("OVERWORLD_ENCOUNTER_BATTLE")[1]
                        Scenes.switchTo(_bdata)
                    end
                end
            end
        end

        overworld._enc.time = overworld._enc.time + 1
    end
end

local blacktop = Sprites.CreateSprite("px.png", "TOP")
blacktop:Scale(2000, 2000)
blacktop.color = {0, 0, 0}
blacktop:MoveTo(DATA.position[1], DATA.position[2])
blacktop._decay = true
blacktop.Step = function (self)
    self:MoveTo(Char.currentSprite.x, Char.currentSprite.y)
    if (self._decay) then
        self.alpha = self.alpha - 0.05
        if (overworld._leaving) then
            self._decay = false
        end
        if (self.alpha <= 0) then
            self._decay = false
        end
    else
        if (self.alpha >= 1) then
            self._decay = true
        end
    end

    if (overworld._leaving) then
        self.alpha = self.alpha + 0.05

        if (self.alpha >= 1) then
            Scenes.switchTo(overworld.target_scene)
        end
    end
end

function overworld.Draw()
end

function overworld.Clear()
    Map.Destroy()
    Camera:unBounds()

    -- Clear the entire Overworld library tree (char, map, world, stat, init,
    -- encounter, shop, ...) so it re-executes fresh on next load.
    ClearModuleTree("Scripts.Libraries.Overworld")

    Camera:reset()
    dialog_just_closed = false
end

return overworld