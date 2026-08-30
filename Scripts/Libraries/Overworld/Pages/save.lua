local page = {
    _active = false,
}
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

local function returnTimeString(all_second)
    local total_seconds = math.floor(all_second or 0)
    local m = math.floor(total_seconds / 60)
    local s = total_seconds % 60

    return string.format("%02d:%02d", m, s)
end

local _x, _y = GetRelativePos(320, 200)
local block = SpawnBlock(_x, _y, 412, 162, 5)
block:Hide()
local heart = Sprites.CreateSprite("Soul Library Sprites/spr_default_heart.png", "GUI")
heart.layer = heart.layer + 1
heart.alpha = 0
heart.color = {1, 0, 0}

local choosing = 1
local just_on_dialog = false
local saved = false

function page.Show()
    choosing = 1
    saved = false
    just_on_dialog = true
    Char.controlling = false
    page._active = true
    local _x, _y = GetRelativePos(320, 200)
    block:UpdatePos(_x, _y)
    block:Show()

    local _data = Global.GetSaveVariable("Overworld")
    if (not _data) then
        _data = {
            time = 0,
            room_name = "--",
            room = "Overworld",
            marker = 2,
            position = {0, 0},
            direction = "down",
            savedpos = false,

            player = {
                name = "Chara",
                lv = 1,
                maxhp = 20,
                hp = 20,

                gold = 0,
                exp = 0,

                atk = 0,
                watk = 0,
                def = 0,
                edef = 0,
                weapon = "stick",
                armor = "bandage",

                items = {},
                getcell = false,
                cells = {
                    "Toriel"
                }
            },
        }
    end

    local _x, _y = GetRelativePos(140, 135)
    local t = Typers.InstText.New(_data.player.name .. "    LV " .. _data.player.lv, {_x, _y}, "GUI")
    table.insert(elements, t)
    local _x, _y = GetRelativePos(500, 135)
    local t = Typers.InstText.New(returnTimeString(_data.time), {_x, _y}, "GUI")
    t:SetAlign("right")
    table.insert(elements, t)

    local _x, _y = GetRelativePos(140, 185)
    local t = Typers.InstText.New(_data.room_name, {_x, _y}, "GUI")
    table.insert(elements, t)
    local _x, _y = GetRelativePos(195, 235)
    local t = Typers.InstText.New(Localize.localizeText("Overworld.Save.Buttons"), {_x, _y}, "GUI")
    table.insert(elements, t)

    heart.alpha = 1
end

function page.Hide()
    page._active = false
    block:Hide()
    block.white.color = {1, 1, 1}
    heart.alpha = 0
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
        choosing = 1
    elseif (Controller.GetState("right") == 1) then
        choosing = 2
    end

    local _x, _y = GetRelativePos(180 + (choosing - 1) * 170, 252)
    heart:MoveTo(_x, _y)

    if (saved and Controller.GetState("confirm") == 1) then
        page.Hide()
    end

    if (not just_on_dialog and not saved) then
        if (Controller.GetState("confirm") == 1) then
            if (choosing == 1) then
                for i = #elements, 1, -1
                do
                    local e = elements[i]
                    e.color = {1, 1, 0}
                end
                block.white.color = {1, 1, 0}
                Audio.PlaySound("snd_save.wav")
                heart.alpha = 0
                saved = true
                elements[#elements]:SetText(Localize.localizeText("Overworld.Save.Success"))
                elements[1]:SetText(DATA.player.name .. "    LV " .. DATA.player.lv)
                elements[2]:SetText(returnTimeString(DATA.time))
                elements[3]:SetText(DATA.room_name)
                Global.SetSaveVariable("Overworld", DATA)
            else
                page.Hide()
            end
        end

        if (Controller.GetState("cancel") == 1) then
            page.Hide()
        end
    end

    if (just_on_dialog) then just_on_dialog = false end
end

return page