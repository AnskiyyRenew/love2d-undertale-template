local scenes = {}
scenes.current = nil
scenes.name_previous = ""
scenes.name_current = ""
scenes.module_current = ""
scenes.pending_clear = false
scenes._pending_switch = nil

scenes.MODULE_ROOTS = {
    "Game.Scenes.",
    "Scripts.Scenes."
}

local function normalize_path(path)
    return path:gsub("[/\\]", ".")
end

--- Turn a switchTo argument into a plain scene name.
--- Accepts "scene_x", "Scenes/scene_x" and "Scripts.Scenes.scene_x" alike.
---@param path string
---@return string
local function sceneNameOf(path)
    local name = normalize_path(path or "")
    name = name:gsub("^%.+", ""):gsub("%.+$", "")
    name = name:gsub("^[Ss]cripts%.", "")
    name = name:gsub("^[Gg]ame%.[Ss]cenes%.", "")
    name = name:gsub("^[Ss]cenes%.", "")
    return name
end

--- Describe a module name as a project-relative file path, for filesystem probes.
---@param module_name string e.g. "Game.Scenes.scene_x"
---@return string e.g. "Game/Scenes/scene_x.lua"
local function modulePathOf(module_name)
    return (module_name:gsub("%.", "/")) .. ".lua"
end

--- Test whether a scene module's file actually exists on disk.
--- LÖVE 11 returns a table from getInfo while LÖVE 12 returns the info directly,
--- so the result is only trusted when truthy.
---@param module_name string
---@return boolean
local function sceneModuleFileExists(module_name)
    local file_path = modulePathOf(module_name)

    local ok, info = pcall(function()
        return SE.filesystem.getInfo and SE.filesystem.getInfo(file_path)
    end)
    if (ok and info) then return true end

    local readable, content = pcall(love.filesystem.read, file_path, 1)
    return (readable and content ~= nil)
end

--- Find the module name of a scene, preferring the Game area.
---
--- A missing FILE falls through to the next root; a file that EXISTS but whose
--- top-level code throws is a real error and must never be reported as "not
--- found". Existence is checked before require for exactly that reason.
---@param name string Plain scene name (e.g. "scene_name").
---@return string|nil moduleName The module that was found, or nil when no root has it.
---@return any loaded The module value returned by require (only when found).
---@return any lookup_error Non-nil when a found scene failed to load: the thrown error.
---@return any first_error
local function findSceneModule(name)
    if (not name) or (name == "") then return nil end

    local found_module = nil
    local found_root = nil
    local first_error = nil
    local first_error_module = nil

    for _, root in ipairs(scenes.MODULE_ROOTS) do
        local module_name = root .. name

        if (sceneModuleFileExists(module_name)) then
            found_module = found_module or module_name
            found_root = found_root or root

            local ok, loaded = pcall(require, module_name)
            if (ok and loaded) then
                if (first_error) then
                    print("[Scenes] WARNING: '" .. tostring(first_error_module) ..
                        "' exists but failed to load; using " .. module_name .. " instead.")
                    print("[Scenes]   " .. tostring(first_error))
                elseif (root ~= scenes.MODULE_ROOTS[1]) then
                    print("[Scenes] WARNING: '" .. name .. "' not found in " ..
                        scenes.MODULE_ROOTS[1] .. " (skipped to " .. root .. name .. ").")
                end
                return module_name, loaded, nil
            end

            if (not first_error) then
                first_error = loaded
                first_error_module = module_name
            end
        end
    end

    if (found_module) then
        if (found_root ~= scenes.MODULE_ROOTS[1]) then
            print("[Scenes] WARNING: '" .. name .. "' not found in " ..
                scenes.MODULE_ROOTS[1] .. " (skipped to " .. found_root .. name .. ").")
        end
        return found_module, nil, (first_error or "unknown error"), first_error_module
    end

    return nil, nil, nil
end

--- Backwards-compatible wrapper returning only a successfully loaded module.
---@param name string Plain scene name.
---@return string|nil moduleName
---@return any loaded
local function resolveSceneModule(name)
    local module_name, loaded = findSceneModule(name)
    return module_name, loaded
end

--- Unload a scene module from the require cache, clearing both roots so a scene
--- that moved between Game and root never stays stale.
---@param name string Plain scene name.
local function unloadSceneModule(name)
    if (not name) or (name == "") then return end
    for _, root in ipairs(scenes.MODULE_ROOTS) do
        package.loaded[root .. name] = nil
    end
end

--- Perform the actual switch: unload the current scene and load the new one.
---@private
---@param sceneName string
---@param ... any
---@param reset boolean
local function doSwitch(sceneName, reset, ...)
    local persistent = false
    sceneName = sceneNameOf(sceneName)

    local isHotReload = reset == "hotreload"

    if (scenes.current) then
        scenes.current.update = function(dt) end
        scenes.current.draw = function() end

        if (not scenes.current.SAVESHADERS) then
            Global.SetVariable("ScreenShaders", {})
        end
        persistent = scenes.current.PERSISTENT

        scenes.current.clear()
        if (isHotReload) then
            scenes.current.clear()
        else
            scenes.pending_clear = true
            scenes.scene_to_clear = scenes.current
        end
    end

    scenes.name_previous = scenes.name_current
    scenes.module_previous = scenes.module_current

    if (not persistent) then
        unloadSceneModule(scenes.name_previous)
        unloadSceneModule("scene_locked")
    end

    Tween.Clear()
    scenes.name_current = sceneName
    scenes.module_current = ""
    collectgarbage("collect")
    unloadSceneModule(sceneName)

    local module_name, loaded, lookup_error, error_module = findSceneModule(sceneName)
    if (module_name and loaded) then
        scenes.current = loaded
        scenes.module_current = module_name
        scenes.current.pausing = false
        scenes.current.AllowHot = false

        if (scenes.current.load) then
            scenes.current.load(...)
        end

        print("[Scenes] Scene loaded: " .. sceneName .. " (" .. module_name .. ")")
    elseif (module_name) then
        print("[Scenes] Failed to load scene '" .. sceneName .. "':")
        print("  [" .. tostring(error_module) .. "] " .. tostring(lookup_error))
        print("[Scenes] Continuing with a no-op stub scene in place of '" .. sceneName .. "'.")

        if (not scenes.current) then
            scenes.current = {
                pausing = false,
                update = function() end,
                draw = function() end,
                clear = function() end
            }
        end
    else
        local tried = {}
        for _, root in ipairs(scenes.MODULE_ROOTS) do
            table.insert(tried, root .. sceneName .. "  (" .. modulePathOf(root .. sceneName) .. ")")
        end

        error("[Scenes] Scene not found: '" .. sceneName .. "'\n" ..
            "  Searched, in order:\n    " .. table.concat(tried, "\n    "), 2)
    end

    if (isHotReload) then
        scenes.pending_clear = false
        scenes.scene_to_clear = nil
    end
end

--- Switch to a different scene by name: unloads the current scene, loads the new one.
---@param sceneName string The name of the scene to switch to.
---@param ... any|nil (optional) Additional arguments to pass to the new scene's load function.
function scenes.switchTo(sceneName, ...)
    scenes._pending_switch = {sceneName, {...}}
end

--- Resolve a scene argument to the module name that would be required for it,
--- preferring the Game area (used by hot-reload tooling).
---@param sceneName string Scene name or path.
---@return string|nil moduleName e.g. "Scripts.Scenes.scene_name".
function scenes.ResolveModule(sceneName)
    return (resolveSceneModule(sceneNameOf(sceneName)))
end

--- Drop a scene from the require cache, under both roots.
---@param sceneName string Scene name or path.
function scenes.UnloadModule(sceneName)
    unloadSceneModule(sceneNameOf(sceneName))
end

--- Perform the switch requested in the previous frame. Called by main at the
--- start of each frame.
function scenes.flushPendingSwitch()
    if (scenes._pending_switch) then
        local p = scenes._pending_switch
        scenes._pending_switch = nil
        doSwitch(p[1], unpack(p[2]))
        if (p[1] ~= scenes.name_current) then
        end
    end
end

function scenes.clearPending()
    if (scenes.pending_clear and scenes.scene_to_clear) then
        if not scenes.scene_to_clear._cleared then
            scenes.scene_to_clear.clear()
            scenes.scene_to_clear._cleared = true
        end
        scenes.pending_clear = false
        scenes.scene_to_clear = nil
    end
end

return scenes
