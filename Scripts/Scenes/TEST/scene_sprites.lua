local scene = {}

local spr = Sprites.CreateSprite("WINDOW.png")
spr:SetFourPointMode(true)
spr:SetFourPoint(40, 100, 300, 80, 120, 300, 320, 380)
-- Or set a single point:
spr:SetFourPointP(2, 450, 90)  -- move top-right corner

function scene.update(dt)
end

function scene.draw()
end

function scene.clear()
    Layers.clear()
end

return scene