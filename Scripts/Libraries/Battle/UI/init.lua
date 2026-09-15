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
local time_kr = 0

-- ---------------------------------------------------------------------------
-- Layout
-- ---------------------------------------------------------------------------
-- The status line is laid out from ONE configurable origin (`text_pos`): the
-- name sits at (text_pos[1], text_pos[2]) and LV / "HP" are offset from it,
-- while the "KR" label and the HP numbers follow the right end of the HP bar.
-- Every element mirrors its live coordinates into the `pos_*` tables below, so
-- other code can ask "where is the HP label right now?" (ui.GetLayout()).
-- The public API at the bottom of this file drives all of it:
--     ui.SetTextPosition / ui.GetTextPosition / ui.MoveTextPosition
--     ui.SetBarPosition  / ui.GetBarPosition  / ui.MoveBarPosition
local text_pos = {30, 400}
-- Left edge (x) and height (y) shared by the three HP bars.
local bar_pos = {245 + 30, 410}
-- The "HP" label follows the name / LV text but never moves further left than
-- this, so it can not collide with the numbers when the name gets short.
local hpname_limit = 245

local bar_maxhp = Sprites.CreateSprite("px.png", "UI")
bar_maxhp:MoveTo(bar_pos[1], bar_pos[2])
bar_maxhp.xpivot = 0
bar_maxhp.yscale = 20
bar_maxhp.color = {1, 0, 0}
bar_maxhp:Outline(0, 0, 0, 1, 2)
local bar_hp = Sprites.CreateSprite("px.png", "UI")
bar_hp.color = {1, 1, 0}
bar_hp:MoveTo(bar_pos[1], bar_pos[2])
bar_hp.xpivot = 0
bar_hp.yscale = 20
local bar_kr = Sprites.CreateSprite("px.png", "UI")
bar_kr.color = {1, 0, 1}
bar_kr:MoveTo(bar_pos[1], bar_pos[2])
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
local kr_color = {1, 0, 1}

-- UI Texts
-- `pos_*` hold the LIVE position of each element (updated on every draw pass),
-- while `text_pos` holds the origin they are derived from. 15 px is one
-- character of `ui_font` (a 24 px monospace font).
local pos_name = {30, 400}
local pos_lv = {30, 400}
local pos_hpname = {30, 400}
local pos_krname = {30, 400}
local pos_hptext = {30, 400}
local name = Layers.add_external(function ()
    pos_name[1], pos_name[2] = text_pos[1], text_pos[2]
    drawOutlinedText(ui_font, Global.GetVariable("MainColor"), Player.name, pos_name[1], pos_name[2], 2)
end, "UI")
local lv = Layers.add_external(function ()
    -- Offset by the width of the name (plus the two spaces that follow it).
    pos_lv[1] = text_pos[1] + 15 * (Player.name:len() + 2)
    pos_lv[2] = text_pos[2]
    drawOutlinedText(ui_font, Global.GetVariable("MainColor"), "LV  " .. Player.lv, pos_lv[1], pos_lv[2], 2)
end, "UI")
local hpname = Layers.add_external(function ()
    -- Sits right after the LV text, but never closer than `hpname_limit`.
    pos_hpname[1] = math.max(
        text_pos[1] + 15 * (Player.name:len() + 2) + 15 * (("LV  " .. Player.lv):len()) + 20,
        hpname_limit
    )
    pos_hpname[2] = text_pos[2] + 3
    pos_.hpname = pos_hpname[1] -- kept for callers of the old variable
    drawOutlinedText(lit_font, Global.GetVariable("MainColor"), "HP", pos_hpname[1], pos_hpname[2], 2)
end, "UI")
local krname = Layers.add_external(function ()
    if (kr_configuration) then
        pos_krname[1] = bar_maxhp.x + bar_maxhp.xscale + 8
        pos_krname[2] = text_pos[2] + 3
        drawOutlinedText(lit_font, Global.GetVariable("MainColor"), "KR", pos_krname[1], pos_krname[2], 2)
    end
end)
local hptext = Layers.add_external(function ()
    -- The numbers follow the right end of the HP bar; the KR variant leaves a
    -- wider gap because the KR value is appended to them.
    if (not kr_configuration) then
        pos_hptext[1] = bar_maxhp.x + bar_maxhp.xscale + 10
        pos_hptext[2] = text_pos[2]
        drawOutlinedText(ui_font, Global.GetVariable("MainColor"), Player.hp .. " / " .. Player.maxhp, pos_hptext[1], pos_hptext[2], 2)
    else
        pos_hptext[1] = bar_maxhp.x + bar_maxhp.xscale + 45
        pos_hptext[2] = text_pos[2]
        local color_ = Global.GetVariable("MainColor")
        if (Player.kr > 0) then
            color_ = kr_color
        end
        drawOutlinedText(ui_font, color_, Player.hp + Player.kr .. " / " .. Player.maxhp, pos_hptext[1], pos_hptext[2], 2)
    end
end, "UI")

local bar_maxlength = 100 * 1.21
function ui.SetBarMaxLength(length)
    if (not length or type(length) ~= "number") then
        return
    end
    bar_maxlength = length
end

function ui.SetHPBarColor(color)
    bar_hp.color = color
end

function ui.ToggleKR(bool)
    kr_configuration = (bool or not kr_configuration)
end

function ui.GetKRStarted()
    return kr_configuration
end

function ui.newBounceText(text, pos, color)
    pos[2] = pos[2] - 60
    local t = Typers.InstText.New(text, pos, "TopAll")
    t.bondfont = {
        engfont = {font = "DAMAGEBACK.TTF", size = 32},
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
    t.color = (color or {1, 0, 0})
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
        engfont = {font = "DAMAGEBACK.TTF", size = 32},
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

function ui.barUpdate()
    bar_maxhp.xscale = math.min(bar_maxlength, Player.maxhp * 1.21)
    bar_hp.xscale = Player.hp / Player.maxhp * bar_maxhp.xscale

    if (Player.kr + Player.hp > Player.maxhp) then
        Player.kr = Player.maxhp - Player.hp
    end

    if (Player.kr > 0) then
        if (Player.hp <= 0) then Player.hp = 1 end
        time_kr = time_kr + 1
        if (Player.kr > 20) then
            if (time_kr >= 15) then Player.kr = math.max(math.floor(Player.kr - 1), 0); time_kr = 0 end
        elseif (Player.kr > 10) then
            if (time_kr >= 30) then Player.kr = math.max(math.floor(Player.kr - 1), 0); time_kr = 0 end
        elseif (Player.kr > 0) then
            if (time_kr >= 40) then Player.kr = math.max(math.floor(Player.kr - 1), 0); time_kr = 0 end
        else
            Player.kr = 0
        end
    else
        Player.kr = 0
    end

    bar_kr.x = bar_hp.x + bar_hp.xscale
    bar_kr.xscale = Player.kr / Player.maxhp * bar_maxhp.xscale
end

function ui.Update(dt)
    buttons.Update()
    ui.button_selecting = buttons.button_selecting
    state.Update()

    ui.barUpdate()

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
                table.remove(ui._bouncetexts, i)
            end
        end
    end

    for i = #ui._notbtexts, 1, -1
    do
        local t = ui._notbtexts[i]
        t._time = t._time + 1
        if (t._time >= 30) then
            t:Destroy()
            table.remove(ui._notbtexts, i)
        end
    end
end

-- ---------------------------------------------------------------------------
-- Public API — position
-- ---------------------------------------------------------------------------

--- Move the status TEXT block: `x` is where the name starts, `y` the shared
--- baseline of the line. LV / "HP" are offset from it, and the "KR" label plus
--- the HP numbers follow the right end of the HP bar (so they stay put unless
--- the bars move too). Passing only `x` keeps the current `y`.
---@param x number
---@param y number|nil
function ui.SetTextPosition(x, y)
    if (type(x) ~= "number") then return end
    text_pos[1] = x
    if (type(y) == "number") then text_pos[2] = y end
end

--- Origin of the status text block.
---@return number x, number y
function ui.GetTextPosition()
    return text_pos[1], text_pos[2]
end

--- Shift the status text block by (dx, dy).
---@param dx number
---@param dy number|nil
function ui.MoveTextPosition(dx, dy)
    ui.SetTextPosition(text_pos[1] + (dx or 0), text_pos[2] + (dy or 0))
end

--- Move the HP BARS: `x` is the shared LEFT edge (bar_maxhp and bar_hp both
--- start there), `y` their shared height. bar_kr tracks the right end of
--- bar_hp automatically, so it is only re-anchored vertically here.
---@param x number
---@param y number|nil
function ui.SetBarPosition(x, y)
    if (type(x) ~= "number") then return end
    bar_maxhp:MoveTo(x, y or bar_maxhp.y)
    bar_hp:MoveTo(x, y or bar_hp.y)
    -- bar_kr hangs off the right end of bar_hp (same rule as barUpdate), so
    -- re-anchor it right away instead of waiting for the next update.
    bar_kr.x = x + (bar_hp.xscale or 0)
    if (type(y) == "number") then bar_kr.y = y end
end

--- Origin of the HP bars (shared left edge / shared height).
---@return number x, number y
function ui.GetBarPosition()
    return bar_maxhp.x, bar_maxhp.y
end

--- Shift the HP bars by (dx, dy).
---@param dx number
---@param dy number|nil
function ui.MoveBarPosition(dx, dy)
    local x, y = ui.GetBarPosition()
    ui.SetBarPosition(x + (dx or 0), y + (dy or 0))
end

--- Shift the whole HUD (status text + HP bars) by the same (dx, dy).
---@param dx number
---@param dy number|nil
function ui.MovePosition(dx, dy)
    ui.MoveTextPosition(dx, dy)
    ui.MoveBarPosition(dx, dy)
end

--- The "HP" label follows the name / LV text but never moves left of this x
--- (default 245).
---@param x number
function ui.SetHPNameLimit(x)
    if (type(x) ~= "number") then return end
    hpname_limit = x
end

--- Snapshot of every LIVE position in one call — handy for debugging or for
--- aligning other elements with the HUD (the values are the ones used by the
--- last draw pass).
---@return table layout
function ui.GetLayout()
    return {
        text = {text_pos[1], text_pos[2]},       -- configured text origin
        bar = {bar_maxhp.x, bar_maxhp.y},        -- configured bar origin
        hpname_limit = hpname_limit,             -- clamp for the "HP" label
        name = {pos_name[1], pos_name[2]},
        lv = {pos_lv[1], pos_lv[2]},
        hpname = {pos_hpname[1], pos_hpname[2]}, -- same x as pos_.hpname
        krname = {pos_krname[1], pos_krname[2]},
        hptext = {pos_hptext[1], pos_hptext[2]},
    }
end

-- ---------------------------------------------------------------------------
-- Public API — HP bar sprites
--
-- The sprites are handed back directly, so everything on them can be read or
-- changed (color, alpha, outline, visible, ...). Two caveats:
--   * `xscale` is rewritten every frame by ui.barUpdate() from Player.hp /
--     Player.maxhp / Player.kr — it is not a place to store your own scale.
--   * the left edge is a layout concern: use ui.SetBarPosition() instead of
--     moving bar_maxhp / bar_hp by hand, otherwise they can drift apart.
-- ---------------------------------------------------------------------------

--- The current-HP bar (yellow).
---@return Sprite
function ui.GetHPBar()
    return bar_hp
end

--- The max-HP (background) bar (red).
---@return Sprite
function ui.GetMaxHPBar()
    return bar_maxhp
end

--- The KR bar (purple).
---@return Sprite
function ui.GetKRBar()
    return bar_kr
end

--- All three bars at once.
---@return table {maxhp = Sprite, hp = Sprite, kr = Sprite}
function ui.GetBars()
    return {maxhp = bar_maxhp, hp = bar_hp, kr = bar_kr}
end

return ui