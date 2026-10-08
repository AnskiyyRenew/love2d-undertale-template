--[[
    GUI Dropdown - UNDERTALE-style dropdown menu

    A trigger button showing the currently-selected item; clicking it expands
    a vertical list of options. The menu opens either above ("up") or below
    ("down") the trigger. A single width `w` sizes the menu (option rows);
    `buttonW` (optional, defaults to `w`) sizes the trigger button separately.

    Pure component: it does not read input. The scene polls hover each frame
    via :SetHover(mx,my) and routes clicks via :HandleClick(mx,my), which
    returns true when the click landed on the dropdown (so the scene can skip
    letting other components handle it). Clicking an option selects it and
    collapses the menu; clicking outside collapses the menu (and returns false
    so the scene is free to forward that same click elsewhere).

    Selection state follows the rest of the GUI library:
      selected option  -> prefix "> " + yellow (like Button:SetSelected)
      hovered option   -> yellow, no prefix (like Button:SetHovered)
      normal           -> white, no prefix
    The trigger button border turns yellow while hovered or expanded.

    Layering: backgrounds (trigger box + menu box) sit on `layer`; all text
    sits on `layer + 1`. Same-layer sorting is by _id (registration order),
    so a same-layer Label + background box would let the black interior cover
    the text -- the split avoids that (same fix as TextInput).

    Usage:
      local dd = GUI.Dropdown.New{
          x = 200, y = 200, w = 180,
          buttonW = 180,          -- optional; defaults to w
          buttonH = 24, itemH = 24,
          items = {"Red", "Green", "Blue"},
          selected = 1,
          expand = "down",        -- "up" | "down"
          layer = 1001,
          onSelect = function(self, idx, text) print(idx, text) end,
      }
      -- in scene.update (after GUI.Input.Update()):
      local mx, my = GUI.Input.GetCanvasMouse()
      dd:SetHover(mx, my)
      if (GUI.Input.IsPressed(1)) then dd:HandleClick(mx, my) end
]]

local primitives = require((...):match("(.-)[^%.]+$") .. "primitives")
local Label      = require((...):match("(.-)[^%.]+$") .. "label")

local Dropdown = {}
Dropdown.__index = Dropdown

local WHITE   = {1, 1, 1}
local YELLOW  = {1, 1, 0}   -- selection / hover (UNDERTALE FIGHT/ACT/ITEM/MERCY yellow)
local BLACK   = {0, 0, 0}
local FONT_H  = 27          -- determination_mono size; InstText default bondfont
local TEXT_PAD = 6          -- left padding inside boxes
local DEFAULT_ITEM_H = 24
local PREFIX_SEL = "> "     -- selected option prefix
local PREFIX_PAD = "  "     -- unselected pad (2 spaces = "> " width, monospace)

function Dropdown.New(opts)
    opts = opts or {}
    local self = setmetatable({}, Dropdown)
    self.x = opts.x or 0
    self.y = opts.y or 0
    self.w = opts.w or 180                 -- menu width (option row width)
    self.buttonW = opts.buttonW or self.w  -- trigger button width (defaults to menu width)
    self.buttonH = opts.buttonH or DEFAULT_ITEM_H
    self.itemH   = opts.itemH   or DEFAULT_ITEM_H
    self.thickness = opts.thickness or 3
    self.gap = opts.gap or 0              -- gap between trigger and menu
    self.expand = opts.expand or "down"  -- "up" | "down"
    self.items = opts.items or {}
    self.layer = opts.layer or 1000
    self.onSelect = opts.onSelect
    self.expanded = false
    self._triggerHovered = false
    self._optionHovered = nil
    self._destroyed = false
    -- clamp selected into range
    self.selected = opts.selected or 1
    if (#self.items > 0) then
        if (self.selected < 1) then self.selected = 1 end
        if (self.selected > #self.items) then self.selected = #self.items end
    else
        self.selected = 0
    end

    local bgLayer  = self.layer       -- backgrounds (boxes)
    local txtLayer = self.layer + 1   -- text labels

    -- background draw entry: trigger box (always) + menu box (when expanded)
    self._bgEntry = Layers.add_external(function()
        if (not self._destroyed) then self:_drawBackground() end
    end, bgLayer)

    -- trigger button text label
    local btnTextY = self.y + (self.buttonH - FONT_H) / 2 + 2
    self._btnLabel = Label.New(self:_triggerText(), {self.x + TEXT_PAD, btnTextY}, txtLayer)
    self._btnLabel:SetAlign("left")

    -- per-option text labels (positioned at construction; toggled by alpha when collapsed)
    self._optLabels = {}
    for i = 1, #self.items do
        local oy = self:_optionY(i)
        local otextY = oy + (self.itemH - FONT_H) / 2 + 2
        local lbl = Label.New(self:_optionText(i), {self.x + TEXT_PAD, otextY}, txtLayer)
        lbl:SetAlign("left")
        lbl:SetAlpha(0)   -- hidden until expanded
        self._optLabels[i] = lbl
    end

    self:_refreshColors()
    return self
end

-- Menu top-left Y. "down" -> just below the trigger; "up" -> stacked above it.
function Dropdown:_menuY()
    if (self.expand == "up") then
        return self.y - self.gap - #self.items * self.itemH
    end
    return self.y + self.buttonH + self.gap
end

-- Top-left Y of option i (inside the menu).
function Dropdown:_optionY(i)
    return self:_menuY() + (i - 1) * self.itemH
end

-- Draw trigger box (always) + menu box (when expanded). Trigger border turns
-- yellow while hovered or expanded; menu border stays white.
function Dropdown:_drawBackground()
    local btnBorder = (self._triggerHovered or self.expanded) and YELLOW or WHITE
    primitives.drawWindow(self.x, self.y, self.buttonW, self.buttonH,
        self.thickness, btnBorder, BLACK)
    if (self.expanded and #self.items > 0) then
        local menuY = self:_menuY()
        primitives.drawWindow(self.x, menuY, self.w, #self.items * self.itemH,
            self.thickness, WHITE, BLACK)
    end
end

-- Trigger label text = currently selected item (no prefix; colour carries state).
function Dropdown:_triggerText()
    if (self.items[self.selected]) then
        return tostring(self.items[self.selected])
    end
    return ""
end

-- Option i text: selected gets "> " prefix; others get the 2-space pad so the
-- column never shifts left/right when toggling selection (monospace).
function Dropdown:_optionText(i)
    local t = tostring(self.items[i] or "")
    if (i == self.selected) then
        return PREFIX_SEL .. t
    end
    return PREFIX_PAD .. t
end

-- Refresh all label colours + option visibility (alpha).
function Dropdown:_refreshColors()
    local btnColor = (self._triggerHovered or self.expanded) and YELLOW or WHITE
    self._btnLabel:SetColor(btnColor[1], btnColor[2], btnColor[3])
    for i, lbl in ipairs(self._optLabels) do
        local isSel = (i == self.selected)
        local isHov = (i == self._optionHovered)
        local c = (isSel or isHov) and YELLOW or WHITE
        lbl:SetColor(c[1], c[2], c[3])
        lbl:SetAlpha(self.expanded and 1 or 0)
    end
end

-- Rebuild all label text (call when selected or items change).
function Dropdown:_refreshText()
    self._btnLabel:SetText(self:_triggerText())
    for i, lbl in ipairs(self._optLabels) do
        lbl:SetText(self:_optionText(i))
    end
end

--- Internal: select option idx (fires onSelect), rebuild text + colours.
function Dropdown:_select(idx)
    if (idx == self.selected) then return end
    self.selected = idx
    self:_refreshText()
    self:_refreshColors()
    if (self.onSelect) then
        self.onSelect(self, idx, self.items[idx])
    end
end

--- Hit-test the trigger button rect (including the border).
function Dropdown:_triggerContains(mx, my)
    return mx >= self.x and mx <= self.x + self.buttonW
       and my >= self.y and my <= self.y + self.buttonH
end

--- Hit-test the expanded menu. Returns the option index under the point or nil.
function Dropdown:_optionAt(mx, my)
    if (not self.expanded or #self.items == 0) then return nil end
    if (mx < self.x or mx > self.x + self.w) then return nil end
    local menuY = self:_menuY()
    if (my < menuY or my > menuY + #self.items * self.itemH) then return nil end
    local idx = math.floor((my - menuY) / self.itemH) + 1
    if (idx < 1 or idx > #self.items) then return nil end
    return idx
end

--- Whether the point falls on the trigger or the expanded menu (for "click
--- outside to close" decisions the scene can do itself; HandleClick already
--- closes on outside clicks).
function Dropdown:ContainsAny(mx, my)
    if (self:_triggerContains(mx, my)) then return true end
    return (self:_optionAt(mx, my) ~= nil)
end

--- Update hover state from the current mouse position. Call every frame
--- (after GUI.Input.Update) so hover highlights track the cursor.
function Dropdown:SetHover(mx, my)
    self._triggerHovered = self:_triggerContains(mx, my)
    self._optionHovered = nil
    if (self.expanded) then
        local idx = self:_optionAt(mx, my)
        if (idx) then self._optionHovered = idx end
    end
    self:_refreshColors()
end

--- Handle a mouse click. Returns true if the click landed on the dropdown
--- (trigger or an option); false if it landed outside (the menu is still
--- collapsed in that case, so the scene is free to forward the click to other
--- components).
---   collapsed + click trigger  -> expand (true)
---   expanded  + click option   -> select + collapse (true)
---   expanded  + click trigger   -> collapse (true)
---   expanded  + click outside  -> collapse (false)
---   collapsed + click outside  -> no-op (false)
function Dropdown:HandleClick(mx, my)
    if (self.expanded) then
        local optIdx = self:_optionAt(mx, my)
        if (optIdx) then
            self:_select(optIdx)
            self.expanded = false
            self:_refreshColors()
            return true
        end
        if (self:_triggerContains(mx, my)) then
            self.expanded = false
            self._triggerHovered = true
            self._optionHovered = nil
            self:_refreshColors()
            return true
        end
        -- outside click -> collapse, do NOT consume
        self.expanded = false
        self._triggerHovered = false
        self._optionHovered = nil
        self:_refreshColors()
        return false
    end
    if (self:_triggerContains(mx, my)) then
        self.expanded = true
        self._triggerHovered = true
        self:_refreshColors()
        return true
    end
    return false
end

--- Programmatically open / close the menu.
function Dropdown:SetExpanded(v)
    local nxt = (v == true)
    if (self.expanded == nxt) then return end
    self.expanded = nxt
    self:_refreshColors()
end

function Dropdown:IsExpanded()
    return self.expanded
end

function Dropdown:GetSelected()
    return self.selected, self.items[self.selected]
end

function Dropdown:GetSelectedText()
    return self.items[self.selected]
end

--- Replace the option list. Rebuilds the option labels; tries to keep the
--- current selection by index, clamped into the new range.
function Dropdown:SetItems(items)
    self.items = items or {}
    -- rebuild option labels
    for _, lbl in ipairs(self._optLabels) do lbl:Destroy() end
    self._optLabels = {}
    if (#self.items > 0) then
        if (self.selected < 1) then self.selected = 1 end
        if (self.selected > #self.items) then self.selected = #self.items end
    else
        self.selected = 0
    end
    local txtLayer = self.layer + 1
    for i = 1, #self.items do
        local oy = self:_optionY(i)
        local otextY = oy + (self.itemH - FONT_H) / 2 + 2
        local lbl = Label.New(self:_optionText(i), {self.x + TEXT_PAD, otextY}, txtLayer)
        lbl:SetAlign("left")
        lbl:SetAlpha(self.expanded and 1 or 0)
        self._optLabels[i] = lbl
    end
    self:_refreshColors()
end

function Dropdown:SetPosition(x, y)
    self.x = x
    self.y = y
    local btnTextY = self.y + (self.buttonH - FONT_H) / 2 + 2
    self._btnLabel:SetPosition(self.x + TEXT_PAD, btnTextY)
    for i, lbl in ipairs(self._optLabels) do
        local oy = self:_optionY(i)
        lbl:SetPosition(self.x + TEXT_PAD, oy + (self.itemH - FONT_H) / 2 + 2)
    end
end

function Dropdown:SetOnSelect(fn)
    self.onSelect = fn
end

function Dropdown:Destroy()
    if (self._destroyed) then return end
    self._destroyed = true
    if (self._bgEntry) then
        Layers.remove_external(self._bgEntry)
        self._bgEntry = nil
    end
    if (self._btnLabel) then
        self._btnLabel:Destroy()
        self._btnLabel = nil
    end
    for _, lbl in ipairs(self._optLabels) do lbl:Destroy() end
    self._optLabels = {}
end
Dropdown.Remove = Dropdown.Destroy

return Dropdown
