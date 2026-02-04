local scenes = {}

scenes.current = nil
scenes.name_previous = ""
scenes.name_current  = ""

function scenes.switchTo(sceneName, ...)
    if (scenes.current) then
        scenes.current.update = function() end
        scenes.current.draw = function() end
        if (scenes.current.clear) then
            scenes.current.clear()
        end
    end

    global:SetVariable("ScreenShaders", {})

    scenes.name_previous = scenes.name_current
    package.loaded["Scripts.Scenes." .. scenes.name_previous] = nil
    scenes.name_current = sceneName
    collectgarbage("collect")
    scenes.current = require("Scripts.Scenes." .. sceneName)
    if (scenes.current.load) then
        scenes.current.load(...)
    end

    print("scene loaded: " .. sceneName)
end

return scenes