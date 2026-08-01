local scene = {}
local blasters = require("Scripts.Libraries.Attacks.Blasters")

function scene.load()
    --[[blasters.New(
        {320, -100},
        {220, 220},
        {180, 0},
        40,
        20
    )]]

    blasters.NewTween(
        {{320, 480}, {420, 220}, "QuartOut"},
        {180, 0, "QuartOut"},
        40,
        20
    )
end

function scene.update(dt)
    blasters.Update(dt)
end

function scene.draw()
end

function scene.clear()
    Layers.clear()
end

return scene