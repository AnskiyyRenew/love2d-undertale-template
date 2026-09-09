---@diagnostic disable: undefined-field

local path = (...):match("(.-)[^%.]+$")
local battle = {
    player = require(path .. "Battle.Player"),
    arenas = require(path .. "Battle.Arenas"),
    ui = require(path .. "Battle.UI"),

    state = "ACTIONSELECT",
    game = nil,

    selected_enemy_index = 0,
    selected_action_index = 0,
    selected_index = 0,
    dialog_texts = nil,

    attack = ImportFile("Battle.PlayerAttacks.stick"),
    attack_paths = {"Scripts.Libraries.Battle.PlayerAttacks.stick"},
    wave = "wave",
    _wave = {},
    restoring_arena = false,

    TIME_F = 0,
    TIME_R = 0,

    EXP = 0,
    GOLD = 0,
    room_end = "scene_end",
    _end = false,
    _end_time = 0
}

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
        package.loaded["Scripts.Waves." .. Battle.wave] = nil
        if (Battle._wave) then
            Battle._wave._end = false
            Battle._wave.objects = {}
            Battle._wave._paths = {}
        end
        Battle._wave = {}
        battle.DefenseEnding()
        battle.mainarena:Resize(565, 130)
        battle.mainarena:RotateTo(0)
        battle.mainarena.is_active = false
        -- Defer the narration text until the arena finishes restoring to full
        -- size (handled in battle.UpdateRestore), so the box visibly scales
        -- back before the text reappears.
        battle.restoring_arena = true
    end

    if (new == "WIN") then
        Player.sprite.visible = false
    end
end

battle.EnteringState = defaultEnteringState
battle.defaultEnteringState = defaultEnteringState

-- Unified state transition: the only way to change the battle state.
-- Whenever the state actually changes, EnteringState is run exactly once,
-- so callers never need to trigger it manually.
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

function battle.Win()
    battle.ChangeState("WIN")
    local texts = Localize.localizeText("Battle.WinTexts1", {Battle.EXP, Battle.GOLD})

    local t = Typers.EText.New(texts, {60, 270}, "UponArena", {0, 0}, "manual")
    t._onComplete = function ()
        battle._end = true
    end
end

function battle.SetGame(file)
    battle.gameName = "Scripts.Game." .. file
    local ok, err = pcall(function ()
        battle.game = require(battle.gameName)
    end)

    if (not ok) then
        print("[Battle System] Error: " .. err)
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
        Battle.ChangeState(game_.state or "ACTIONSELECT")
        UI.buttons.ResetButtons()
        if (Battle.state == "ACTIONSELECT") then
            narration_text:SetText(game_.narration or "")
        end
        UI.barUpdate()

        -- Attach game_apis methods to the encounter table via metatable.
        -- This allows encounter:AddItem(...), encounter:AddEnemy(...),
        -- and encounter:forceAttack(...) to work seamlessly on any loaded game.
        if (type(game_) == "table") then
            setmetatable(game_, {__index = game_apis})
        end

        return battle.game
    end
end

function battle.SetAttackPattern(pattern)
    local _pattern
    local ok, err = pcall(function ()
        _pattern = ImportFile("Battle.PlayerAttacks." .. pattern)
    end)

    if (ok) then
        battle.attack = _pattern

        local _add = true
        for _, v in ipairs(battle.attack_paths)
        do
            if (pattern == v) then
                _add = false
            end
        end

        if (_add) then
            table.insert(battle.attack_paths, pattern)
        end
    else
        battle.attack = ImportFile("Battle.PlayerAttacks.stick")
        print("[Battle - PlayerAttack] Error: " .. err)
    end
end

function battle.Defending()
    Player.sprite:MoveTo(320, 320)
    Battle.mainarena.is_active = true
    Battle.mainarena:Resize(155, 130)

    local _wave = {}
    local ok, err = pcall(function ()
        _wave = require("Scripts.Waves." .. Battle.wave)
    end)

    -- Defensive reset: the wave is the shared "Battle.Waves" table, which may
    -- still hold _end = true from a previous run if cleanup was skipped.
    if (ok) then
        _wave._end = false
        Battle._wave = _wave
    else
        _wave = require("Scripts.Waves.wave")
        _wave._end = false
        Battle._wave = _wave
        print("[Battle - Wave] Error: " .. err)
    end
end

function battle.Update(dt)
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
        v.animation.canspare = v.canspare
        if (v.animation and v.animation.Update) then
            v.animation:Update(dt)
        end
    end

    if (battle._end) then
        battle._end_time = battle._end_time + 1
    end
end

-- Called while returning from DEFENDING to ACTIONSELECT. Defers the narration
-- text until the arena has scaled back to full size (565x130); pressing confirm
-- during the restore snaps the arena to full size so the text can show at once.
function battle.UpdateRestore(dt)
    if (not battle.restoring_arena) then
        return
    end

    local arena = battle.mainarena
    if (Controller.GetState("confirm") == 1) then
        arena:Resize(565, 130, true)
    end

    if (arena.width == arena.target.width and arena.height == arena.target.height) then
        battle.restoring_arena = false
        battle.narration_text:SetText(battle.game.narration)
    end
end

function battle.Clear()
    -- Clear the game module tree so it re-queries Localize on next load
    if battle.gameName then
        ClearModuleTree(battle.gameName)
    end

    -- Clear all loaded attack pattern modules (Scripts.Libraries.Battle.PlayerAttacks.*)
    for i = #battle.attack_paths, 1, -1
    do
        ClearModuleTree(battle.attack_paths[i])
    end

    if (Battle._wave) then
        Battle._wave._end = false
        Battle._wave.objects = {}
        Battle._wave._paths = {}
    end
    Battle._wave = {}
    -- Clear the wave wrapper and reset the shared "Battle.Waves" state so a
    -- future wave doesn't inherit a stale _end = true flag.
    ClearModuleTree("Scripts.Waves." .. Battle.wave)
    battle.restoring_arena = false
    battle.enemy_anims = {}

    -- Clear the entire Battle library tree (UI, buttons, Player, Arenas,
    -- game_apis, Waves, PlayerAttacks, Souls, etc.) in a single pass.
    ClearModuleTree("Scripts.Libraries.Attacks")
    ClearModuleTree("Scripts.Libraries.Battle")
end

return battle