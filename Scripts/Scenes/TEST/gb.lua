local scene = {}

local gb = ImportFile("Attacks.Blasters")

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

function scene.draw()
end

function scene.clear()
    Layers.clear()
end

return scene