-- Exported by Debugger
local spr = Sprites.CreateSprite("WINDOW.png", 0)
spr:MoveTo(320, 240)
spr:Scale(1, 1)
spr.rotation = 0
spr.alpha = 1
spr.color = {1, 0, 0}
spr.visible = true
spr:SetFourPointMode(true)
spr:SetFourPoint(
    40, 100,  -- top-left
    450, 90,  -- top-right
    120, 300,  -- bottom-left
    320, 380   -- bottom-right
)
