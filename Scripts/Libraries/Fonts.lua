-- Fonts library: every lookup goes through the Game area first, then falls
-- back to the engine directory. Callers may pass a bare filename, an already
-- rooted "Resources/Fonts/..." path, or an explicit Game path.
local fonts = {
    _path  = "Resources/Fonts/",

    -- Per-game override root, checked before _path.
    _gpath = "Game/Resources/Fonts/",
}

--- Test whether a file exists on the LÖVE filesystem.
--- LÖVE 11 returns a table from getInfo while LÖVE 12 returns the info directly;
--- some builds expose neither, so all shapes are tolerated.
---@param path string
---@return boolean
local function fileExists(path)
    if (not path) then return false end

    local ok, info = pcall(function()
        return SE.filesystem.getInfo and SE.filesystem.getInfo(path)
    end)
    if (ok and info) then return true end

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

    -- Already an explicit Game path: leave it, or it would be prefixed twice.
    if (name:sub(1, #fonts._gpath) == fonts._gpath) then
        return name
    end

    -- Leading "/" is a love-fs absolute path; the Game twin and the engine root
    -- are still probed before falling back to the original.
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
--- Extra arguments (size, hinting, dpiscale) are forwarded untouched; a nil
--- path uses the default font.
---@param path? string Font name, already-rooted path, or nil for the default font.
---@return Font
function fonts.New(path, ...)
    if (path == nil) then
        return SE.graphics.newFont(...)
    end
    return SE.graphics.newFont(fonts.ResolvePath(path), ...)
end

return fonts
