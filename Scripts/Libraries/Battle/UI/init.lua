local path = (...):match("(.-)[^%.]+$")
local buttons = require(path .. "UI.buttons")
local state = require(path .. "UI.stateinner")

local ui = {
    buttons = buttons,
    button_selecting = buttons.button_selecting,
    state = state,

    _bouncetexts = {},
    _notbtexts = {}
}

local setup_hpbar = {
    use_stencil = false
}
local kr_configuration = true

local bar_maxhp = Sprites.CreateSprite("px.png", "UI")
bar_maxhp:MoveTo(245 + 30, 410)
bar_maxhp.xpivot = 0
bar_maxhp.yscale = 20
bar_maxhp.color = {1, 0, 0}
bar_maxhp:OutLine(0, 0, 0, 1, 2)
local bar_hp = Sprites.CreateSprite("px.png", "UI")
bar_hp.color = {1, 1, 0}
bar_hp:MoveTo(245 + 30, 410)
bar_hp.xpivot = 0
bar_hp.yscale = 20
local bar_kr = Sprites.CreateSprite("px.png", "UI")
bar_kr.color = {1, 0, 1}
bar_kr:MoveTo(245 + 30, 410)
bar_kr.xpivot = 0
bar_kr.xscale = 0
bar_kr.yscale = 20

local ui_font = SE.graphics.newFont("Resources/Fonts/Mars Needs Cunnilingus.ttf", 24, "mono")
local lit_font = SE.graphics.newFont("Resources/Fonts/8bit-wonder.TTF", 12, "mono")
ui_font:setFilter("nearest", "nearest")
lit_font:setFilter("nearest", "nearest")

local function drawOutlinedText(font, color, text, x, y, thickness)
    local th = thickness or 1
    SE.graphics.setFont(font)
    SE.graphics.setColor(0, 0, 0)
    SE.graphics.print(text, x - th, y)
    SE.graphics.print(text, x + th, y)
    SE.graphics.print(text, x, y - th)
    SE.graphics.print(text, x, y + th)
    SE.graphics.setColor(color)
    SE.graphics.print(text, x, y)
end
ui.drawOutlinedText = drawOutlinedText

local pos_ = {
    hpname = 245
}

-- UI Texts
local name = Layers.add_external(function ()
    drawOutlinedText(ui_font, Global.GetVariable("MainColor"), Player.name, 30, 400, 2)
end, "UI")
local lv = Layers.add_external(function ()
    drawOutlinedText(ui_font, Global.GetVariable("MainColor"), "LV " .. Player.lv, 30 + 15 * (Player.name:len() + 2), 400, 2)
end, "UI")
local hpname = Layers.add_external(function ()
    pos_.hpname = 30 + 15 * (Player.name:len() + 2) + 15 * (("LV " .. Player.lv):len()) + 20
    drawOutlinedText(lit_font, Global.GetVariable("MainColor"), "HP", math.max(pos_.hpname, 245), 403, 2)
end, "UI")
local krname = Layers.add_external(function ()
    if (kr_configuration) then
        drawOutlinedText(lit_font, Global.GetVariable("MainColor"), "KR", bar_maxhp.x + bar_maxhp.xscale + 8, 403, 2)
    end
end)
local hptext = Layers.add_external(function ()
    if (not kr_configuration) then
        drawOutlinedText(ui_font, Global.GetVariable("MainColor"), Player.hp .. " / " .. Player.maxhp, bar_maxhp.x + bar_maxhp.xscale + 10, 400, 2)
    else
        drawOutlinedText(ui_font, Global.GetVariable("MainColor"), Player.hp .. " / " .. Player.maxhp, bar_maxhp.x + bar_maxhp.xscale + 45, 400, 2)
    end
end, "UI")

local bar_maxlength = 100 * 1.21
function ui.setBarMaxLength(length)
    if (not length or type(length) ~= "number") then
        return
    end
    bar_maxlength = length
end

function ui.newBounceText(text, pos)
    pos[2] = pos[2] - 60
    local t = Typers.InstText.New(text, pos, "TopAll")
    t.bondfont = {
        engfont = {font = "DAMAGEBACK.ttf", size = 32},
        non_engfont = {font = "simsun.ttc", size = 13},
        engfunc = function()
            t.scale = 1
        end,
        non_engfunc = function()
            t.scale = 2
        end
    }
    t.color = {0, 0, 0}
    t:SetAlign("center")
    t:Rebuild()
    t._speed = -3
    t._gravity = 0.3
    t._time = 0
    table.insert(ui._bouncetexts, t)

    local t = Typers.InstText.New(text, pos, "TopAll")
    t.bondfont = {
        engfont = {font = "Hachicro.ttf", size = 32},
        non_engfont = {font = "simsun.ttc", size = 13},
        engfunc = function()
            t.scale = 1
        end,
        non_engfunc = function()
            t.scale = 2
        end
    }
    t.color = {1, 0, 0}
    t:SetAlign("center")
    t:Rebuild()
    t._speed = -3
    t._gravity = 0.3
    t._time = 0
    table.insert(ui._bouncetexts, t)
end

function ui.newMonsterBar(pos, start, target)
    local _maxhp = Sprites.CreateSprite("px.png", "TopAll")
    _maxhp.xpivot = 0
    _maxhp:Scale(100, 15)
    _maxhp:MoveTo(pos[1] - 50, pos[2] + 40)
    _maxhp.color = {1, 0, 0}
    _maxhp._time = -30
    table.insert(ui._notbtexts, _maxhp)

    local _hp = Sprites.CreateSprite("px.png", "TopAll")
    _hp.xpivot = 0
    _hp:Scale(100, 15)
    _hp.xscale = start
    _hp:MoveTo(pos[1] - 50, pos[2] + 40)
    _hp.color = {0, 1, 0}
    _hp._time = -30
    Tween.CreateTween(function (v)
        _hp.xscale = v
    end, "Linear", "", _hp.xscale, math.max(0, target), 30)
    table.insert(ui._notbtexts, _hp)
end

function ui.newMissText(text, pos)
    pos[2] = pos[2] - 60
    local t = Typers.InstText.New(text, pos, "TopAll")
    t.bondfont = {
        engfont = {font = "DAMAGEBACK.ttf", size = 32},
        non_engfont = {font = "simsun.ttc", size = 13},
        engfunc = function()
            t.scale = 1
        end,
        non_engfunc = function()
            t.scale = 2
        end
    }
    t.color = {0, 0, 0}
    t:SetAlign("center")
    t:Rebuild()
    t._speed = -3
    t._gravity = 0.3
    t._time = 0
    table.insert(ui._notbtexts, t)

    local t = Typers.InstText.New(text, pos, "TopAll")
    t.bondfont = {
        engfont = {font = "Hachicro.ttf", size = 32},
        non_engfont = {font = "simsun.ttc", size = 13},
        engfunc = function()
            t.scale = 1
        end,
        non_engfunc = function()
            t.scale = 2
        end
    }
    t:SetAlign("center")
    t:Rebuild()
    t._speed = -3
    t._gravity = 0.3
    t._time = 0
    table.insert(ui._notbtexts, t)
end

function ui.Update(dt)
    buttons.Update()
    ui.button_selecting = buttons.button_selecting
    state.Update()

    bar_maxhp.xscale = math.min(bar_maxlength, Player.maxhp * 1.21)
    bar_hp.xscale = Player.hp / Player.maxhp * bar_maxhp.xscale
    bar_kr.x = bar_hp.x + bar_hp.xscale

    for i = #ui._bouncetexts, 1, -1
    do
        local t = ui._bouncetexts[i]
        if (t._speed <= 3) then
            t._speed = t._speed + t._gravity
            t.y = t.y + t._speed
        else
            t._time = t._time + 1
            if (t._time >= 38) then
                t:Destroy()
            end
        end
    end

    for i = #ui._notbtexts, 1, -1
    do
        local t = ui._notbtexts[i]
        t._time = t._time + 1
        if (t._time >= 30) then
            t:Destroy()
        end
    end
end

return ui