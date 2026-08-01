local scene = {}

Tween.CreateCustomTween("myBezier", function(t)
    local pts = {
        {x = 0.0000, y = 0.0000},
        {x = 0.0000, y = 0.9975},
        {x = 0.7000, y = 0.0575},
        {x = 0.0806, y = 1.0000},
        {x = 0.2111, y = 0.0000},
        {x = 0.5486, y = 0.0000},
        {x = 0.8861, y = 0.0000},
        {x = 1.0000, y = 1.0000},
    }
    local n = #pts
    local px, py = {}, {}
    for i = 1, n do
        px[i], py[i] = pts[i].x, pts[i].y
    end
    for level = n, 2, -1 do
        for i = 1, level - 1 do
            px[i] = px[i] * (1 - t) + px[i + 1] * t
            py[i] = py[i] * (1 - t) + py[i + 1] * t
        end
    end
    return py[1]
end)

local poseur = Sprites.CreateSprite("poseur.png", 0)
poseur.x = 220
Tween.CreateTween(function (v)
    poseur.x = v
end, "myBezier", "", 220, 420, 120)

function scene.update(dt)
end

function scene.draw()
end

function scene.clear()
    Layers.clear()
end

return scene