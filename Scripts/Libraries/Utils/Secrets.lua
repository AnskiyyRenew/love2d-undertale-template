-- Secrets.lua
-- Native secret store: pulls secrets out of a compiled shared library so they
-- never appear as plain text inside the .love archive.
--
-- Loaded through LuaJIT FFI. IMPORTANT: ffi.load goes through the OS loader
-- (LoadLibrary / dlopen), NOT through LÖVE's virtual filesystem -- "Resources/
-- Libs/..." only means something to love.filesystem, so every candidate has to
-- be a real OS path. See DiscordRPC.lua:134 for the same trap, already solved
-- there; this module reuses that approach.
--
-- Fallback contract (must never hard-fail):
--   native library -> Secrets.fallback table -> nil
-- A missing library is normal: a dev machine without a build, or the web
-- (love.js) target which has no native libraries at all. Callers must treat
-- nil as "feature unavailable" and degrade quietly.
--
-- Usage:
--   local Secrets = ImportFile("Utils.Secrets")
--   local pk = Secrets.gamejoltPK()          -- nil when unavailable
--   if Secrets.available() then ... end
--   print(Secrets.source())                  -- "native" / "fallback" / "none"

local Secrets = {}

local ffi = nil
do
    local ok, m = pcall(require, "ffi")
    if ok and m then ffi = m end
end

---Must match PROBE_MAGIC in gen_source.py.
local PROBE_MAGIC = 0x5EC0DE

---Slot indices. Mirrors SLOT_ORDER in gen_source.py -- append only.
Secrets.SLOT_GAMEJOLT_PK = 0

---Plain-text fallback values, keyed by slot. Filled from conf_pure.lua
---(GamejoltPK) at init; a project may also set these directly.
Secrets.fallback = {}

---@type any|nil Loaded FFI namespace, or nil.
Secrets._lib = nil
---@type string|nil Path that actually loaded, for diagnostics.
Secrets._path = nil
---@type string|nil Why the native library could not be loaded.
Secrets._error = nil
---@type boolean Set once the load has been attempted; do not retry every call.
Secrets._tried = false


-- 1. Platform and file name


local function os_name()
    local ok, v = pcall(function()
        if SE and SE.system and SE.system.getOS then return SE.system.getOS() end
        if love and love.system and love.system.getOS then return love.system.getOS() end
        return "Unknown"
    end)
    if ok and type(v) == "string" then return v end
    return "Unknown"
end

local function lib_names(platform)
    if platform == "Windows" then
        return { "secrets.dll" }
    elseif platform == "Android" or platform == "Linux" then
        -- Android resolves a bare soname through the app's nativeLibraryDir,
        -- which is where the packager puts the jniLibs.
        return { "libsecrets.so" }
    elseif platform == "OS X" or platform == "iOS" then
        return { "libsecrets.dylib" }
    end
    return nil
end


-- 2. Real OS paths (ffi.load does not see LÖVE's virtual filesystem)


---Resolves the directory the game actually lives in on disk.
local function source_dir()
    local ok_s, s = pcall(function() return SE.filesystem.getSource() end)
    local ok_b, b = pcall(function() return SE.filesystem.getSourceBaseDirectory() end)
    if (ok_s and type(s) == "string" and s ~= "") then
        s = s:gsub("\\", "/"):gsub("/+$", "")
        -- Bare folder name -> combine with the base directory.
        if (s:match("^%a:") or s:match("^/")) then
            return s
        elseif (ok_b and type(b) == "string" and b ~= "") then
            return b:gsub("\\", "/"):gsub("/+$", "") .. "/" .. s
        end
    end
    if (ok_b and type(b) == "string" and b ~= "") then
        return b:gsub("\\", "/"):gsub("/+$", "")
    end
    return nil
end

local function candidates(platform, names)
    local dirs = {}
    local src = source_dir()
    if src then
        -- Source checkout: the library sits next to the other engine libs.
        dirs[#dirs + 1] = src .. "/Resources/Libs/Secrets/"
        -- Fused exe: getSource() points at the exe itself, so probe its folder
        -- too (that is where the packager drops the dll).
        dirs[#dirs + 1] = src .. "/"
        dirs[#dirs + 1] = src .. "/Resources/Libs/"
    end
    -- Relative fallbacks; only resolve when CWD happens to be the game folder.
    dirs[#dirs + 1] = "Resources/Libs/Secrets/"
    dirs[#dirs + 1] = ""
    dirs[#dirs + 1] = "./"

    local out = {}
    for _, d in ipairs(dirs) do
        for _, n in ipairs(names) do
            out[#out + 1] = d .. n
        end
    end
    return out
end


-- 3. Loading


local function load_native()
    if (not ffi) then
        Secrets._error = "ffi unavailable"
        return nil
    end
    local platform = os_name()
    local names = lib_names(platform)
    if (not names) then
        Secrets._error = "unsupported platform: " .. platform
        return nil
    end

    local ok_def, def_err = pcall(ffi.cdef, [[
        const char *se_cfg(int slot);
        int se_cfg_probe(void);
    ]])
    if (not ok_def) then
        Secrets._error = "ffi.cdef failed: " .. tostring(def_err)
        return nil
    end

    local errors = {}
    for _, path in ipairs(candidates(platform, names)) do
        local ok_load, lib = pcall(ffi.load, path)
        if (ok_load and lib) then
            local ok_probe, magic = pcall(function() return lib.se_cfg_probe() end)
            if (ok_probe and magic == PROBE_MAGIC) then
                Secrets._path = path
                return lib
            end
            errors[#errors + 1] = path .. " (loaded, probe mismatch: "
                                  .. tostring(magic) .. ")"
        else
            errors[#errors + 1] = path .. " -> " .. tostring(lib)
        end
    end
    Secrets._error = table.concat(errors, "\n")
    return nil
end

local function ensure()
    if Secrets._tried then return end
    Secrets._tried = true
    wire_fallback()
    Secrets._lib = load_native()
end


-- 4. Fallback wiring


---Copies conf_pure.lua's plain-text values into the fallback table.
---Runs once at init so a dev machine without a compiled library still works.
local _wired = false
local function wire_fallback()
    if _wired then return end
    _wired = true
    local ok_g, g = pcall(function() return Global end)
    if (not ok_g or type(g) ~= "table" or type(g.GetVariable) ~= "function") then
        return
    end
    local ok_v, pk = pcall(function() return g.GetVariable("GamejoltPK") end)
    if (ok_v and type(pk) == "string" and pk ~= "") then
        Secrets.fallback[Secrets.SLOT_GAMEJOLT_PK] = pk
    end
end


---Initialises the store. Safe to call more than once; also runs lazily on the
---first get(), so callers do not have to remember to call it.
---@return boolean native True when the native library was loaded.
function Secrets.init()
    wire_fallback()
    ensure()
    return Secrets._lib ~= nil
end


-- 5. Public API


---True when secrets come from the compiled native library.
---@return boolean
function Secrets.available()
    ensure()
    return Secrets._lib ~= nil
end

---Where the current value would come from: "native", "fallback" or "none".
---@return string
function Secrets.source()
    ensure()
    if Secrets._lib then return "native" end
    for _, v in pairs(Secrets.fallback) do
        if v then return "fallback" end
    end
    return "none"
end

---Diagnostics string: loaded path, or every path tried and why it failed.
---@return string
function Secrets.status()
    ensure()
    if Secrets._lib then
        return "native: " .. tostring(Secrets._path)
    end
    return "native unavailable: " .. tostring(Secrets._error or "not attempted")
end

---Fetches a secret by slot, falling back to plain text when the library is
---missing. Returns nil when neither is available.
---@param slot integer
---@return string|nil
function Secrets.get(slot)
    ensure()
    if Secrets._lib then
        local ok, ptr = pcall(function() return Secrets._lib.se_cfg(slot) end)
        if (ok and ptr ~= nil) then
            local ok_s, str = pcall(ffi.string, ptr)
            if (ok_s and str ~= nil and str ~= "") then return str end
        end
    end
    return Secrets.fallback[slot]
end

---Convenience accessor for the GameJolt private key.
---@return string|nil
function Secrets.gamejoltPK()
    return Secrets.get(Secrets.SLOT_GAMEJOLT_PK)
end

---Registers a plain-text fallback for a slot (used on the web target, where
---no native library can exist).
---@param slot integer
---@param value string|nil
function Secrets.setFallback(slot, value)
    Secrets.fallback[slot] = value
end

return Secrets
