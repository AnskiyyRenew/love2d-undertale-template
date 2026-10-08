--[[
    GUI Slider - a horizontal value slider (track + knob)

    Pure component: it does not read input. The owning scene drives value
    changes via :Move(dir) / :SetValue(v) / :DragTo(x) / :Wheel(dir);
    :SetFocused toggles the knob highlight. Drawn through Layers.add_external,
    like the rest of the GUI.

    Layout: the knob is a knobSize x knobSize square; the track is a thin bar
    vertically centred with the knob. Knob x is mapped from value over [min,max].

    Mouse support:
      :ContainsPoint(x,y)  hit-test (track + knob, with 4px slack)
      :DragTo(cx, cy)      set value from a canvas x (clamped, stepped)
      :Wheel(dir)          move by +/- step (same as :Move)

    Usage:
      local s = GUI.Slider.New{ x=200, y=300, w=240, min=0, max=100, value=50, step=1 }
      s:SetFocused(true)
      -- in scene.update, when focused and up/down pressed:
      s:Move(1)    -- +step
      s:Move(-1)   -- -step
      -- or with mouse:
      if (s:ContainsPoint(mx, my)) then s:SetFocused(true) end
      if (dragging) then s:DragTo(mx, my) end
      if (wheel ~= 0) then s:Wheel(wheel) end
      local v = s:GetValue()
]]

local primitives = require((...):match("(.-)[^%.]+$") .. "primitives")
local Label      = require((...):match("(.-)[^%.]+$") .. "label")

local Slider = {}
Slider.__index = Slider

local function clamp(v, lo, hi)
    return math.max(lo, math.min(v, hi))
end

function Slider.New(opts)
    opts = opts or {}
    local self = setmetatable({}, Slider)
    self.x = opts.x or 0
    self.y = opts.y or 0
    self.w = opts.w or 200
    self.min = opts.min or 0
    self.max = opts.max or 100
    self.step = opts.step or 1
    self.trackH   = opts.trackH   or 4
    self.knobSize = opts.knobSize or 10
    self.trackColor   = opts.trackColor   or {0.3, 0.3, 0.3}
    self.knobColor    = opts.knobColor    -- nil = MainColor at draw time
    self.focusedColor = opts.focusedColor or {1, 1, 0}
    self.layer = opts.layer or 1000
    self.focused = (opts.focused == true)
    self.showLabel = (opts.showLabel ~= false)
    self._destroyed = false
    -- snap initial value into range and onto the step grid
    self.value = clamp(opts.value or self.min, self.min, self.max)
    self.value = self:_snap(self.value)
    -- register draw
    self._entry = Layers.add_external(function()
        if (not self._destroyed) then self:_draw() end
    end, self.layer)
    -- optional numeric readout to the right of the track
    if (self.showLabel) then
        self._label = Label.New(tostring(self.value), {self.x + self.w + 12, self.y - 4}, self.layer)
    end
    return self
end

-- snap a value onto the step grid (keeps float drift out of repeated moves)
function Slider:_snap(v)
    if (self.step == 0) then return v end
    local k = math.floor((v - self.min) / self.step + 0.5)
    return self.min + k * self.step
end

function Slider:_draw()
    -- track vertically centred with the knob
    local trackY = self.y + (self.knobSize - self.trackH) / 2
    primitives.drawRect(self.x, trackY, self.w, self.trackH, self.trackColor)
    -- knob position from value
    local span = (self.max - self.min)
    local t = (span == 0) and 0 or (self.value - self.min) / span
    local knobX = self.x + t * (self.w - self.knobSize)
    local knobColor = self.focused and self.focusedColor or self.knobColor
    primitives.drawRect(knobX, self.y, self.knobSize, self.knobSize, knobColor)
end

-- refresh the numeric readout label
function Slider:_syncLabel()
    if (self._label) then
        self._label:SetText(tostring(self.value))
    end
end

function Slider:GetValue()
    return self.value
end

function Slider:SetValue(v)
    self.value = clamp(self:_snap(v), self.min, self.max)
    self:_syncLabel()
end

function Slider:SetRange(min, max)
    self.min = min or self.min
    self.max = max or self.max
    self.value = clamp(self.value, self.min, self.max)
    self:_syncLabel()
end

--- Move by dir steps (+1 / -1). Each step is self.step; the result snaps
--- onto the step grid to avoid float drift from repeated moves.
function Slider:Move(dir)
    local stepped = self.value + dir * self.step
    self:SetValue(stepped)
end

--- Set value from a canvas-space x (mouse drag). The knob's leading edge
--- follows the cursor: t = (cx - x) / (w - knobSize).
function Slider:DragTo(cx, cy)
    local span = self.max - self.min
    local denom = self.w - self.knobSize
    local t = (denom <= 0) and 0 or (cx - self.x) / denom
    if (t < 0) then t = 0 elseif (t > 1) then t = 1 end
    self:SetValue(self.min + t * span)
end

--- Mouse wheel: same as :Move(dir).
function Slider:Wheel(dir)
    self:Move(dir)
end

--- Hit-test the slider area (track + knob, with 4px slack for easy grabbing).
function Slider:ContainsPoint(px, py)
    local pad = 4
    return px >= self.x - pad and px <= self.x + self.w + pad
       and py >= self.y - pad and py <= self.y + self.knobSize + pad
end

function Slider:SetFocused(v)
    self.focused = (v == true)
end

function Slider:SetPosition(x, y)
    self.x = x
    self.y = y
    if (self._label) then self._label:SetPosition(x + self.w + 12, y - 4) end
end

function Slider:Destroy()
    if (self._destroyed) then return end
    self._destroyed = true
    if (self._entry) then
        Layers.remove_external(self._entry)
        self._entry = nil
    end
    if (self._label) then
        self._label:Destroy()
        self._label = nil
    end
end
Slider.Remove = Slider.Destroy

return Slider
