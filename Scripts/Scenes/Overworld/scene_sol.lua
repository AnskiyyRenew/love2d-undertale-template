local scene = {}
local ow = ImportFile("Overworld")
ow.Init("Maps/main_scene/sol.lua")
ow.SetMusic("Start.ogg")

function scene.update(dt)
    ow.Update(dt)

    
end

function scene.draw()
    ow.Draw()
end

function scene.clear()
    ow.Clear()
    Layers.clear()
end

return scene