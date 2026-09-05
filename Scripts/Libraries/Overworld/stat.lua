-- It's not stat actually...
local stat = {
    _created = false,
    _page = "idle",
    _menus = 2
}
DATA.player.getcell = true
-- Camera-relative positioning is delegated to the single shared GetRelativePos
-- defined in init.lua, so the stat menu and the overworld dialogs always read
-- the camera through the same code path (no duplicated math that could drift
-- out of sync by a frame).
local function get_relative_pos(x, y)
    return GetRelativePos(x, y)
end

local function get_rx(x)
    local rx = GetRelativePos(x, 0)
    return rx
end

local function get_ry(y)
    local _, ry = GetRelativePos(0, y)
    return ry
end

local elements = {}
local temp_elements = {}
local function spawn_block(x, y, width, height, thickness, targettable)
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

    if (not targettable) then
        table.insert(elements, block)
    else
        table.insert(targettable, block)
    end
    return block
end

local heart = Sprites.CreateSprite("Soul Library Sprites/spr_default_heart.png", "GUI")
heart.layer = heart.layer + 1
heart.alpha = 0
heart.color = {1, 0, 0}

-- Vars
local in_menu = 1
local in_item = 1
local in_item_menu = 1

function stat.Update(dt)
    if (Char.controlling) then
        if (Controller.GetState("menu") == 1 and not stat._created) then
            stat._created = true
            Char.controlling = false
            -- Stop the player instantly. stat.Update runs BEFORE the physics
            -- step inside map.Update, so zeroing the velocity here prevents the
            -- body (and thus the camera) from sliding forward one frame while
            -- the menu is being positioned. This removes the one-frame gap
            -- between the camera the menu is anchored to and the camera that is
            -- actually used to draw this frame.
            if (Char.collision.body) then
                Char.collision.body:setLinearVelocity(0, 0)
            end
            heart.alpha = 1
            in_menu = 1

            if (DATA.player.getcell) then
                stat._menus = 3
            end

            local _x, _y = get_relative_pos(65, 205)
            heart:MoveTo(_x, _y)

            local _x, _y = get_relative_pos(100, 240)
            spawn_block(_x, _y, 132, 138, 5)

            local _x, _y = get_relative_pos(100, 106)
            spawn_block(_x, _y, 132, 100, 5)

            local _x, _y = get_relative_pos(43, 60)
            local t = Typers.InstText.New(DATA.player.name, {_x, _y}, "GUI")
            table.insert(elements, t)

            local _x, _y = get_relative_pos(45, 102)
            local t = Typers.InstText.New("LV " .. DATA.player.lv, {_x, _y}, "GUI")
            t.font = "Crypt Of Tomorrow.ttf"
            t.fontsize = 16
            table.insert(elements, t)

            local _x, _y = get_relative_pos(45, 120)
            local t = Typers.InstText.New("HP " .. DATA.player.hp .. "/" .. DATA.player.maxhp, {_x, _y}, "GUI")
            t.font = "Crypt Of Tomorrow.ttf"
            t.fontsize = 16
            table.insert(elements, t)

            local _x, _y = get_relative_pos(45, 137)
            local t = Typers.InstText.New("G  " .. DATA.player.gold, {_x, _y}, "GUI")
            t.font = "Crypt Of Tomorrow.ttf"
            t.fontsize = 16
            table.insert(elements, t)

            -- Three menus.
            local _buttons = Localize.localizeText("Overworld.Menu.Buttons")
            local _x, _y = get_relative_pos(80, 190 - 3)
            local t = Typers.InstText.New(_buttons[1], {_x, _y}, "GUI")
            if (#DATA.player.items == 0) then
                t.alpha = 0.5
            end
            table.insert(elements, t)

            local _x, _y = get_relative_pos(80, 190 + 35 - 3)
            local t = Typers.InstText.New(_buttons[2], {_x, _y}, "GUI")
            table.insert(elements, t)

            if (DATA.player.getcell) then
                local _x, _y = get_relative_pos(80, 190 + 70 - 3)
                local t = Typers.InstText.New(_buttons[3], {_x, _y}, "GUI")
                table.insert(elements, t)
            end
        end
    end

    if (stat._created) then
        if (Controller.GetState("confirm") == 1) then
            if (stat._page == "idle") then
                if (in_menu == 1) then
                    in_item = 1
                    in_item_menu = 1
                    stat._page = "item"

                    local _x, _y = get_relative_pos(360, 230)
                    spawn_block(_x, _y, 335, 350, 5, temp_elements)

                    local _x, _y = get_relative_pos(215, 87)
                    heart:MoveTo(_x, _y)

                    for i = 1, 8
                    do
                        local _x, _y = get_relative_pos(230, 70 + (i - 1) * 32)
                        local _item = DATA.player.items[i]
                        local t = Typers.InstText.New((_item and ITEMS.FindItemByID(DATA.player.items[i]).name or ""), {_x, _y}, "GUI")
                        table.insert(temp_elements, t)
                        if (_item) then
                            local _it = ITEMS.FindItemByID(_item)
                            if (_it._color) then
                                t.color = _it._color
                            end
                        end
                    end

                    local _x, _y = get_relative_pos(230, 360)
                    local t = Typers.InstText.New(Localize.localizeText("Overworld.Menu.Item"), {_x, _y}, "GUI")
                    table.insert(temp_elements, t)
                elseif (in_menu == 2) then
                    stat._page = "stat"
                    heart.alpha = 0

                    local _x, _y = get_relative_pos(365, 260)
                    spawn_block(_x, _y, 345, 410, 5, temp_elements)

                    local _x, _y = get_relative_pos(215, 80)
                    local _str = Localize.localizeText("Overworld.Menu.Stat", {
                        DATA.player.name, DATA.player.lv,
                        DATA.player.hp, DATA.player.maxhp,

                        DATA.player.atk, DATA.player.watk,
                        DATA.player.def, DATA.player.edef,
                        DATA.player.weapon, DATA.player.armor,
                        DATA.player.gold
                    })
                    local t = Typers.InstText.New(_str, {_x, _y}, "GUI")
                    table.insert(temp_elements, t)

                    local _x, _y = get_relative_pos(370, 240)
                    local nextexp = Overworld.CalcNextEXP()
                    local _expstr = string.format(
                        "EXP: %s\nNEXT:%s",

                        DATA.player.exp, nextexp
                    )
                    local t = Typers.InstText.New(_expstr, {_x, _y}, "GUI")
                    table.insert(temp_elements, t)

                elseif (in_menu == 3) then
                    stat._page = "cell"

                    local _x, _y = get_relative_pos(360, 230)
                    spawn_block(_x, _y, 345, 350, 5, temp_elements)

                    local _x, _y = get_relative_pos(215, 87)
                    heart:MoveTo(_x, _y)

                    for i = 1, 10
                    do
                        local _x, _y = get_relative_pos(230, 70 + (i - 1) * 32)
                        local _item = DATA.player.cells[i]
                        local t = Typers.InstText.New((_item and _item.name or "-"), {_x, _y}, "GUI")
                        table.insert(temp_elements, t)
                        if (_item) then
                            if (_item._color) then
                                t.color = _item._color
                            end
                        end
                    end
                end
            elseif (stat._page == "item") then
                stat._page = "item2"
            end
        elseif (Controller.GetState("cancel") == 1) then
            if (stat._page == "idle") then
                stat.Destroy()
            elseif (stat._page == "item") then
                stat._page = "idle"
                for i = #temp_elements, 1, -1
                do
                    local e = temp_elements[i]
                    if (e.Destroy) then
                        e:Destroy()
                    end
                end
            elseif (stat._page == "stat") then
                stat._page = "idle"
                heart.alpha = 1
                for i = #temp_elements, 1, -1
                do
                    local e = temp_elements[i]
                    if (e.Destroy) then
                        e:Destroy()
                    end
                end
            elseif (stat._page == "cell") then
                stat._page = "idle"
                heart.alpha = 1
                for i = #temp_elements, 1, -1
                do
                    local e = temp_elements[i]
                    if (e.Destroy) then
                        e:Destroy()
                    end
                end
            elseif (stat._page == "item2") then
                stat._page = "item"
            end
        end
        if (stat._page == "idle") then
            if (Controller.GetState("down") == 1) then
                in_menu = math.min(stat._menus, in_menu + 1)
            elseif (Controller.GetState("up") == 1) then
                in_menu = math.max(1, in_menu - 1)
            end
            heart.x = get_rx(65)
            heart.y = get_ry(205 + (in_menu - 1) * 35)
        elseif (stat._page == "item") then
            if (Controller.GetState("down") == 1) then
                in_item = math.min(math.max(1, #DATA.player.items), in_item + 1)
            elseif (Controller.GetState("up") == 1) then
                in_item = math.max(1, in_item - 1)
            end
            local _x, _y = get_relative_pos(215, 87 + (in_item - 1) * 32)
            heart:MoveTo(_x, _y)
        elseif (stat._page == "item2") then
            if (Controller.GetState("right") == 1) then
                in_item_menu = math.min(3, in_item_menu + 1)
            elseif (Controller.GetState("left") == 1) then
                in_item_menu = math.max(1, in_item_menu - 1)
            end

            local _i18nx = tonumber(Localize.localizeText("Overworld.Menu.Interval")[in_item_menu])
            local _x, _y = get_relative_pos(_i18nx, 378)
            heart:MoveTo(_x, _y)

            if (Controller.GetState("confirm") == 1) then
                stat.Destroy()
                Char.controlling = false
                Overworld.dialogNew(ITEMS.GetActionByID())
            end
        end
    end
end

function stat.Destroy()
    stat._created = false
    Char.controlling = true
    heart.alpha = 0

    for i = #elements, 1, -1
    do
        local e = elements[i]
        if (e.Destroy) then
            e:Destroy()
        end
    end
end


return stat