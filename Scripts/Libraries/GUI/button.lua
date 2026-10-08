--[[
    GUI Button - UNDERTALE-style button

    Selection state: prefix (default "> ") + yellow colour; when not selected a
    space pad of equal width is used so the text never shifts left/right when
    toggling selection. Colour/prefix are all customisable.

    Mouse support: an optional hit area (w x h) plus a hover state. Hover sets
    the yellow colour (without the prefix, so keyboard-selected and mouse-hover
    look distinct); click is detected by the scene via :ContainsPoint.

    The button does NOT read input itself -- selection, hover, and triggering
    are driven externally (the scene's input handling) via SetSelected /
    SetHovered / Trigger. This lets a button work with keyboard, gamepad, or
    mouse input alike.

    Usage:
      local btn = GUI.Button.New{
          x = 200, y = 150, text = "FIGHT",
          w = 200, h = 30,            -- hit area (mouse); defaults 180x24
          onSelect = function() ... end,
      }
      btn:SetSelected(true)
      btn:SetHovered(true)
      if (confirm pressed) then btn:Trigger() end

    Monospace alignment: determination_mono is monospaced, so prefix "> " (2
    chars) and pad "  " (2 chars) are the same width; text doesn't jitter on toggle.
]]

local Label = require((...):match("(.-)[^%.]+$") .. "label")

local Button = {}
Button.__index = Button

local SEL_COLOR  = {1, 1, 0}   -- selection yellow (UNDERTALE FIGHT/ACT/ITEM/MERCY)
local NORM_COLOR = {1, 1, 1}   -- unselected white

function Button.New(opts)
    opts = opts or {}
    local self = setmetatable({}, Button)
    self.x = opts.x or 0
    self.y = opts.y or 0
    self.w = opts.w or 180       -- hit area width (mouse)
    self.h = opts.h or 24        -- hit area height (mouse)
    self.text = opts.text or ""
    self.selected = (opts.selected == true)
    self.hovered  = false
    self.onSelect = opts.onSelect
    self.layer = opts.layer or 1000
    self.prefix = opts.prefix or ">"      -- selection prefix
    self.pad = opts.pad or "  "           -- unselected pad (default 2 spaces, equals "> " width)
    self.colorNormal = opts.colorNormal or NORM_COLOR
    self.colorSelected = opts.colorSelected or SEL_COLOR
    self._label = Label.New(self:_displayText(), {self.x, self.y}, self.layer)
    self:_applyStyle()
    return self
end

-- The text to display right now (with prefix / pad). Hover does NOT add a
-- prefix -- only keyboard selection does, so hover and selection stay visually
-- distinct when both are active.
function Button:_displayText()
    if (self.selected) then
        return self.prefix .. " " .. self.text
    end
    return self.pad .. self.text
end

-- Apply selected / hovered / normal colour.
function Button:_applyStyle()
    local c = (self.selected or self.hovered) and self.colorSelected or self.colorNormal
    self._label:SetColor(c[1], c[2], c[3])
end

-- Rebuild text and colour
function Button:_refresh()
    self._label:SetText(self:_displayText())
    self:_applyStyle()
end

--- Set selection state
function Button:SetSelected(v)
    local nxt = (v == true)
    if (self.selected == nxt) then return end
    self.selected = nxt
    self:_refresh()
end

--- Set hover state (mouse over the hit area). Only changes colour.
function Button:SetHovered(v)
    local nxt = (v == true)
    if (self.hovered == nxt) then return end
    self.hovered = nxt
    self:_applyStyle()
end

function Button:SetText(t)
    self.text = t or ""
    self:_refresh()
end

function Button:SetPosition(x, y)
    self.x = x
    self.y = y
    self._label:SetPosition(x, y)
end

function Button:SetOnSelect(fn)
    self.onSelect = fn
end

--- Hit-test the mouse hit area (top-left + w x h).
function Button:ContainsPoint(px, py)
    return px >= self.x and px <= self.x + self.w
       and py >= self.y and py <= self.y + self.h
end

--- Fire the select callback. Returns onSelect's return value if any.
function Button:Trigger()
    if (self.onSelect) then
        return self.onSelect(self)
    end
end

function Button:Destroy()
    if (self._label) then
        self._label:Destroy()
        self._label = nil
    end
end
Button.Remove = Button.Destroy

return Button
