--[[
    GUI Primitives - low-level draw primitives (UNDERTALE style)

    Top-left (x, y) + size (w, h); pixel-snapped (floor(v + 0.5), matching
    Sprites.snapCoord). Colours are 0-1 {r,g,b} / {r,g,b,a}; every draw resets
    to white afterwards so colour never leaks into other layers.

    Provides: drawRect, drawWindow (two stacked rects: thick border + fill),
    drawCenteredWindow (battle-box centre semantics), drawBorder /
    drawCenteredBorder (hollow 4-edge border), snap / applyColor / resetColor /
    mainColor. Fonts live in Label/Button via InstText; this file only draws
    rectangles.
]]

local primitives = {}

-- UNDERTALE default palette (0-1). MainColor is read at runtime from Global; white fallback.
primitives.COLORS = {
    WHITE   = {1, 1, 1},
    BLACK   = {0, 0, 0},
    YELLOW  = {1, 1, 0},   -- selection state (FIGHT/ACT/ITEM/MERCY yellow)
    RED     = {1, 0, 0},   -- soul red
    ORANGE  = {1, 0.5, 0},
    BLUE    = {0, 0.5, 1},
    GREEN   = {0, 1, 0},
}

--- Pixel snap (matches Sprites.snapCoord: floor(v + 0.5))
local function snap(v)
    return math.floor(v + 0.5)
end
primitives.snap = snap

--- Read MainColor at runtime (hacks may change it live); white fallback.
local function mainColor()
    if (Global and Global.GetVariable) then
        return Global.GetVariable("MainColor") or {1, 1, 1}
    end
    return {1, 1, 1}
end
primitives.mainColor = mainColor

--- Apply colour (accepts {r,g,b} or {r,g,b,a}; alpha overrides if given)
local function applyColor(c, a)
    c = c or {1, 1, 1}
    SE.graphics.setColor(c[1] or 1, c[2] or 1, c[3] or 1, a or c[4] or 1)
end
primitives.applyColor = applyColor

--- Reset to white (call after every draw to prevent colour leaks)
local function resetColor()
    SE.graphics.setColor(1, 1, 1, 1)
end
primitives.resetColor = resetColor

--- Single solid rectangle (coordinates pre-snapped)
function primitives.drawRect(x, y, w, h, color, alpha)
    applyColor(color, alpha)
    SE.graphics.rectangle("fill", snap(x), snap(y), snap(w), snap(h))
    resetColor()
end

--- Two-rectangle stacked window (same technique as the UNDERTALE battle box):
---   outer = (x-t, y-t, w+2t, h+2t) with outer colour (the thick border)
---   inner = (x,   y,   w,   h  ) with inner colour (the fill, default black)
--- Outer is drawn first (below), inner on top covers the centre, leaving the
--- thick border. See Scripts/Libraries/Battle/Arenas.lua: white (w+2t,h+2t)
--- + black (w,h).
function primitives.drawWindow(x, y, w, h, thickness, outer, inner, outerAlpha, innerAlpha)
    thickness = thickness or 5
    outer = outer or mainColor()
    inner = inner or {0, 0, 0}
    local t = thickness
    applyColor(outer, outerAlpha)
    SE.graphics.rectangle("fill", snap(x - t), snap(y - t), snap(w + t * 2), snap(h + t * 2))
    applyColor(inner, innerAlpha)
    SE.graphics.rectangle("fill", snap(x), snap(y), snap(w), snap(h))
    resetColor()
end

--- Centre-point variant (cx, cy = rectangle centre). Matches Arenas semantics.
function primitives.drawCenteredWindow(cx, cy, w, h, thickness, outer, inner, outerAlpha, innerAlpha)
    primitives.drawWindow(cx - w / 2, cy - h / 2, w, h, thickness, outer, inner, outerAlpha, innerAlpha)
end

--- Hollow border (4 edge rectangles; interior transparent, shows layers below).
--- For decorative frames only (no interior fill). Thickness = edge thickness.
function primitives.drawBorder(x, y, w, h, thickness, color, alpha)
    thickness = thickness or 5
    color = color or mainColor()
    local t = thickness
    applyColor(color, alpha)
    SE.graphics.rectangle("fill", snap(x), snap(y), snap(w), snap(t))
    SE.graphics.rectangle("fill", snap(x), snap(y + h - t), snap(w), snap(t))
    SE.graphics.rectangle("fill", snap(x), snap(y), snap(t), snap(h))
    SE.graphics.rectangle("fill", snap(x + w - t), snap(y), snap(t), snap(h))
    resetColor()
end

--- Centre-point hollow border
function primitives.drawCenteredBorder(cx, cy, w, h, thickness, color, alpha)
    primitives.drawBorder(cx - w / 2, cy - h / 2, w, h, thickness, color, alpha)
end

return primitives
