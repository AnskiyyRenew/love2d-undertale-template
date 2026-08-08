local shop = {
    main = Typers.EText.New("", {40, 250}, 5),
    background = Sprites.CreateSprite("px.png", 0)
}
Audio.Clear()

local white = Sprites.CreateSprite("px.png", 0)
white.ypivot = 1
white.y = 480
white:Scale(640, 250)
local black = Sprites.CreateSprite("px.png", 0)
black.y = white.y - white.yscale / 2
black:Scale(630, 240)
black.color = {0, 0, 0}
local line = Sprites.CreateSprite("px.png", 0)
line:Scale(5, 240)
line.y = black.y
line.x = 440

function shop.GetBackground()
    return shop.background
end

function shop.SetMainText(text)
    shop.main:SetText(text)
end

function shop.Update(dt)
    
end

return shop