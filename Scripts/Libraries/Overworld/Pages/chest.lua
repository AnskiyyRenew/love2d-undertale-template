local page = {_active = false}
local elements = {}

local function clamp(v, max, min)
    return (math.max(math.min(max, v), min))
end

local function GetRelativePos(x, y)
    local rx = clamp(Camera.x, (Camera.max_x or math.huge), (Camera.min_x or -math.huge))
    local ry = clamp(Camera.y, (Camera.max_y or math.huge), (Camera.min_y or -math.huge))
    return rx - 320 + x, ry - 240 + y
end

local function SpawnBlock(x, y, width, height, thickness)
    local block = {
        x = x,
        y = y,
        w = width,
        h = height,
        t = thickness,
    }

    local white = Sprites.CreateSprite("px.png", "GUI")
    white:Scale(block.w + thickness * 2, block.h + thickness * 2)
    white:MoveTo(block.x, block.y)
    local black = Sprites.CreateSprite("px.png", "GUI")
    black.color = {0, 0, 0}
    black:Scale(block.w, block.h)
    black:MoveTo(block.x, block.y)

    block.Destroy = function (self)
        white:Destroy()
        black:Destroy()
        block = nil
    end

    block.Hide = function (self)
        white.alpha = 0
        black.alpha = 0
    end

    block.Show = function (self)
        white.alpha = 1
        black.alpha = 1
    end

    block.UpdatePos = function (self, _x, _y)
        white:MoveTo(_x, _y)
        black:MoveTo(_x, _y)
    end

    block.white = white
    block.black = black

    return block
end

local _x, _y = GetRelativePos(320, 240)
local block = SpawnBlock(_x, _y, 600, 440, 5)
block:Hide()
local line = Sprites.CreateSprite("px.png", "GUI")
line:Scale(2, 300)
line:MoveTo(_x, _y)
line.color = {0.5, 0, 0}
line.alpha = 0
local heart = Sprites.CreateSprite("Soul Library Sprites/spr_default_heart.png", "GUI")
heart.layer = heart.layer + 1
heart.alpha = 0
heart.color = {1, 0, 0}

local left_max = 0
local right_max = 0
local current_chest = "chest"

local in_section = 1
local in_channel = 1
local total_sect = 1

function page.Show(chest)
    in_section = 1
    in_channel = 1
    total_sect = 1
    left_max = 0
    right_max = 0
    current_chest = chest
    Char.controlling = false
    page._active = true

    local _x, _y = GetRelativePos(50, 97)
    heart.alpha = 1
    heart:MoveTo(_x, _y)
    local _x, _y = GetRelativePos(320, 240)
    line:MoveTo(_x, _y)
    line.alpha = 1
    block:UpdatePos(_x, _y)
    block:Show()

    local _x, _y = GetRelativePos(100, 30)
    local title = Typers.InstText.New(Localize.localizeText("Overworld.Chest.Title"), {_x, _y}, "GUI")
    table.insert(elements, title)
    local _x, _y = GetRelativePos(320, 405)
    local tip = Typers.InstText.New(Localize.localizeText("Overworld.Chest.Tip"), {_x, _y}, "GUI")
    tip:SetAlign("center")
    table.insert(elements, tip)

    -- inventory typers
    for i = 1, 8
    do
        local _item = DATA.player.items[i]
        local _x, _y = GetRelativePos(70, 80 + (i - 1) * 30)
        local t = Typers.InstText.New((_item and ITEMS.FindItemByID(_item).name or ""), {_x, _y}, "GUI")
        table.insert(elements, t)

        if (_item) then
            if (ITEMS.FindItemByID(_item)._color) then
                t.color = ITEMS.FindItemByID(_item)._color
            end
            left_max = left_max + 1
        end
    end
    for i = 1, 10
    do
        local _item = CHEST[chest][i]
        local _x, _y = GetRelativePos(370, 80 + (i - 1) * 30)
        local t = Typers.InstText.New((_item and ITEMS.FindItemByID(_item).name or ""), {_x, _y}, "GUI")
        table.insert(elements, t)

        if (_item) then
            if (ITEMS.FindItemByID(_item)._color) then
                t.color = ITEMS.FindItemByID(_item)._color
            end
            right_max = right_max + 1
        end
    end
end

local function refreshItems()
    for i = 1, 18 do
        local item
        if (i <= 8) then
            item = DATA.player.items[i]
        else
            item = CHEST[current_chest][i - 8]
        end

        local t = elements[i + 2]
        t:SetText((item and ITEMS.FindItemByID(item).name or ""))
        t.color = (item and ITEMS.FindItemByID(item)._color) or {1, 1, 1}
    end
end

function page.Hide()
    page._active = false
    block:Hide()
    block.white.color = {1, 1, 1}
    heart.alpha = 0
    line.alpha = 0
    Overworld.JustOnDialog()
    Char.controlling = true

    for i = #elements, 1, -1
    do
        local e = elements[i]
        e:Destroy()
        table.remove(elements, i)
    end
end

function page.Update()
    if (not page._active) then return end

    if (Controller.GetState("left") == 1) then
        in_section = 1
        total_sect = left_max
        local _x = GetRelativePos(50, 0)
        heart.x = _x
    elseif (Controller.GetState("right") == 1) then
        in_section = 2
        total_sect = right_max
        local _x = GetRelativePos(350, 0)
        heart.x = _x
    end

    if (Controller.GetState("up") == 1) then
        in_channel = math.max(1, in_channel - 1)
        local _, _y = GetRelativePos(0, 97 + (in_channel - 1) * 30)
        heart.y = _y
    elseif (Controller.GetState("down") == 1) then
        in_channel = math.min(total_sect, in_channel + 1)
        local _, _y = GetRelativePos(0, 97 + (in_channel - 1) * 30)
        heart.y = _y
    end

    if (Controller.GetState("confirm") == 1) then
        -- Swapper
        if (in_section == 1) then
            if (right_max >= 10) then return end
            table.insert(CHEST[current_chest], DATA.player.items[in_channel])
            table.remove(DATA.player.items, in_channel)
            left_max = left_max - 1
            right_max = right_max + 1

            refreshItems()
        else
            if (left_max >= 8 or right_max <= 0) then return end
            left_max = left_max + 1
            right_max = right_max - 1
            table.insert(DATA.player.items, CHEST[current_chest][in_channel])
            table.remove(CHEST[current_chest], in_channel)

            refreshItems()
        end
    end

    if (Controller.GetState("cancel") == 1) then
        page.Hide()
    end
end

return page