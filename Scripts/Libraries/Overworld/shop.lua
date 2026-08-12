local shop = {
    data = DATA.player,
    main = Typers.EText.New("", {40, 260}, 5),
    background = Sprites.CreateSprite("px.png", 0)
}
local blacktop = Sprites.CreateSprite("px.png", 100)
blacktop:Scale(1000, 1000)
blacktop.color = {0, 0, 0}
blacktop:MoveTo(Camera.x, Camera.y)
blacktop._decay = true
blacktop.Step = function (self)
    self:MoveTo(Camera.x, Camera.y)
    if (self._decay) then
        self.alpha = self.alpha - 0.05
        if (shop._leaving) then
            self._decay = false
        end
        if (self.alpha <= 0) then
            self._decay = false
        end
    else
        if (self.alpha >= 1) then
            self._decay = true
        end
    end

    if (shop._leaving) then
        self.alpha = self.alpha + 0.05

        if (self.alpha >= 1) then
            Scenes.switchTo(shop.target_scene)
        end
    end
end
Audio.Clear()

-- Boards
local white = Sprites.CreateSprite("px.png", 0)
white.ypivot = 1
white.y = 480
white:Scale(640, 240)
local black = Sprites.CreateSprite("px.png", 0)
black.y = white.y - white.yscale / 2
black:Scale(630, 230)
black.color = {0, 0, 0}
local line = Sprites.CreateSprite("px.png", 0)
line:Scale(5, 230)
line.y = black.y
line.x = 430

-- Typers
local actions = {"Buy", "Sell", "Talk", "Exit"}
for i = 1, 4
do
    local t = Typers.InstText.New(Localize.localizeText("Overworld.Shop.Action." .. actions[i]), {485, 260 + (i - 1) * 40}, 1)
end
local t_gold = Typers.InstText.New(shop.data.gold .. "G", {465, 420}, 1)
local t_inv = Typers.InstText.New(#shop.data.items .. "/8", {600, 420}, 1)
t_inv:SetAlign("right")

function shop.GetBackground()
    return shop.background
end

function shop.SetMainText(text)
    shop.main:SetText(text)
end

function shop.Update(dt)
    
end

return shop