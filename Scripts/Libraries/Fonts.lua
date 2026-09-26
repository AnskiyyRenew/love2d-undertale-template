-- Fonts library.
--
-- Fonts behave like the other resources: every lookup goes through the Game
-- area first, and only falls back to the engine directory when the Game copy
-- does not exist.
--
--     Fonts/           engine default   Resources/Fonts/
--     Game/Fonts/      game override    Game/Resources/Fonts/
--
-- Callers may pass either a bare filename ("determination_mono.ttf"), a name
-- already rooted at the engine directory ("Resources/Fonts/foo.ttf" - what the
-- Typers build internally), or a full explicit Game path. All three shapes
-- resolve to the same place, and the extra Game candidates are only consulted
-- when the original file is missing, so nothing that used to load breaks.
local fonts = {
    _path  = "Resources/Fonts/",

    -- Per-game override root, checked before _path.
    _gpath = "Game/Resources/Fonts/",
}

--- Test whether a file exists on the LÖVE filesystem.
--- LÖVE 11 returns a table from getInfo while LÖVE 12 returns the info directly,
--- and older/odd builds may expose neither, so every shape is tolerated.
---@param path string
---@return boolean
local function fileExists(path)
    if (not path) then return false end

    local ok, info = pcall(function()
        return SE.filesystem.getInfo and SE.filesystem.getInfo(path)
    end)
    if (ok and info) then return true end

    -- Fallback probe: only a real, non-empty readable file counts.
    local readable, data = pcall(function()
        return love.filesystem.read(path, 1)
    end)
    return (readable and data ~= nil)
end

--- Resolve a font name to a real path, preferring the Game copy.
---@param name string
---@return string The path to load, or the engine path when nothing was found.
function fonts.ResolvePath(name)
    if (not name) then return name end
    if (type(name) ~= "string") then return name end

    name = name:gsub("\\", "/")

    -- Already an explicit Game path: leave it alone, otherwise it would be
    -- prefixed a second time ("Game/Resources/Fonts/Game/Resources/Fonts/..")
    -- and the lookup would silently miss.
    if (name:sub(1, #fonts._gpath) == fonts._gpath) then
        return name
    end

    -- Leading slash: an absolute path from the love filesystem root. Mirror
    -- the engine prefix first, the same way the Typers write "/Voices/foo.wav"
    -- meaning "under Resources/Sounds/".
    if (name:sub(1, 1) == "/") then
        local relative = name:gsub("^/+", "")
        if (relative == "") then return name end

        local game_path = fonts._gpath .. relative
        if (fileExists(game_path)) then return game_path end

        if (fileExists(name)) then return name end

        local root_path = fonts._path .. relative
        if (fileExists(root_path)) then return root_path end

        return name
    end

    -- Already rooted: do not prepend anything, just try the Game twin once.
    if (name:sub(1, #fonts._path) == fonts._path) then
        local game_twin = fonts._gpath .. name:sub(#fonts._path + 1)
        if (fileExists(game_twin)) then return game_twin end
        return name
    end

    local game_path = fonts._gpath .. name
    if (fileExists(game_path)) then return game_path end

    return fonts._path .. name
end

--- Create a font, resolving the path Game-first.
--- Mirrors `love.graphics.newFont`, so every extra argument (size, hinting,
--- dpiscale) is forwarded untouched, and a call with no path at all (the
--- "default font" form) still works.
---@param path? string Font name, already-rooted path, or nil for the default font.
---@return Font
function fonts.New(path, ...)
    if (path == nil) then
        return SE.graphics.newFont(...)
    end
    return SE.graphics.newFont(fonts.ResolvePath(path), ...)
end

return fonts
