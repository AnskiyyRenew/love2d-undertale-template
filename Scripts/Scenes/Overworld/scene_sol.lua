local scene = {}
local ow = ImportFile("Overworld")
ow.Init("Maps/main_scene/sol.lua")
ow.SetMusic("Start.ogg")

--- Updates the overworld state of the SOL area.
---@param dt number Seconds elapsed since the previous frame.
function scene.update(dt)
    ow.Update(dt)

end

--- Draws the SOL overworld map and its sprites.
function scene.draw()
    ow.Draw()
end

--- Releases the overworld state and clears all layers.
function scene.clear()
    ow.Clear()
    Layers.clear()
end

return scene