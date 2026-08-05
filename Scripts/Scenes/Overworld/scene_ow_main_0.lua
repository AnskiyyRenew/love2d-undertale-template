local scene = {}
local overworld = ImportFile("Overworld")
overworld.Init("Maps/main_scene/main_0.lua")
overworld.SetMusic("Start.ogg")
Camera:setBounds(320, 210, 700, 210)

function scene.update(dt)
    overworld.Update(dt)
end

function scene.draw()
    overworld.Draw()
end

function scene.clear()
    Layers.clear()
    overworld.Clear()
end

return scene