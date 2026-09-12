local scenes = {}
scenes.current = nil
scenes.name_previous = ""
scenes.name_current = ""
scenes.pending_clear = false
scenes._pending_switch = nil

local function normalize_path(path)
    return path:gsub("[/\\]", ".")
end

--- Perform the actual switch: unload the current scene and load the new one.
--- @private
local function doSwitch(sceneName, reset, ...)
    local persistent = false
    normalize_path(sceneName)

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

    if (not persistent) then
        package.loaded["Scripts.Scenes." .. scenes.name_previous] = nil
        package.loaded["Scripts.Scenes.scene_locked"] = nil
    end

    Tween.Clear()
    scenes.name_current = sceneName
    collectgarbage("collect")
    package.loaded["Scripts.Scenes." .. sceneName] = nil

    local ok, loaded = pcall(require, "Scripts.Scenes." .. sceneName)
    if (ok) then
        scenes.current = loaded
        scenes.current.pausing = false
        scenes.current.AllowHot = false

        if (scenes.current.load) then
            scenes.current.load(...)
        end

        print("[Scenes] Scene loaded: " .. sceneName)
    end

    if (isHotReload) then
        scenes.pending_clear = false
        scenes.scene_to_clear = nil
    end
end

--- Switch to a different scene by name. This function will unload the current scene and load the new one.
---@param sceneName string The name of the scene to switch to.
---@param ... any|nil (optional) Additional arguments to pass to the new scene's load function.
function scenes.switchTo(sceneName, ...)
    -- The switch is intentionally deferred to the start of the next frame (see
    -- flushPendingSwitch). This offsets the scene change by one frame from the
    -- input that triggered it (e.g. the confirm press that finished a dialogue),
    -- so the new scene never receives that leftover keypress. It also makes
    -- switchTo safe to call from any callback without recursion.
    scenes._pending_switch = {sceneName, {...}}
end

--- Perform the switch that was requested in the previous frame. Called by main
--- at the start of each frame. Duplicate requests for the scene we are already
--- on are ignored.
function scenes.flushPendingSwitch()
    if (scenes._pending_switch) then
        local p = scenes._pending_switch
        scenes._pending_switch = nil
        doSwitch(p[1], unpack(p[2]))
        if (p[1] ~= scenes.name_current) then
            --doSwitch(p[1], p[2], unpack(p[3]))
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