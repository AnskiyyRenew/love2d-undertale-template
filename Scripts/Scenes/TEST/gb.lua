local scene = {}

local gb = ImportFile("Attacks.Blasters")

--- Steps the blaster manager and spawns blasters from the current mouse position.
---@param dt number Delta time in seconds.
function scene.update(dt)
    gb.Update(dt)

    local mx, my = Keyboard.GetMousePosition()
    if (Keyboard.GetState("d") == 1) then
        print("!!tween!!")
        gb.New(
            {320, -100}, {mx, my},
            {0, math.random(359)},
            40, 80
        )
    elseif (Keyboard.GetState("f") == 1) then
        print("tween")
        gb.NewTween(
            {{320, -100}, {mx, my}, "QuartOut"},
            {0, math.random(359), "QuartOut"},
            40, 80
        )
    end
end

--- Draws nothing; the blasters are rendered by their own attack module.
function scene.draw()
end

--- Removes every layer belonging to the test scene.
function scene.clear()
    Layers.clear()
end

return scene