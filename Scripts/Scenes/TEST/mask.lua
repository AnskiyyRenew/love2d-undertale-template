local scene = {}

local white = Sprites.CreateSprite("px.png", 0)
white:Scale(165, 140)
local black = Sprites.CreateSprite("px.png", 0)
black.color = {0, 0, 0}
black:Scale(155, 130)

local mask = Masks.New("rectangle", 320, 240, 155, 130, 0, 0)
local poseur = Sprites.CreateSprite("poseur.png", 2)
poseur:SetStencils({mask})

function scene.update(dt)
    mask:Follow(black)

    poseur:MoveTo(Keyboard.GetMousePosition())
    white.rotation = white.rotation - 2
    black.rotation = black.rotation - 2
end

function scene.draw()
end

function scene.clear()
    Layers.clear()
end

return scene