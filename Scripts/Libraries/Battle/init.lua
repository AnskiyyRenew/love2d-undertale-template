---@diagnostic disable: undefined-field

-- Game-first module resolution. The Game area wins, the engine directory is the
-- fallback:
--   encounters      Game.Encounter.<file>    (Game-only, no engine twin)
--   waves           Game.Waves.<name>      -> Scripts.Waves.<name>
--   attack patterns Game.Attacks.<name>    -> Scripts...Battle.PlayerAttacks.<name>
--   souls           Game.Souls.<name>      -> Scripts...Battle.Player.Souls.<name>
-- Files are probed on disk before require: pcall(require) cannot tell a missing
-- module from one whose top-level code threw.
local BATTLE_MODULE_ROOTS = {
    waves = {"Game.Waves.", "Scripts.Waves."},
    attacks = {"Game.Attacks.", "Scripts.Libraries.Battle.PlayerAttacks."}
}

--- Describe a module name as a project-relative file path, for filesystem probes.
---@param module_name string e.g. "Scripts.Waves.wave"
---@return string e.g. "Scripts/Waves/wave.lua"
local function battleModulePathOf(module_name)
    return (module_name:gsub("%.", "/")) .. ".lua"
end

--- Test whether a module's file actually exists on disk.
--- LÖVE 11 returns a table from getInfo while LÖVE 12 returns the info
--- directly, so a result is only trusted as a positive when it is truthy.
---@param module_name string
---@return boolean
local function battleModuleExists(module_name)
    local file_path = battleModulePathOf(module_name)

    local ok, info = pcall(function()
        return SE.filesystem.getInfo and SE.filesystem.getInfo(file_path)
    end)
    if (ok and info) then return true end

    local readable, content = pcall(love.filesystem.read, file_path, 1)
    return (readable and content ~= nil)
end

--- Require the first module that exists among `roots`, Game area first.
---
--- Game area first. `module_name` is returned whenever the file exists, even
--- when loading it threw; `error_message` then carries the error.
---@param roots string[] Module prefixes to try, in order.
---@param name string Module name suffix (e.g. the wave name).
---@return string|nil module_name
---@return any loaded
---@return any error_message
---@return string|nil error_module
local function requireGameFirst(roots, name)
    -- Every path returns the full 4-value shape: a bare `return nil` collapses to one.
    if (not name) or (name == "") then return nil, nil, nil, nil end

    local found_module = nil
    local found_root = nil
    local first_error = nil
    local first_error_module = nil

    for _, root in ipairs(roots) do
        local module_name = root .. name

        if (battleModuleExists(module_name)) then
            found_module = found_module or module_name
            found_root = found_root or root

            local ok, loaded = pcall(require, module_name)
            if (ok and loaded) then
                if (first_error) then
                    print("[Battle] WARNING: '" .. tostring(first_error_module) ..
                        "' exists but failed to load; using " .. module_name .. " instead.")
                    print("[Battle]   " .. tostring(first_error))
                elseif (root ~= roots[1]) then
                    print("[Battle] WARNING: '" .. name .. "' not found in " ..
                        roots[1] .. " (fell back to " .. module_name .. ").")
                end
                return module_name, loaded, nil, nil
            end

            if (not first_error) then
                first_error = loaded
                first_error_module = module_name
            end
        end
    end

    if (found_module) then
        if (found_root ~= roots[1]) then
            print("[Battle] WARNING: '" .. name .. "' not found in " ..
                roots[1] .. " (fell back to " .. found_module .. ").")
        end
        return found_module, nil, (first_error or "unknown error"), first_error_module
    end

    return nil, nil, nil, nil
end

---Clear a wave module from the require cache under both roots.
---@param wave_name string|nil Defaults to battle.wave when nil.
local function clearWaveModule(wave_name)
    local name = wave_name
    if (not name) or (name == "") then
        name = Battle.wave
    end
    if (not name) or (name == "") then return end

    for _, root in ipairs(BATTLE_MODULE_ROOTS.waves) do
        ClearModuleTree(root .. name)
        package.loaded[root .. name] = nil
    end
end

---Load an attack pattern module, Game area first.
---Declared before `local battle` because the default pattern is resolved while
---that table is being built.
---@param name string e.g. "stick"
---@return table|nil attack Nil when no root has it or every candidate threw.
---@return string|nil module_name The module that was found (nil when none).
local function loadAttackPattern(name)
    local roots = BATTLE_MODULE_ROOTS.attacks
    local module_name, loaded, error_message, error_module = requireGameFirst(roots, name)

    if (loaded) then return loaded, module_name end

    if (module_name) then
        print("[Battle - PlayerAttack] Error in '" .. tostring(error_module) ..
            "': " .. tostring(error_message))
    else
        print("[Battle - PlayerAttack] WARNING: attack pattern '" .. tostring(name) ..
            "' not found. Searched, in order:")
        for _, root in ipairs(roots) do
            print("    " .. root .. name .. "  (" .. battleModulePathOf(root .. name) .. ")")
        end
    end

    return nil, module_name
end


Layers.new_layer("BOTTOM", -1000)
Layers.new_layer("Background", -10)
Layers.new_layer("UI", 0)
Layers.new_layer("ArenasExtraW", 10)
Layers.new_layer("ArenasExtraB", 10.01)
Layers.new_layer("UponArena", 11)
Layers.new_layer("BelowPlayer", 12)
Layers.new_layer("Player", 13)
Layers.new_layer("BelowBullets", 25)
Layers.new_layer("Bullets", 30)
Layers.new_layer("ArenasCoverW", 50)
Layers.new_layer("ArenasCoverB", 50.01)
Layers.new_layer("TopAll", 60)
Layers.new_layer("TOP", 1000)

local path = (...):match("(.-)[^%.]+$")
local default_attack, default_attack_module = loadAttackPattern("stick")
if (not default_attack) then
    error("[Battle - PlayerAttack] the default attack pattern 'stick' could not be loaded.", 0)
end

local battle = {
    player = require(path .. "Battle.Player"),
    arenas = require(path .. "Battle.Arenas"),

    state = "ACTIONSELECT",
    game = nil,

    selected_enemy_index = 0,
    selected_action_index = 0,
    selected_index = 0,
    dialog_texts = nil,

    attack = default_attack,
    -- Resolved module names, so battle.Clear() can drop them from either root.
    attack_paths = {default_attack_module},
    wave = "wave",
    _wave = {},
    restoring_arena = false,

    TIME_F = 0,
    TIME_R = 0,

    EXP = 0,
    GOLD = 0,
    room_end = "scene_end",
    _end = false,
    _end_time = 0,

    -- Set false before SetGame() for a scripted fight that owns Player.hp.
    auto_overworld_sync = true,
    _data_synced = false
}

---Public wrapper so other Battle modules (e.g. UI states) can drop the wave
---module without hard-coding which root it came from. Defined after the `battle`
---table because it assigns a field on that table.
function battle.ClearWaveModule(wave_name)
    clearWaveModule(wave_name)
end

local blacktop = Sprites.CreateSprite("px.png", "TOP")
blacktop:Scale(1000, 1000)
blacktop.alpha = 0
blacktop.color = {0, 0, 0}
blacktop.Step = function (self)
    if (battle._end) then
        self.alpha = self.alpha + 0.05

        if (self.alpha >= 1) then
            Scenes.switchTo(battle.room_end)
        end
    end
end

-- Load battle method APIs for attaching to encounter tables via metatable
local game_apis = require(path .. "Battle.game_apis")

Player = battle.player
Arenas = battle.arenas
battle.ui = require(path .. "Battle.UI")
UI = battle.ui

Player.SetSoul(1)
battle.mainarena = Arenas.New("plus", "rectangle", 320, 320, 565, 130, 0)
battle.mainarena.is_active = false
local narration_text = Typers.EText.New("", {60, 270}, "UponArena", {0, 0}, "none")
battle.narration_text = narration_text

function battle.BattleDialogue(texts, final_state)
    local t = Typers.EText.New(texts, {60, 270}, "UponArena", {0, 0}, "manual")
    t._onComplete = function ()
        Battle.ChangeState(final_state or "ACTIONSELECT")
        Battle.narration_text:SetText(battle.game.narration)
        UI.state.block_transition = true
    end
end

function battle.FullDialogue(texts, call)
    local t = Typers.EText.New(texts, {60, 270}, "UponArena", {0, 0}, "manual")
    t._onComplete = function ()
        call()
    end
end

function battle.DefenseEnding() end
function battle.HandleActions(enemy, action) end
function battle.HandleItems(item) end
-- Override on the battle table for custom spare handling; the default hands the
-- turn back to the enemy.
function battle.HandleSpare() battle.ChangeState("DEFENDING") end
function battle.HandleFlee() end
function battle.FleeUpdate(dt) end
function battle.OnHit(bullet) end

local function defaultEnteringState(old, new)
    if (old == "ACTIONMENU" and new == "DIALOGUERESULT") then
        local enemy = battle.game.enemies[battle.selected_enemy_index]
        local action = enemy.actions[battle.selected_action_index]
        battle.HandleActions(enemy, action)
    elseif (old == "ITEMMENU" and new == "DIALOGUERESULT") then
        local item = battle.game.items[battle.selected_index]
        battle.HandleItems(item)

        for i = #battle.game.items, 1, -1
        do
            local item_ = battle.game.items[i]
            if (i == UI.state.item_slot) then
                if (not item_._cantdestroy) then
                    table.remove(battle.game.items, UI.state.item_slot)
                end
            end
        end
    end
    if (new == "DEFENDING") then
        battle.Defending()
        UI.buttons.ResetButtons()
    elseif (old == "DEFENDING" and new == "ACTIONSELECT") then
        clearWaveModule(Battle.wave)
        if (Battle._wave) then
            Battle._wave._end = false
            Battle._wave.objects = {}
            Battle._wave._paths = {}
        end
        Battle._wave = {}
        battle.DefenseEnding()
        Arenas.Clear()
        battle.mainarena:MoveTo(320, 320)
        battle.mainarena:Resize(565, 130)
        battle.mainarena:RotateTo(0)
        battle.mainarena.is_active = false
        -- Narration reappears once the arena finishes restoring (battle.UpdateRestore).
        battle.restoring_arena = true
    end

    if (new == "WIN") then
        Player.sprite.visible = false
    end
end

battle.EnteringState = defaultEnteringState
battle.defaultEnteringState = defaultEnteringState

-- Single entry point for state changes: EnteringState runs once per real change.
function battle.ChangeState(new_state)
    if (battle.state == new_state) then
        return
    end
    local old = battle.state
    battle.state = new_state
    battle.EnteringState(old, new_state)
end

function battle.SetEndRoom(room)
    battle.room_end = room
end

-- Overworld save-data bridge. `DATA` (Game/Logics) holds the live overworld
-- stats, while an encounter module only defines template values. Runs for every
-- battle while overworld data is loaded, and is idempotent: EXP / GOLD are
-- consumed on write-back, so nothing is ever counted twice.

---Is this battle linked to an overworld save? False for battle-only games,
---where `DATA` is never assigned.
function battle.HasOverworldData()
    if (battle.auto_overworld_sync == false) then return false end
    return (type(DATA) == "table" and type(DATA.player) == "table")
end

---Start the battle with the stats the overworld is carrying. Runs at the end of
---SetGame(), so it overrides the encounter module's template values.
function battle.SyncFromOverworld()
    if (not battle.HasOverworldData()) then return false end

    local p = DATA.player
    Player.name  = (p.name  ~= nil) and p.name  or Player.name
    Player.lv    = (p.lv    ~= nil) and p.lv    or Player.lv
    Player.maxhp = (p.maxhp ~= nil) and p.maxhp or Player.maxhp
    Player.hp    = (p.hp    ~= nil) and p.hp    or Player.hp
    Player.kr    = 0

    if (UI and UI.barUpdate) then UI.barUpdate() end
    return true
end

---Write this battle's results back into the overworld save data: HP, EXP, GOLD
---and any level-ups from `DATA.lv_data`.
function battle.SyncToOverworld()
    if (not battle.HasOverworldData()) then return false end
    if (battle._data_synced) then return false end
    battle._data_synced = true

    local p = DATA.player
    p.exp  = (p.exp  or 0) + (battle.EXP  or 0)
    p.gold = (p.gold or 0) + (battle.GOLD or 0)
    p.hp   = math.max(0, math.min(p.maxhp or Player.maxhp, Player.hp))

    local lv_data = DATA.lv_data
    if (lv_data) then
        local lv = p.lv or 1
        while (lv_data[lv + 1] and p.exp >= lv_data[lv + 1].totalExp) do
            local old_max = p.maxhp
            lv = lv + 1
            p.lv = lv

            local row = lv_data[lv]
            p.maxhp = row.hp
            p.atk   = row.at
            p.def   = row.df

            -- Undertale-style: the gained max HP is added to the current HP.
            p.hp = math.min(p.maxhp, p.hp + (p.maxhp - old_max))
        end
    end

    -- Consume the earnings so a second write-back can never double-count.
    battle.EXP = 0
    battle.GOLD = 0
    return true
end

---Play the victory message. The base lines come from "Battle.WinTexts1"
---(EXP / GOLD), with `extra_texts` appended after them. Scenes override
---`Battle.Win` to react on victory; this implementation stays available as
---`Battle.defaultWin`.
function battle.Win(extra_texts, on_complete)
    battle.ChangeState("WIN")
    local texts = Localize.localizeText("Battle.WinTexts1", {Battle.EXP, Battle.GOLD})

    if (extra_texts) then
        for _, line in ipairs(extra_texts) do
            texts[#texts + 1] = line
        end
    end

    local t = Typers.EText.New(texts, {60, 270}, "UponArena", {0, 0}, "manual")
    t._onComplete = function ()
        if (on_complete) then on_complete() end
        battle._end = true
    end
end
-- Base implementation, kept so a scene can override Battle.Win and still call it.
battle.defaultWin = battle.Win

---Load an encounter script from Game/Encounter/ (there is no engine-side twin),
---then apply its template stats on top of any overworld save data.
function battle.SetGame(file)
    battle.gameName = "Game.Encounter." .. file

    if (not battleModuleExists(battle.gameName)) then
        print("[Battle System] WARNING: encounter '" .. tostring(file) .. "' not found at " ..
            battleModulePathOf(battle.gameName) .. ".")
        return nil
    end

    local ok, err = pcall(function ()
        battle.game = require(battle.gameName)
    end)

    if (not ok) then
        print("[Battle System] Error loading encounter '" .. tostring(file) .. "': " .. tostring(err))
        return nil
    else
        print("[Battle System] Loaded '" .. file .. "' as the battle successfully!")
        local game_ = battle.game
        if (not game_) then return end
        local player_data = game_.player

        if (player_data.name) then Player.name = player_data.name end
        if (player_data.lv) then Player.lv = player_data.lv end
        if (player_data.maxhp) then Player.maxhp = player_data.maxhp end
        if (player_data.hp) then Player.hp = player_data.hp end
        if (game_.wave) then Battle.wave = game_.wave end

        -- Overworld save data wins over the encounter module's template stats.
        battle.SyncFromOverworld()

        Battle.ChangeState(game_.state or "ACTIONSELECT")
        UI.buttons.ResetButtons()
        if (Battle.state == "ACTIONSELECT") then
            narration_text:SetText(game_.narration or "")
        end
        UI.barUpdate()

        -- Attach game_apis so encounter:AddItem / AddEnemy / forceAttack work.
        if (type(game_) == "table") then
            setmetatable(game_, {__index = game_apis})
        end

        return battle.game
    end
end

function battle.SetAttackPattern(pattern)
    local loaded, module_name = loadAttackPattern(tostring(pattern))

    if (loaded) then
        battle.attack = loaded

        local _add = true
        for _, v in ipairs(battle.attack_paths)
        do
            if (module_name == v) then
                _add = false
            end
        end

        if (_add) then
            table.insert(battle.attack_paths, module_name)
        end
        return
    end

    -- Fall back to the default attack pattern so ACTIONSELECT still works.
    print("[Battle - PlayerAttack] Falling back to the default pattern (stick).")
    battle.attack = default_attack
end

---Load a wave script, Game area first. A missing or broken wave falls back to the
---default "wave" script so a battle always has something to run.
function battle.LoadWave(wave_name)
    local name = (wave_name and wave_name ~= "") and wave_name or "wave"
    local roots = BATTLE_MODULE_ROOTS.waves

    local module_name, loaded, error_message, error_module = requireGameFirst(roots, name)
    battle.waveModule = module_name

    if (loaded) then
        return loaded
    end

    if (module_name) then
        print("[Battle - Wave] Error in '" .. tostring(error_module) .. "': " .. tostring(error_message))
    else
        print("[Battle - Wave] WARNING: wave '" .. name .. "' not found. Searched, in order:")
        for _, root in ipairs(roots) do
            print("    " .. root .. name .. "  (" .. battleModulePathOf(root .. name) .. ")")
        end
    end

    -- Fall back through the resolver so a Game-side "wave" override still wins.
    local fallback_module, fallback, fallback_error = requireGameFirst(roots, "wave")
    battle.waveModule = fallback_module or battle.waveModule

    if (fallback) then
        print("[Battle - Wave] Falling back to the default wave (" .. tostring(fallback_module) .. ").")
        return fallback
    end

    print("[Battle - Wave] Error: default wave unavailable: " .. tostring(fallback_error))
    return {}
end

function battle.Defending()
    Player.sprite:MoveTo(320, 320)
    Battle.mainarena.is_active = true
    Battle.mainarena:Resize(155, 130)

    local _wave = battle.LoadWave(Battle.wave)

    -- The wave table is shared: a previous run may have left _end = true behind.
    _wave._end = false
    Battle._wave = _wave
end

-- Debug helpers: jump straight to a wave, and end the current turn early. Both
-- go through the normal transitions, so nothing is left half torn down.

---End the running enemy turn right now, as if its wave had called EndWave().
---Development builds only.
---@return boolean ended
function battle.DebugEndWave()
    if (_RELEASED) then return false end
    if (battle.state ~= "DEFENDING") then return false end
    if (type(battle._wave) ~= "table") then return false end

    if (battle._wave.EndWave) then
        battle._wave.EndWave()
    end
    -- A stale ENDED = true would end the NEXT wave immediately.
    battle._wave.ENDED = false

    battle.ChangeState("ACTIONSELECT")
    print("[Battle - Debug] wave ended early: " .. tostring(battle.wave))
    return true
end

---Load `wave_name` and enter DEFENDING immediately, skipping every earlier turn.
---@param wave_name string Wave name as an encounter's `wave` field takes it.
---@return boolean ok
---@return string|nil error_message
function battle.DebugJumpWave(wave_name)
    if (_RELEASED) then return false, "release build" end
    if (type(wave_name) ~= "string" or wave_name == "") then
        return false, "empty wave name"
    end
    if (not battle.game or not battle.game.enemies) then
        return false, "no encounter loaded"
    end
    if (battle._end or battle.state == "WIN") then
        return false, "battle is already over"
    end

    -- Tear the current turn down the normal way so its bullets get destroyed.
    if (battle.state == "DEFENDING" and type(battle._wave) == "table") then
        if (battle._wave.EndWave) then
            battle._wave.EndWave()
        end
        battle._wave.ENDED = false
    end
    if (battle.state ~= "ACTIONSELECT") then
        battle.ChangeState("ACTIONSELECT")
    end

    -- Drop the cached module so the file's top-level code runs again.
    clearWaveModule(wave_name)

    battle.wave = wave_name
    -- Otherwise UpdateRestore would reveal the narration in the middle of the wave.
    battle.restoring_arena = false
    battle.narration_text:SetText("")

    battle.ChangeState("DEFENDING")

    print("[Battle - Debug] jumped to wave '" .. wave_name ..
        "' (" .. tostring(battle.waveModule) .. ")")
    return true, nil
end

-- Animation dispatch. An animation is a plain table split in two: the MODULE
-- (what require returns, holds the functions) and an INSTANCE (what New(pos)
-- returns, holds the state plus `_class` pointing back at the module).
-- BindAnimation hangs dot-callable closures on the instance; no metatable.

---The function table that drives `anim`: `anim._class`, the module itself for a
---bare module (a scene that never called `Game:InitAnimation`), or nil.
---@param anim any
---@return table|nil
function battle.AnimModule(anim)
    if (type(anim) ~= "table") then
        return nil
    end
    return anim._class or anim
end

---True for an instance produced by `New(pos)` (`_class` is the marker), false
---for a module.
---@param t any
---@return boolean
function battle.IsAnimInstance(t)
    return type(t) == "table" and t._class ~= nil
end

---Hang the module's functions on `instance` as bound, dot-callable methods, so
---callers write `anim.SetFace(3)` instead of `cls.SetFace(anim, 3)`.
---The methods stay on the module (one copy each); each bound closure only
---supplies the instance as its first argument. `New` is skipped, an existing
---field is never overwritten, and calling this twice is a no-op. Colon calls
---raise, so there is exactly one call form.
---@param instance table The object `New(pos)` just returned.
---@param module table|nil Its module; defaults to `instance._class`.
---@return table instance The same table, so calls can be chained.
function battle.BindAnimation(instance, module)
    if (type(instance) ~= "table" or instance._bound) then
        return instance
    end

    module = module or instance._class
    if (type(module) ~= "table") then
        return instance
    end

    for name, fn in pairs(module) do
        if (type(fn) == "function" and name ~= "New" and instance[name] == nil) then
            -- Copied into locals so each closure captures its own pair.
            local method_name, method_fn = name, fn
            instance[name] = function (first, ...)
                if (first == instance) then
                    error("animation methods are dot calls: write anim."
                        .. method_name .. "(...) without self", 2)
                end
                return method_fn(instance, first, ...)
            end
        end
    end

    instance._bound = true
    return instance
end

-- Hitbox viewer (development builds only): F7 toggles an overlay showing the
-- shapes really tested each frame — every `isBullet` sprite plus the player
-- soul(s). Drawn on the TOP layer; unreachable in a release build.
local HITBOX_KEY = "f7"

battle.debug_hitboxes = false
battle.hitbox_sprites = 0
battle.hitbox_shapes = 0

local hitbox_overlay = nil

--- Draw one (possibly rotated) rectangle as a closed outline.
---@param shape table {x, y, w, h, angle}
local function drawHitboxShape(shape)
    local rad = math.rad(shape.angle or 0)
    local cos_a, sin_a = math.cos(rad), math.sin(rad)
    local hw, hh = math.abs(shape.w) * 0.5, math.abs(shape.h) * 0.5

    SE.graphics.polygon("line",
        shape.x - hw * cos_a + hh * sin_a, shape.y - hw * sin_a - hh * cos_a,
        shape.x + hw * cos_a + hh * sin_a, shape.y + hw * sin_a - hh * cos_a,
        shape.x + hw * cos_a - hh * sin_a, shape.y + hw * sin_a + hh * cos_a,
        shape.x - hw * cos_a - hh * sin_a, shape.y - hw * sin_a + hh * cos_a)
end

---Draw one (possibly rotated) ellipse as a closed outline. LÖVE has no rotated
---ellipse, so the points go out as a polygon.
---@param shape table {x, y, w, h, angle}
---@param segments integer|nil Corner count of the approximation; 24 by default.
local function drawEllipseShape(shape, segments)
    segments = segments or 24

    local rad = math.rad(shape.angle or 0)
    local cos_a, sin_a = math.cos(rad), math.sin(rad)
    local rx, ry = math.abs(shape.w) * 0.5, math.abs(shape.h) * 0.5

    local points = {}
    for i = 1, segments do
        local t = (i - 1) / segments * (math.pi * 2)
        local lx, ly = math.cos(t) * rx, math.sin(t) * ry
        points[#points + 1] = shape.x + lx * cos_a - ly * sin_a
        points[#points + 1] = shape.y + lx * sin_a + ly * cos_a
    end

    SE.graphics.polygon("line", points)
end

--- Outline one sprite: the faint box plus the shapes that really collide, in the
--- colour of its role.
---@param sprite Sprite
---@param r number Red
---@param g number Green
---@param b number Blue
---@return integer count How many collision shapes were drawn for this sprite.
local function drawSpriteHitbox(sprite, r, g, b)
    local box = Sprites.GetHitbox(sprite)

    SE.graphics.setColor(r * 0.45, g * 0.45, b * 0.45, 1)
    drawHitboxShape(box)

    local shapes = sprite.pp_collision and Sprites.GetPPShapes(sprite) or nil
    if (shapes and #shapes > 0) then
        SE.graphics.setColor(r, g, b, 1)
        for i = 1, #shapes do
            drawHitboxShape(shapes[i])
        end
        return #shapes
    end

    SE.graphics.setColor(r, g, b, 1)
    if (box.shape == "ellipse") then
        drawEllipseShape(box)
    else
        drawHitboxShape(box)
    end
    return 1
end

--- The overlay's draw function. Runs inside the layer pass (world space, on top
--- of everything) and restores every graphics state it touches, because the
--- layer pass keeps drawing after it.
local function drawHitboxOverlay()
    -- The entry stays registered while hidden (cheaper than re-hooking).
    if (not battle.debug_hitboxes) then
        battle.hitbox_sprites = 0
        battle.hitbox_shapes = 0
        return
    end

    local prev_r, prev_g, prev_b, prev_a = SE.graphics.getColor()
    local prev_width = SE.graphics.getLineWidth()
    local prev_style = SE.graphics.getLineStyle()
    SE.graphics.setLineStyle("rough")
    SE.graphics.setLineWidth(1)

    local sprite_count, shape_count = 0, 0

    -- Souls first (cyan), bullets last (red) so they land on top.
    for _, soul in ipairs(Player.souls) do
        local spr = soul.sprite
        if (spr and spr.image and spr.visible ~= false) then
            shape_count = shape_count + drawSpriteHitbox(spr, 0.35, 1, 1)
            sprite_count = sprite_count + 1
        end
    end
    if (Player.sprite and Player.sprite.image and Player.sprite.visible ~= false) then
        shape_count = shape_count + drawSpriteHitbox(Player.sprite, 0.35, 1, 1)
        sprite_count = sprite_count + 1
    end

    for _, spr in ipairs(Sprites.images) do
        if (spr.isBullet and spr.image and spr.visible ~= false) then
            shape_count = shape_count + drawSpriteHitbox(spr, 1, 0.3, 0.3)
            sprite_count = sprite_count + 1
        end
    end

    SE.graphics.setColor(prev_r, prev_g, prev_b, prev_a)
    SE.graphics.setLineWidth(prev_width)
    if (prev_style) then SE.graphics.setLineStyle(prev_style) end

    battle.hitbox_sprites = sprite_count
    battle.hitbox_shapes = shape_count
end

---Whether the overlay is still hooked into the layer system. A scene clear
---empties the layer lists without flagging the old entry.
---@return boolean
local function hitboxOverlayRegistered()
    return (hitbox_overlay ~= nil) and (Layers.find_by_id(hitbox_overlay._id) == hitbox_overlay)
end

--- Hook the overlay into the layer system (top layer) if it is not already in.
local function registerHitboxOverlay()
    if (hitboxOverlayRegistered()) then return end
    hitbox_overlay = Layers.add_external(drawHitboxOverlay, "TOP")
end

--- Show or hide the hitbox viewer. Without an argument it toggles.
--- Development builds only: does nothing and returns false when released.
---@param show boolean|nil true / false to set it, nil to flip it.
---@return boolean on
function battle.ToggleHitboxes(show)
    if (_RELEASED) then
        return false
    end

    if (show == nil) then
        battle.debug_hitboxes = not battle.debug_hitboxes
    else
        battle.debug_hitboxes = (show == true)
    end

    if (battle.debug_hitboxes) then
        registerHitboxOverlay()
    end

    print("[Battle] Hitbox viewer: " .. (battle.debug_hitboxes and "ON" or "OFF"))
    return battle.debug_hitboxes
end

function battle.Update(dt)
    -- F7 toggles the viewer; re-hooked every frame while on, because a scene
    -- clear wipes the layer system's external draws.
    if (not _RELEASED) then
        if (Keyboard.GetState(HITBOX_KEY) == 1) then
            battle.ToggleHitboxes()
        end
        if (battle.debug_hitboxes) then
            registerHitboxOverlay()
        end
    end

    Player.Update(dt)
    Arenas.Update(dt)
    UI.Update(dt)

    -- Timers
    battle.TIME_F = battle.TIME_F + 1
    battle.TIME_R = battle.TIME_R + dt

    -- Enemies Animation
    if (not battle.game) then return end
    for _, v in ipairs(battle.game.enemies)
    do
        local anim = v.animation
        if (anim) then
            -- Fields monsters commonly read straight off `self`.
            anim.enemy    = v
            anim.canspare = v.canspare
            anim.killable = v.killable
            anim.hp       = v.hp
            anim.maxhp    = v.maxhp
            -- Convenience signal: HP has reached 0 and the enemy is killable.
            anim.dead     = (v.hp ~= nil and v.hp <= 0 and v.killable == true)

            if (type(anim) == "table" and anim._bound and anim.Update) then
                anim.Update(dt)
            end
        end
    end

    if (battle._end) then
        battle._end_time = battle._end_time + 1
    end
end

-- Called on the way back from DEFENDING to ACTIONSELECT. Waits for the arena to
-- finish restoring on its own, then reveals the narration. While the flag is
-- set, state.Update() routes confirm/cancel here, so the menu cannot open early.
function battle.UpdateRestore(dt)
    if (not battle.restoring_arena) then
        return
    end

    local arena = battle.mainarena
    if (arena.width == arena.target.width and arena.height == arena.target.height) then
        battle.restoring_arena = false
        battle.narration_text:SetText(battle.game.narration)
    end
end

function battle.Clear()
    -- Hand HP / EXP / GOLD (and any level-ups) back to DATA before dropping modules.
    battle.SyncToOverworld()

    -- Clear the game module tree so it re-queries Localize on next load
    if battle.gameName then
        ClearModuleTree(battle.gameName)
    end

    -- attack_paths holds resolved names, so both roots are covered; the tree clear
    -- below catches any that were never registered.
    for i = #battle.attack_paths, 1, -1
    do
        ClearModuleTree(battle.attack_paths[i])
    end
    ClearGameTree("Attacks")

    -- Game-area content: without this, re-entering a battle would hand back last
    -- run's modules, state included.
    ClearGameTree("Encounter")
    ClearGameTree("Animations")
    ClearGameTree("Waves")
    ClearGameTree("Souls")

    if (Battle._wave) then
        Battle._wave._end = false
        Battle._wave.objects = {}
        Battle._wave._paths = {}
    end
    Battle._wave = {}
    -- Clear the wave wrapper under both roots and reset the shared wave state.
    clearWaveModule(Battle.wave)
    battle.restoring_arena = false

    -- Clear the whole Battle library tree (UI, buttons, Player, Arenas, ...).
    ClearModuleTree("Scripts.Libraries.Attacks")
    ClearModuleTree("Scripts.Libraries.Battle")
end

return battle