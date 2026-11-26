local scene = {}

--- Updates the scene state once per frame.
---@param dt number Delta time in seconds.
function scene.update(dt)
end

--- Draws the scene content once per frame.
function scene.draw()
end

--- Clears every layer when the scene is left.
function scene.clear()
    Layers.clear()
end

return scene