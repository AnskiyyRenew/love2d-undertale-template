-- It's not stat actually...
local stat = {
    _created = false,
    _page = "idle"
}

local function clamp(v, max, min)
    return (math.max(math.min(max, v), min))
end

local function get_relative_pos(x, y)
    local rx = clamp(Camera.x, (Camera.max_x or math.huge), (Camera.min_x or -math.huge))
    local ry = clamp(Camera.y, (Camera.max_y or math.huge), (Camera.min_y or -math.huge))
    return rx - 320 + x, ry - 240 + y
end

local function spawn_block(x, y, width, height, thickness)
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

    block.Destroy = function ()
        white:Destroy()
        black:Destroy()
        block = nil
    end

    return block
end

local heart = Sprites.CreateSprite("Soul Library Sprites/spr_default_heart.png", "GUI")
heart.layer = heart.layer + 1
heart.alpha = 0
heart.color = {1, 0, 0}

function stat.Update(dt)
    if (Char.controlling) then
        if (Controller.GetState("menu") == 1 and not stat._created) then
            stat._created = true
            Char.controlling = false
            Char.mainstate = "i-idle"
            heart.alpha = 1
            local _x, _y = get_relative_pos(65, 205)
            heart:MoveTo(_x, _y)

            local _x, _y = get_relative_pos(100, 240)
            spawn_block(_x, _y, 132, 138, 5)

            local _x, _y = get_relative_pos(100, 106)
            spawn_block(_x, _y, 132, 100, 5)

            local _x, _y = get_relative_pos(43, 60)
            local t = Typers.InstText.New(DATA.player.name, {_x, _y}, "GUI")

            local _x, _y = get_relative_pos(45, 102)
            local t = Typers.InstText.New("LV " .. DATA.player.lv, {_x, _y}, "GUI")
            t.font = "Crypt Of Tomorrow.ttf"
            t.fontsize = 16

            local _x, _y = get_relative_pos(45, 120)
            local t = Typers.InstText.New("HP " .. DATA.player.hp .. "/" .. DATA.player.maxhp, {_x, _y}, "GUI")
            t.font = "Crypt Of Tomorrow.ttf"
            t.fontsize = 16

            local _x, _y = get_relative_pos(45, 137)
            local t = Typers.InstText.New("G  " .. DATA.player.gold, {_x, _y}, "GUI")
            t.font = "Crypt Of Tomorrow.ttf"
            t.fontsize = 16

            -- Three menus.
            local _x, _y = get_relative_pos(80, 190 - 3)
            local t = Typers.InstText.New("ITEM", {_x, _y}, "GUI")

            local _x, _y = get_relative_pos(80, 190 + 35 - 3)
            local t = Typers.InstText.New("STAT", {_x, _y}, "GUI")

            local _x, _y = get_relative_pos(80, 190 + 70 - 3)
            local t = Typers.InstText.New("CELL", {_x, _y}, "GUI")
        end
    end
end


return stat