-- GameConf -- loads the configuration script, Game area first.
--
--   conf_pure.lua        (root)    engine defaults, always executed
--   Game/conf_pure.lua   (Game)    game-specific overrides, executed after it
--
-- The root copy is ALWAYS run first so every variable has a sane default; the
-- Game copy then only needs to spell out what it wants to change. That is
-- deliberate: conf_pure.lua is not a module with a contract - it is a script
-- that happens to define FPS, Volume, Guard, ... . A Game copy that *replaced*
-- it would leave every variable it forgot undefined (no FPS -> 1/nil, no Guard
-- -> Guard.Update(nil) every frame) and the game would fall over at startup.
-- Overlaying keeps a partial Game copy harmless.
--
-- If the Game copy exists but throws, the configuration is rolled back to the
-- root state (snapshot / restore) and the error is reported loudly - so a
-- broken Game config degrades to "engine defaults", never to "half applied".

local Conf = {}

local ROOT_CONF = "conf_pure.lua"
local GAME_CONF = "Game/conf_pure.lua"

--- Does the file exist? Same probe style as the other Game-first resolvers:
--- never infer existence from a failed load.
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

--- Compile a script from the virtual filesystem (LÖVE's own loader first).
---@param path string
---@return function|nil chunk
---@return string|nil error_message
local function loadChunk(path)
    if (SE and SE.filesystem and SE.filesystem.load) then
        return SE.filesystem.load(path)
    end
    if (love and love.filesystem and love.filesystem.load) then
        return love.filesystem.load(path)
    end
    return loadfile(path)
end

--- Snapshot everything a config script is allowed to change, so a broken Game
--- copy can be undone completely instead of leaving a half-applied config.
---@return table
local function snapshot()
    local vars = {}
    if (type(Global) == "table") then
        for k, v in pairs(Global) do vars[k] = v end
    end
    return {vars = vars, guard = rawget(_G, "Guard")}
end

---@param snap table
local function restore(snap)
    if (not snap) then return end

    if (type(Global) == "table") then
        for k in pairs(Global) do
            if (snap.vars[k] == nil) then Global[k] = nil end
        end
        for k, v in pairs(snap.vars) do Global[k] = v end
    end

    if (snap.guard ~= nil) then
        Guard = snap.guard
    end
end

--- Run one config script. Returns true on success, nil + message on failure.
---@param path string
---@return boolean|nil
---@return string|nil
local function runScript(path)
    local chunk, load_error = loadChunk(path)
    if (type(chunk) ~= "function") then
        return nil, "could not compile: " .. tostring(load_error)
    end

    local ok, message = pcall(chunk)
    if (not ok) then
        return nil, tostring(message)
    end

    return true
end

--- Load the configuration: engine defaults, then the Game overrides.
--- Safe to call again (F2 / hot reload): both scripts are re-executed, not
--- served from the require cache.
function Conf.Load()
    local ok, message = runScript(ROOT_CONF)
    if (not ok) then
        print("[Conf] ERROR: '" .. ROOT_CONF .. "' failed to load: " .. tostring(message))
        return false
    end

    if (not fileExists(GAME_CONF)) then
        return true
    end

    local snap = snapshot()
    local ok_game, message_game = runScript(GAME_CONF)

    if (not ok_game) then
        restore(snap)
        print("[Conf] WARNING: '" .. GAME_CONF .. "' exists but failed to load; " ..
            "using the engine defaults from " .. ROOT_CONF .. " instead.")
        print("[Conf]   " .. tostring(message_game))
        return false
    end

    print("[Conf] applied game configuration from " .. GAME_CONF)
    return true
end

--- True when a Game-side configuration file is present.
---@return boolean
function Conf.HasGameConfig()
    return fileExists(GAME_CONF)
end

return Conf
