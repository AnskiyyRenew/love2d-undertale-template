local shop = {
    data = DATA.player,
    main = Typers.EText.New("", {40, 260}, 5, {0, 0}, "none"),
    background = Sprites.CreateSprite("px.png", 0),
    player = Sprites.CreateSprite("Soul Library Sprites/spr_default_heart.png", 2),
    textend = "* cya.",

    _leavekey = false,
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
            Scenes.switchTo(DATA.room)
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
shop.player.color = {1, 0, 0}

-- Typers
local actions = {
    "Buy",
    "Sell",
    "Talk",
    "Exit"
}
local buttons = {}
for i = 1, 4
do
    local t = Typers.InstText.New(Localize.localizeText("Overworld.Shop.Action." .. actions[i]), {485, 260 + (i - 1) * 40}, 1)
    table.insert(buttons, t)
end
local t_gold = Typers.InstText.New(shop.data.gold .. "G", {465, 420}, 1)
local t_inv = Typers.InstText.New(#shop.data.items .. "/8", {600, 420}, 1)
t_inv:SetAlign("right")

local goods_per_page = 5
local goods_buttons = {}
for i = 1, goods_per_page
do
    local t = Typers.InstText.New("", {75, 260 + (i - 1) * 40}, 1)
    table.insert(goods_buttons, t)
end

-- V
local goods = {}
local prices = {}
local states = {"BUY", "SELL", "TALK"}
local choosing_page = "IDLE"
local choosing_b = 1
local choosing_a = 1
local goods_startpos = 0

local text_pointer = Typers.InstText.New("1 / 1", {10, 460}, 2)
text_pointer.font = "Crypt Of Tomorrow.ttf"
text_pointer.fontsize = 16
text_pointer.alpha = 0

local function updateTextPointer()
    local current = math.min(goods_startpos + choosing_a, #goods)
    text_pointer:SetText(current .. " / " .. #goods)
end

local function itemText(item)
    local text = "* " .. item.name
    return text
end

local function createElements(state)
    if (state == "IDLE") then
    elseif (state == "BUY") then
        text_pointer.alpha = 1
        updateTextPointer()
        for i = 1, #buttons
        do
            buttons[i].alpha = 0
        end
        for i = 1, goods_per_page
        do
            local t = goods_buttons[i]
            local index = i + goods_startpos
            if (index <= #goods) then
                t:SetText(itemText(goods[index]))
                t.alpha = 1
            else
                t:SetText("")
                t.alpha = 0
            end
        end
    end
end

local function hideElements()
    for i = 1, #buttons
    do
        buttons[i].alpha = 0
    end
    line.alpha = 0
    shop.player.alpha = 0
    t_gold.alpha = 0
    t_inv.alpha = 0
    text_pointer.alpha = 0
end

local function updateButtons(data, startPos)
    for i = 1, goods_per_page do
        local t = goods_buttons[i]
        local index = i + startPos
        if (index <= #data) then
            t:SetText(itemText(data[index]))
            t.alpha = 1
        else
            t:SetText("")
            t.alpha = 0
        end
    end
end

local function downScroll(data, pos)
    updateButtons(data, pos)
end

local function upScroll(data, pos)
    updateButtons(data, pos)
end

function shop.GetPlayer()
    return shop.player
end

function shop.GetBackground()
    return shop.background
end

function shop.SetMainText(text)
    shop.main:SetText(text)
end

local function findItem(id)
    local db = ITEMS
    if (db) then
        return db.FindItemByID(id)
    end
end

function shop.SetGoods(g)
    goods = {}

    for i = 1, #g
    do
        local item = findItem(g[i])
        if (item) then
            goods[#goods + 1] = {id = item.id, name = item.name}
        end
    end
end

function shop.AddGoods(g)
    local item = findItem(g)
    if (item) then
        goods[#goods + 1] = {id = item.id, name = item.name}
    end
end

function shop.RemoveGoods(index)
    table.remove(goods, index)
end

function shop.SetPrice(id, price)
    prices[id] = price
end

function shop.GetPrice(id)
    return prices[id]
end

function shop.Update(dt)
    if (Controller.GetState("confirm") == 1) then
        shop.SetMainText("")
        if (choosing_page == "IDLE") then
            if (choosing_b <= 3) then
                choosing_page = states[choosing_b]
                if (choosing_page == "BUY") then
                    choosing_a = 1
                    goods_startpos = 0
                    createElements("BUY")
                end
            else
                choosing_page = "EXITING"
                hideElements()
                shop.SetMainText(shop.textend)
                shop.main.mode = "manual"
                shop.main._onComplete = function ()
                    shop._leaving = true
                end
            end
        end
    end

    if (choosing_page == "IDLE") then
        if (Controller.GetState("down") == 1) then
            Audio.PlaySound("snd_menu_0.wav")
            choosing_b = math.min(choosing_b + 1, 4)
        elseif (Controller.GetState("up") == 1) then
            Audio.PlaySound("snd_menu_0.wav")
            choosing_b = math.max(choosing_b - 1, 1)
        end
        shop.player:MoveTo(465, 278 + (choosing_b - 1) * 40)
    elseif (choosing_page == "BUY") then
        if (Controller.GetState("down") == 1) then
            Audio.PlaySound("snd_menu_0.wav")
            if (choosing_a < goods_per_page and goods_startpos + choosing_a < #goods) then
                choosing_a = choosing_a + 1
            elseif (choosing_a == goods_per_page and goods_startpos + goods_per_page < #goods) then
                goods_startpos = goods_startpos + 1
                downScroll(goods, goods_startpos)
            end
            updateTextPointer()
        elseif (Controller.GetState("up") == 1) then
            Audio.PlaySound("snd_menu_0.wav")
            if (choosing_a > 1) then
                choosing_a = choosing_a - 1
            elseif (goods_startpos > 0) then
                goods_startpos = goods_startpos - 1
                choosing_a = 1
                upScroll(goods, goods_startpos)
            end
            updateTextPointer()
        end
        shop.player:MoveTo(55, 278 + (choosing_a - 1) * 40)
    end
end

function shop.Clear()
    -- Unload the shop module so reopening a shop re-executes it fresh,
    -- avoiding stale state / duplicated sprites from a previous visit.
    ClearModuleTree("Scripts.Libraries.Overworld.shop")
end

return shop