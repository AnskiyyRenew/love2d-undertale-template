-- HackLoader -- game-side "hack" injection for engine internals.
--
-- Engine libraries under Scripts.Libraries are NOT part of the Game override
-- mechanism (only scenes / waves / souls / maps / resources are). Some things -
-- the battle UI, battle flow, sprite behaviour - can therefore only be changed
-- by editing the engine, which a game author must not do.
--
-- This module gives the Game area a supported way in:
--
--   Game/Hacks/*.lua     run once at startup, after every engine library has
--                        been loaded but before the first scene is switched to.
--
-- Three primitives, enough for both "tweak one function" and "replace a whole
-- subsystem":
--
--   Hack.Replace(engine_module, game_module)
--       Whole-module replacement, applied through package.preload so it also
--       wins for modules that are loaded LAZILY later on (Battle, UI, ...).
--       If the engine module is already loaded the fields are hot-swapped in
--       place (and a warning is printed) instead of pretending it worked.
--
--   Hack.After(module_name, fn)
--       Run `fn(module)` as soon as `module_name` is loaded - now if it already
--       is, otherwise the moment it gets required. This is the only way to
--       touch lazily loaded globals such as Battle / UI.
--
--   Hack.Wrap(owner, key, wrapper) / Hack.Set(owner, key, value)
--       Function-level surgery. `wrapper` receives the ORIGINAL function as its
--       first argument. Both record the previous value so Hack.Unapply() can
--       put everything back.
--
-- Load order / isolation:
--   * Files are sorted by their numeric filename prefix (010_x.lua before
--     020_y.lua); files starting with "_" are plain modules, never entry points.
--   * One broken hack is reported loudly and skipped - it never prevents the
--     rest from loading, and never blocks the game from starting.
--   * Wrapping the same owner.key twice prints a WARNING: later hacks wrap
--     around earlier ones, so order decides who sees the call first.
--   * Hack.Unapply() undoes every patch and installed loader, so F5 (which
--     clears Scripts.Libraries) can replay the hacks on the fresh modules
--     instead of stacking wrappers on top of wrappers.

local Hack = {}

-- Registry kept in a GLOBAL: F5 calls ClearModuleTree("Scripts.Libraries"),
-- which drops this very module from package.loaded. A module-local table would
-- be silently replaced by an empty one and Unapply() would lose every original.
local state = _HACK_STATE
if (not state) then
    state = {
        overrides = {},  -- engine module name -> Game module name
        after     = {},  -- module name -> {fn, ...}
        loaders   = {},  -- module name -> previous package.preload entry (false = none)
        applied   = {},  -- hack module name -> display name
        patches   = {}   -- applied field patches, newest last (Unapply walks back)
    }
    _HACK_STATE = state
end

local function warn(message)
    print("[Hack] WARNING: " .. tostring(message))
end

local function err(message)
    print("[Hack] ERROR: " .. tostring(message))
end

-- ---------------------------------------------------------------------------
-- module loading helpers
-- ---------------------------------------------------------------------------

--- Load a module the way require() would, ignoring package.preload (so our own
--- loader can never recurse into itself).
---@param module_name string
---@return any
local function loadModuleFromSearchers(module_name)
    local searchers = package.searchers or package.loaders
    local saved = package.preload[module_name]
    package.preload[module_name] = nil

    local ok, mod = pcall(function()
        for _, searcher in ipairs(searchers) do
            local loader, data = searcher(module_name)
            if (type(loader) == "function") then
                return loader(module_name, data)
            end
        end
        error("module '" .. tostring(module_name) .. "' not found by any searcher")
    end)

    package.preload[module_name] = saved
    if (not ok) then error(mod, 0) end

    -- Lua 5.1 turns a loader that returns nil into `true` in package.loaded.
    if (mod == nil) then mod = package.loaded[module_name] end
    return mod
end

--- Run the Hack.After callbacks registered for a module.
---@param module_name string
---@param mod any
local function fireAfter(module_name, mod)
    local hooks = state.after[module_name]
    if (not hooks) then return end

    for _, fn in ipairs(hooks) do
        local ok, message = pcall(fn, mod, module_name)
        if (not ok) then
            err("after-hook for '" .. module_name .. "' failed: " .. tostring(message))
        end
    end
end

--- Install a package.preload loader that (a) honours Hack.Replace, and
--- (b) fires the after-hooks. Kept installed so a later reload (F5) is
--- patched again instead of slipping through un-hacked.
---
--- The "already installed" mark is the ENTRY TABLE itself, not `previous`:
--- `previous` is nil for most modules and nil/false cannot be told apart from
--- "not installed", which made a second call capture our own loader as the
--- previous one and chain wrappers together.
---@param module_name string
local function ensureLoader(module_name)
    if (state.loaders[module_name]) then return end

    local previous = package.preload[module_name]
    state.loaders[module_name] = {previous = previous}

    package.preload[module_name] = function(name)
        local mod
        local override = state.overrides[module_name]

        if (override) then
            local ok, res = pcall(require, override)
            if (not ok) then error(res, 0) end
            mod = res
        elseif (previous) then
            mod = previous(name)
        else
            mod = loadModuleFromSearchers(name)
        end

        if (mod == nil) then mod = package.loaded[name] end
        fireAfter(module_name, mod)
        return mod
    end
end

--- Record a field so Hack.Unapply() can restore it.
---@param owner table
---@param key any
---@param original any
---@param kind string
---@param label string|nil
local function recordPatch(owner, key, original, kind, label)
    state.patches[#state.patches + 1] = {
        owner = owner, key = key, original = original, kind = kind, label = label
    }
end

--- Copy every field of `patch` into `owner`, recording the previous values.
---@param owner table
---@param patch table
---@param label string|nil
local function patchFields(owner, patch, label)
    for k, v in pairs(patch) do
        if (type(v) == "table" and type(owner[k]) == "table") then
            patchFields(owner[k], v, label)
        else
            recordPatch(owner, k, owner[k], "set", label)
            owner[k] = v
        end
    end
end

-- ---------------------------------------------------------------------------
-- public API
-- ---------------------------------------------------------------------------

--- Replace an engine module with a module from the Game area.
--- Works for modules that are not loaded yet (the normal case - Battle and UI
--- are required lazily by battle scenes). If the target is already loaded the
--- fields are hot-swapped instead, with a warning.
---@param engine_module string e.g. "Scripts.Libraries.Battle.UI"
---@param game_module string e.g. "Game.Hacks.MyBattleUI"
function Hack.Replace(engine_module, game_module)
    if (type(engine_module) ~= "string" or type(game_module) ~= "string") then
        error("Hack.Replace: both arguments must be module name strings", 2)
    end

    local existing = state.overrides[engine_module]
    if (existing and existing ~= game_module) then
        warn("'" .. engine_module .. "' is already replaced by '" .. existing ..
            "'; '" .. game_module .. "' wins.")
    end
    state.overrides[engine_module] = game_module
    ensureLoader(engine_module)

    if (package.loaded[engine_module]) then
        warn("'" .. engine_module .. "' was already loaded; hot-swapping its fields " ..
            "instead of a clean replace (some code may hold the old functions).")
        local ok, mod = pcall(require, game_module)
        if (not ok or type(mod) ~= "table") then
            err("replacement '" .. game_module .. "' could not be loaded: " .. tostring(mod))
            return
        end
        patchFields(package.loaded[engine_module], mod, "replace:" .. engine_module)
    end
end

--- Run `fn(module, module_name)` as soon as `module_name` is loaded.
--- This is the hook to use for lazily loaded globals (Battle, UI, ...): at
--- startup they do not exist yet, so they cannot be patched directly.
---@param module_name string
---@param fn function
function Hack.After(module_name, fn)
    if (type(module_name) ~= "string" or type(fn) ~= "function") then
        error("Hack.After: expected (module_name: string, fn: function)", 2)
    end

    state.after[module_name] = state.after[module_name] or {}
    table.insert(state.after[module_name], fn)

    if (package.loaded[module_name]) then
        local ok, message = pcall(fn, package.loaded[module_name], module_name)
        if (not ok) then
            err("after-hook for '" .. module_name .. "' failed: " .. tostring(message))
        end
    else
        ensureLoader(module_name)
    end
end

--- Overwrite one field, remembering the old value.
---@param owner table
---@param key any
---@param value any
---@param label string|nil Shown in warnings about conflicting patches.
function Hack.Set(owner, key, value, label)
    if (type(owner) ~= "table") then
        error("Hack.Set: owner must be a table", 2)
    end
    recordPatch(owner, key, owner[key], "set", label)
    owner[key] = value
end

--- Wrap a function: `wrapper(original, ...)` replaces `owner[key]`.
---@param owner table
---@param key any
---@param wrapper function
---@param label string|nil Shown in warnings about conflicting patches.
function Hack.Wrap(owner, key, wrapper, label)
    if (type(owner) ~= "table") then
        error("Hack.Wrap: owner must be a table", 2)
    end
    if (type(wrapper) ~= "function") then
        error("Hack.Wrap: wrapper must be a function", 2)
    end

    local original = owner[key]
    if (type(original) ~= "function") then
        warn("Hack.Wrap: '" .. tostring(key) .. "' is not a function (" ..
            type(original) .. "); nothing was wrapped.")
        return
    end

    for _, patch in ipairs(state.patches) do
        if (patch.owner == owner and patch.key == key) then
            warn("'" .. tostring(key) .. "' is already patched by '" ..
                tostring(patch.label or "?") .. "'; '" .. tostring(label or "?") ..
                "' now wraps on top of it.")
            break
        end
    end

    recordPatch(owner, key, original, "wrap", label)
    owner[key] = function(...)
        return wrapper(original, ...)
    end
end

--- Deep-merge a patch table into an existing table (tables merge, other values
--- overwrite). Every replaced leaf is recorded.
---@param owner table
---@param patch table
---@param label string|nil
function Hack.Patch(owner, patch, label)
    if (type(owner) ~= "table" or type(patch) ~= "table") then
        error("Hack.Patch: expected (owner: table, patch: table)", 2)
    end
    patchFields(owner, patch, label)
end

-- ---------------------------------------------------------------------------
-- loading / unloading
-- ---------------------------------------------------------------------------

local HACK_DIR = "Game/Hacks"

--- Does the file exist? Never infer it from a failed load.
---@param path string
---@return boolean
local function fileExists(path)
    local ok, info = pcall(function()
        return SE.filesystem.getInfo and SE.filesystem.getInfo(path)
    end)
    if (ok and info) then return true end

    local readable, content = pcall(love.filesystem.read, path, 1)
    return (readable and content ~= nil)
end

--- Declarative overrides: Game/Overrides.lua returns a plain mapping of
---   engine module name -> Game module name
--- so "swap this whole subsystem" needs no Lua logic at all. It rides on the
--- very same preload machinery as Hack.Replace - this is only a friendlier
--- front door, not a second mechanism.
local OVERRIDES_FILE = "Game/Overrides.lua"
local OVERRIDES_MODULE = "Game.Overrides"

local function loadOverrides()
    if (not fileExists(OVERRIDES_FILE)) then return end

    local ok, mod = pcall(require, OVERRIDES_MODULE)
    if (not ok) then
        err("'" .. OVERRIDES_FILE .. "' failed to load: " .. tostring(mod))
        return
    end
    if (type(mod) ~= "table") then
        warn("'" .. OVERRIDES_FILE .. "' must return a table of " ..
            "{[engine module] = game module}; got " .. type(mod) .. ".")
        return
    end

    local keys = {}
    for k in pairs(mod) do keys[#keys + 1] = k end
    table.sort(keys)

    for _, engine_module in ipairs(keys) do
        local game_module = mod[engine_module]
        if (type(engine_module) == "string" and type(game_module) == "string") then
            print("[Hack] override: " .. engine_module .. " -> " .. game_module)
            Hack.Replace(engine_module, game_module)
        else
            warn("'" .. OVERRIDES_FILE .. "' entry '" .. tostring(engine_module) ..
                "' must map a string to a string; skipped.")
        end
    end
end

--- List the hack entry-point files, numeric prefix first, "_"-files skipped.
---@return string[]
local function listHackFiles()
    local ok, items = pcall(function()
        return SE.filesystem.getDirectoryItems and SE.filesystem.getDirectoryItems(HACK_DIR)
    end)
    if (not ok) or (type(items) ~= "table") then
        ok, items = pcall(function()
            return love.filesystem.getDirectoryItems(HACK_DIR)
        end)
    end
    if (not ok) or (type(items) ~= "table") then return {} end

    local files = {}
    for _, name in ipairs(items) do
        if (name:sub(1, 1) ~= "_" and name:match("%.lua$")) then
            files[#files + 1] = name
        end
    end

    table.sort(files, function(a, b)
        local na = tonumber(a:match("^(%d+)")) or math.huge
        local nb = tonumber(b:match("^(%d+)")) or math.huge
        if (na ~= nb) then return na < nb end
        return a < b
    end)

    return files
end

--- Load and run every hack in Game/Hacks/, plus the declarative
--- Game/Overrides.lua mapping. Safe to call again after Unapply().
function Hack.Load()
    -- Declarative overrides first: they are the "swap this whole module" case,
    -- and a hack that replaces the same module then wins (with a warning).
    loadOverrides()

    local files = listHackFiles()
    if (#files == 0) then
        Hack.Report()
        return
    end

    for _, file in ipairs(files) do
        local module_name = "Game.Hacks." .. (file:gsub("%.lua$", ""))

        if (not state.applied[module_name]) then
            local ok, mod = pcall(require, module_name)
            if (not ok) then
                err("'" .. file .. "' failed to load: " .. tostring(mod))
            else
                local apply = (type(mod) == "function") and mod
                    or (type(mod) == "table" and mod.apply)

                if (type(apply) ~= "function") then
                    warn("'" .. file .. "' returns neither a function nor an " ..
                        "{apply = function} table; skipped.")
                else
                    local ok2, message = pcall(apply, Hack)
                    if (not ok2) then
                        err("'" .. file .. "' apply() failed: " .. tostring(message))
                    end
                end

                state.applied[module_name] = (type(mod) == "table" and mod.name) or file
            end
        end
    end

    Hack.Report()
end

--- Undo everything: restore patched fields and remove installed loaders.
--- Used before F5 clears Scripts.Libraries, so hacks replay on fresh modules
--- instead of piling wrapper on wrapper.
function Hack.Unapply()
    for i = #state.patches, 1, -1 do
        local patch = state.patches[i]
        if (patch.owner and patch.key ~= nil) then
            patch.owner[patch.key] = patch.original
        end
        state.patches[i] = nil
    end

    for module_name, entry in pairs(state.loaders) do
        -- entry.previous is nil when nothing was registered before us, which
        -- removes our loader entirely.
        package.preload[module_name] = entry.previous
    end

    -- Drop the hack modules from the require cache too, so a reload actually
    -- picks up edits made to Game/Hacks/*.lua and Game/Overrides.lua instead of
    -- re-running the code that was loaded at startup.
    package.loaded[OVERRIDES_MODULE] = nil
    for module_name in pairs(state.applied) do
        package.loaded[module_name] = nil
    end

    state.loaders = {}
    state.overrides = {}
    state.after = {}
    state.applied = {}
end

--- Print what is currently applied (used at startup and by the F6 debug dump).
function Hack.Report()
    local count = 0
    for _ in pairs(state.applied) do count = count + 1 end

    if (count == 0) then return end

    print("[Hack] " .. count .. " hack(s) applied:")
    for module_name, name in pairs(state.applied) do
        print("[Hack]   - " .. tostring(name) .. "  (" .. module_name .. ")")
    end
    print("[Hack] " .. #state.patches .. " patched field(s), " ..
        (function()
            local n = 0
            for _ in pairs(state.loaders) do n = n + 1 end
            return n
        end)() .. " module loader(s) installed, " ..
        (function()
            local n = 0
            for _ in pairs(state.overrides) do n = n + 1 end
            return n
        end)() .. " override(s).")
end

--- Number of applied hacks (for debug output when there is nothing to list).
---@return integer
function Hack.Count()
    local count = 0
    for _ in pairs(state.applied) do count = count + 1 end
    return count
end

return Hack
