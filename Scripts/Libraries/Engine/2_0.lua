--[[
    Scripts/Libraries/Engine/2_0.lua
    Backward-compatibility layer: run SE "12.0" / v2.0 projects on the current engine.

    Load AFTER the current engine globals exist (Global, Sprites, Typers, Layers,
    Keyboard, Masks, Tween, Audio, Scenes, Collisions, LuaEX, Camera):

        require("Scripts.Libraries.Engine.2_0")     -- or ImportFile("Engine.2_0")

    What this file provides (old name -> current implementation):
      global        -> adapter over Global (colon methods + variable field access)
      sprites       -> Sprites (+ CreateSpriteAtlas shim)
      typers        -> Typers (+ CreateText / DrawText / SpawnBubble / instances / clear)
      layers        -> Layers
      keyboard      -> Keyboard
      masks         -> Masks (+ reset / setTest / clear aliases)
      tween         -> Tween
      audio         -> Audio (+ ClearAll / NameExists, instance methods attached)
      scenes        -> Scenes
      collisions    -> Collisions
      luaex         -> LuaEX (+ printTable shim)
      windows       -> current Windows module
      maths         -> small Mathematics shim (Clamp / Choose / Direction / ...)
      localize      -> Localize (+ localizetext global)
      _CAMERA_/cam  -> proxy over the current Camera instance (rotation <-> r,
                       boundActive -> unBounds, old method names)

    IMPORTANT COMPATIBILITY GAPS still to migrate (see bottom of file for details):
      gui (GUIManager), Timeline, TimeManager(timer), ShaderToy folder API, old
      Scripts/Shaders folder format, old Overworld/Battle gameplay modules, the old
      typer tag vocabulary ([scale]/[voice]/[pattern]/[fontSize:i,s] / named colors),
      old easing names, and the per-file save/ layout.
]]

local compat = {}
compat.VERSION = "2_0"

-- Set to true to overwrite globals that already exist (default: only fill gaps).
compat.force = compat.force or false

local function sset(name, value)
    if (value == nil) then return end
    if (compat.force or _G[name] == nil) then
        _G[name] = value
    end
end

-- Resolve an engine module: prefer the already-loaded global, otherwise try
-- ImportFile (available once PathDefiner has run in main.lua).
local function resolve(gname, import_path)
    local v = _G[gname]
    if (v ~= nil) then return v end
    if (type(ImportFile) == "function") then
        local ok, mod = pcall(ImportFile, import_path)
        if (ok and mod ~= nil) then return mod end
    end
    return nil
end

local GlobalMod = resolve("Global", "Global")

if (GlobalMod) then
    -- Keep a couple of v2.0 defaults alive if the old project expects them.
    pcall(function()
        if (GlobalMod.EnsureVariable) then
            GlobalMod.EnsureVariable("LAYER", 30)
            GlobalMod.EnsureVariable("ScreenShaders", {})
        end
    end)

    local global_compat = {}

    -- Define the colon methods FIRST: once __newindex is installed below, plain
    -- assignments would be routed into the variable store instead of the table.
    function global_compat:SetVariable(name, value) return GlobalMod.SetVariable(name, value) end
    function global_compat:GetVariable(name) return GlobalMod.GetVariable(name) end
    function global_compat:EnsureVariable(name, value) return GlobalMod.EnsureVariable(name, value) end
    function global_compat:SetSaveVariable(name, value) return GlobalMod.SetSaveVariable(name, value) end
    function global_compat:GetSaveVariable(name) return GlobalMod.GetSaveVariable(name) end
    function global_compat:EnsureSaveVariable(name, value) return GlobalMod.EnsureSaveVariable(name, value) end
    function global_compat:DeleteSaveVariable(name) return GlobalMod.DeleteSaveVariable(name) end

    setmetatable(global_compat, {
        __index = function(_, k)
            local v = GlobalMod[k]
            if (v ~= nil) then return v end
            return GlobalMod.GetVariable(k)
        end,
        __newindex = function(_, k, v)
            GlobalMod.SetVariable(k, v)
        end,
    })

    sset("global", global_compat)
    compat.global = global_compat
end

sset("sprites", resolve("Sprites", "Sprites"))
sset("layers", resolve("Layers", "Layers"))
sset("keyboard", resolve("Keyboard", "Controller.Keyboard"))
sset("tween", resolve("Tween", "Tween"))
sset("scenes", resolve("Scenes", "SceneManager"))
sset("collisions", resolve("Collisions", "Collisions"))
sset("luaex", resolve("LuaEX", "Utils.LuaExtended"))

local Sprites = resolve("Sprites", "Sprites")
if (Sprites and not Sprites.CreateSpriteAtlas and Sprites.CreateSprite) then
    function Sprites.CreateSpriteAtlas(path, x, y, w, h, layer)
        local sprite = Sprites.CreateSprite(path, layer)
        if (sprite and sprite.image and SE and SE.graphics and SE.graphics.newQuad) then
            local iw, ih = sprite.image:getDimensions()
            sprite.quad = SE.graphics.newQuad(x, y, w, h, iw, ih)
        end
        return sprite
    end
    compat.added_sprite_atlas = true
end

local Masks = resolve("Masks", "Masks")
if (Masks) then
    if (not Masks.setTest) then
        function Masks.setTest(value)
            -- Old API toggled a manual stencil test; the current engine exposes
            -- masks.Use(value) / masks.Clear(). Kept as a best-effort alias.
            if (value ~= nil and value ~= 0 and Masks.Use) then
                pcall(Masks.Use, value)
            elseif (Masks.Clear) then
                pcall(Masks.Clear)
            end
        end
    end
    if (not Masks.reset) then
        function Masks.reset()
            if (Masks.Clear) then pcall(Masks.Clear) end
        end
    end
    if (not Masks.clear) then
        function Masks.clear()
            if (Masks.Clear) then pcall(Masks.Clear) end
        end
    end
    sset("masks", Masks)
end

local Audio = resolve("Audio", "Audio")
if (Audio) then
    if (not Audio.ClearAll) then
        Audio.ClearAll = function() if (Audio.Clear) then return Audio.Clear() end end
    end
    if (not Audio.NameExists) then
        Audio.NameExists = function(name)
            local insts = Audio.insts or {}
            for i = 1, #insts do
                local inst = insts[i]
                if (inst and (inst.name == name or inst.path == name)) then return true end
            end
            return false
        end
    end

    -- Attach old colon-methods to playback instances if the engine's instances
    -- do not already expose them (old code calls ins:VolumeTransition(...)).
    local function attach_inst_methods(inst)
        if (type(inst) ~= "table") then return inst end
        local map = {
            VolumeTransition = Audio.VolumeTransition,
            PitchTransition  = Audio.PitchTransition,
            FadeIn           = Audio.FadeIn,
            FadeOut          = Audio.FadeOut,
            Pause            = Audio.Pause,
            Resume           = Audio.Resume,
            Stop             = Audio.Stop,
        }
        for name, fn in pairs(map) do
            if (inst[name] == nil and type(fn) == "function") then
                inst[name] = function(self, ...) return fn(self, ...) end
            end
        end
        return inst
    end

    local raw_play_sound = Audio.PlaySound
    local raw_play_music = Audio.PlayMusic
    if (raw_play_sound) then
        Audio.PlaySound = function(...)
            local a, b = raw_play_sound(...)
            return a, attach_inst_methods(b)
        end
    end
    if (raw_play_music) then
        Audio.PlayMusic = function(...)
            local a, b = raw_play_music(...)
            return a, attach_inst_methods(b)
        end
    end
    sset("audio", Audio)
end

local LuaEX = resolve("LuaEX", "Utils.LuaExtended")
if (LuaEX and not LuaEX.printTable) then
    function LuaEX.printTable(t, indent, seen)
        indent = indent or 0
        seen = seen or {}
        if (type(t) ~= "table") then print(tostring(t)) return end
        if (seen[t]) then print(string.rep(" ", indent) .. "<cycle>") return end
        seen[t] = true
        for k, v in pairs(t) do
            if (type(v) == "table") then
                print(string.rep(" ", indent) .. tostring(k) .. " = {")
                LuaEX.printTable(v, indent + 2, seen)
                print(string.rep(" ", indent) .. "}")
            else
                print(string.rep(" ", indent) .. tostring(k) .. " = " .. tostring(v))
            end
        end
    end
end

local ok_win, WinMod = pcall(require, "Scripts.Libraries.Utils.Windows")
if (ok_win and type(WinMod) == "table") then
    sset("windows", WinMod)
end

local maths = {}
function maths.Clamp(v, minv, maxv) return math.max(minv, math.min(maxv, v)) end
function maths.Lerp(a, b, t) return a + (b - a) * t end
function maths.Round(v) return math.floor(v + 0.5) end
function maths.Sign(v) return (v > 0 and 1) or (v < 0 and -1) or 0 end
function maths.Choose(...)
    local n = select("#", ...)
    if (n == 0) then return nil end
    return (select(math.random(n), ...))
end
function maths.Distance(x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end
function maths.Direction(x1, y1, x2, y2, offset)
    local angle = math.deg(math.atan2(y2 - y1, x2 - x1))
    return angle + (offset or 0)
end
sset("maths", maths)

local Localize = resolve("Localize", "Localize")
if (Localize) then
    local localize_proxy = setmetatable({}, {
        __index = function(_, k)
            local v = Localize[k]
            if (v ~= nil) then return v end
            if (Localize.localizeText) then return Localize.localizeText(k) end
            return nil
        end,
    })
    sset("localize", localize_proxy)
    sset("localizetext", function(_lang, key, args) return Localize.localizeText(key, args) end)
end

local Camera = resolve("Camera", "Camera")
if (Camera and type(Camera) == "table" and Camera.New and not Camera.setPosition) then
    local ok, inst = pcall(function() return Camera:New() end)
    if (ok and inst) then Camera = inst end
end
if (Camera) then
    local cam_proxy = setmetatable({}, {
        __index = function(_, k)
            if (k == "rotation") then return Camera.r or 0 end
            if (k == "angle") then return Camera.r or 0 end
            return Camera[k]
        end,
        __newindex = function(_, k, v)
            if (k == "rotation" or k == "angle") then
                Camera.r = v
            elseif (k == "boundActive") then
                Camera.boundActive = v
                if (v == false and Camera.unBounds) then pcall(function() Camera:unBounds() end) end
            else
                Camera[k] = v
            end
        end,
    })
    sset("_CAMERA_", cam_proxy)
    sset("cam", cam_proxy)
    compat.camera = cam_proxy
end

local Typers = resolve("Typers", "Typers")
local EText  = Typers and Typers.EText
local InstText = Typers and Typers.InstText

local NAMED_COLORS = {
    red = "ff0000", purple = "9900ff", blue = "0000ff", green = "00ff00",
    yellow = "ffff00", white = "ffffff", black = "000000", orange = "ff8000",
    cyan = "00ffff", pink = "ff00ff", gray = "808080", grey = "808080",
}

local function translate_legacy_tags(s)
    if (type(s) ~= "string") then return s end
    -- [fontSize:index,size] / [fontSize:size] -> [size:size]
    s = s:gsub("%[fontSize:%s*%d+%s*,%s*(%d+)%s*%]", "[size:%1]")
    s = s:gsub("%[fontSize:%s*(%d+)%s*%]", "[size:%1]")
    -- [function:...] -> [func:...]
    s = s:gsub("%[function:", "[func:")
    -- named colors -> colorhex
    s = s:gsub("%[([%a_]+)%]", function(name)
        local hex = NAMED_COLORS[name:lower()]
        return hex and ("[colorhex:" .. hex .. "]") or ("[" .. name .. "]")
    end)
    -- tags with no current equivalent: strip (documented gaps)
    s = s:gsub("%[fontIndex:[^%]]*%]", "")
    s = s:gsub("%[pattern:[^%]]*%]", "")
    s = s:gsub("%[space:[^%]]*%]", "")
    s = s:gsub("%[spaceX%s*=%s*[^%]]*%]", "")
    s = s:gsub("%[offset:[^%]]*%]", "")
    s = s:gsub("%[offsetX%s*=%s*[^%]]*%]", "")
    s = s:gsub("%[offsetY%s*=%s*[^%]]*%]", "")
    s = s:gsub("%[scale:[^%]]*%]", "")
    s = s:gsub("%[scale%s*=%s*[^%]]*%]", "")
    return s
end

local function translate_sentences(sentences)
    if (type(sentences) == "string") then return translate_legacy_tags(sentences) end
    if (type(sentences) == "table") then
        local out = {}
        for i = 1, #sentences do out[i] = translate_legacy_tags(sentences[i]) end
        return out
    end
    return sentences
end

local LEGACY_FIELD_MAP = {
    OnComplete  = "_onComplete",
    OnUpdating  = "_onUpdate",
    sentences   = "texts",
    progressmode = "mode",
}

local function letters_size(t)
    local maxx, maxy = 0, 0
    local letters = (t and t.letters) or {}
    for i = 1, #letters do
        local L = letters[i]
        local w = (L.width or 0) * (L.scale or 1)
        local x = (L.x or 0) + w
        if (x > maxx) then maxx = x end
        if ((L.y or 0) > maxy) then maxy = (L.y or 0) end
    end
    return maxx, maxy + 20
end

local function legacy_wrap(typer)
    if (type(typer) ~= "table") then return typer end

    local proxy = setmetatable({}, {
        __index = function(_, k) return typer[k] end,
        __newindex = function(_, k, v)
            local tk = LEGACY_FIELD_MAP[k] or k
            typer[tk] = v
        end,
    })

    local function add(name, fn)
        if (type(typer[name]) ~= "function") then
            typer[name] = fn
        end
    end

    add("GetLettersSize", function() return letters_size(typer) end)
    add("SetStencils", function(_, masks) typer.stencils = masks or {} end)
    add("SetShaders", function(_, shaders) typer.shaders = shaders or {} end)
    add("Reparse", function() if (typer.Rebuild) then typer:Rebuild() end end)
    add("BubbleSize", function(_, w, h)
        if (typer.bubble and typer.BubbleSize) then typer:BubbleSize(w, h) end
    end)
    add("MoveTo", function(_, x, y) typer.x = x typer.y = y end)
    add("Move", function(_, dx, dy) typer.x = (typer.x or 0) + dx typer.y = (typer.y or 0) + dy end)
    add("Destroy", function()
        if (typer.Destroy) then typer:Destroy()
        elseif (Layers and Layers.remove) then Layers.remove(typer)
        elseif (Layers and Layers.Remove) then Layers.Remove(typer) end
    end)

    return proxy
end

if (Typers) then
    -- old instances list name
    if (Typers.insts and not Typers.instances) then
        Typers.instances = Typers.insts
    end
    if (not Typers.clear) then
        Typers.clear = function()
            if (Typers.ClearCache) then pcall(Typers.ClearCache) end
        end
    end

    -- typers.CreateText(sentences, position, layer, bubblesize, progressmode)
    if (EText and EText.New) then
        Typers.CreateText = function(sentences, position, layer, bubblesize, progressmode)
            position  = position or {320, 240}
            bubblesize = bubblesize or {0, 0}
            local typer = EText.New(
                translate_sentences(sentences),
                {position[1] or 320, position[2] or 240},
                layer or 0,
                {bubblesize[1] or 0, bubblesize[2] or 0},
                progressmode or "none"
            )
            return legacy_wrap(typer)
        end
        sset("CreateText", Typers.CreateText)
    end

    -- typers.DrawText(text, position, layer)  -> current InstText (instant)
    if (InstText and InstText.New) then
        Typers.DrawText = function(text, position, layer)
            if (type(text) == "table") then text = text[1] end
            position = position or {320, 240}
            local typer = InstText.New(
                translate_legacy_tags(tostring(text or "")),
                {position[1] or 320, position[2] or 240},
                layer or 0
            )
            return legacy_wrap(typer)
        end
        sset("CreateInstantText", Typers.DrawText)
    end

    -- typers.SpawnBubble(x, y, w, h, layer): best-effort stub (the current EText
    -- builds its own bubble lazily through :ShowBubble()).
    if (not Typers.SpawnBubble) then
        Typers.SpawnBubble = function(x, y, w, h, layer)
            return { x = x, y = y, w = w, h = h, layer = layer }
        end
    end

    sset("typers", Typers)
end

_G.Compat2_0 = compat
return compat