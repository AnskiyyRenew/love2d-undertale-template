--[[
    GUI Window - UNDERTALE-style visual window

    Two stacked rectangles (thick outer border + inner fill); purely visual,
    no collision, no player constraint. Driven by Layers.add_external; layer
    defaults to 1000 (above battle elements). Animation uses the same
    smooth_value approach as Arenas (rate-limited approach toward a target).

    Usage:
      local w = GUI.Window.New{ x=200, y=100, w=240, h=120, thickness=5 }
      w:ResizeWithSpeed(300, 150, 15, 15)   -- smooth resize (call w:Update(dt) in scene.update)
      w:SetVisible(false)
      w:SetCenter(320, 240)                 -- switch to centre-point semantics
      w:Destroy()                           -- on scene end / cleanup

    Coordinate convention: top-left (x,y) + size (w,h). :SetCenter switches to centre.
    Note: Update must be driven by the caller (scene.update); omit for static menus.
]]

local primitives = require((...):match("(.-)[^%.]+$") .. "primitives")

local Window = {}
Window.__index = Window

-- Rate-limited approach (same as Arenas.smooth_value)
local function smooth(value, target, speed)
    if (value > target) then
        return math.max(value - speed, target)
    elseif (value < target) then
        return math.min(value + speed, target)
    end
    return value
end

local DEFAULT_SPEEDS = { x = 7.5, y = 7.5, w = 15, h = 15, t = 15 }

--- Create a window instance
---@param opts table {x,y,w,h,thickness,outer,inner,layer,visible,...}
function Window.New(opts)
    opts = opts or {}
    local self = setmetatable({}, Window)
    self.x = opts.x or 0
    self.y = opts.y or 0
    self.w = (opts.w or 100)
    self.h = (opts.h or 100)
    self.thickness = opts.thickness or 5
    self.outer = opts.outer          -- nil = MainColor at draw time
    self.inner = opts.inner or {0, 0, 0}
    self.outerAlpha = opts.outerAlpha
    self.innerAlpha = opts.innerAlpha
    self.layer = opts.layer or 1000
    self.visible = (opts.visible ~= false)
    self._entry = nil
    self._destroyed = false
    -- animation target / speeds
    self.target = { x = self.x, y = self.y, w = self.w, h = self.h, thickness = self.thickness }
    self.speeds = {}
    for k, v in pairs(DEFAULT_SPEEDS) do self.speeds[k] = v end
    -- register draw with Layers
    self._entry = Layers.add_external(function()
        if (not self._destroyed and self.visible) then
            primitives.drawWindow(self.x, self.y, self.w, self.h,
                self.thickness, self.outer, self.inner,
                self.outerAlpha, self.innerAlpha)
        end
    end, self.layer)
    return self
end

--- Move toward target. imm=true syncs current coords immediately (no animation).
function Window:MoveTo(x, y, imm)
    self.target.x = x
    self.target.y = y
    if (imm) then self.x = x; self.y = y end
end

--- Switch to centre-point coordinate semantics (converts to top-left)
function Window:SetCenter(cx, cy, imm)
    self:MoveTo(cx - self.w / 2, cy - self.h / 2, imm)
end

--- Resize. imm=true syncs immediately.
function Window:Resize(w, h, imm)
    self.target.w = (w > 0) and w or 0
    self.target.h = (h > 0) and h or 0
    if (imm) then self.w = self.target.w; self.h = self.target.h end
end

--- Resize and set the approach speed (pixels/frame)
function Window:ResizeWithSpeed(w, h, sw, sh)
    self.target.w = (w > 0) and w or 0
    self.target.h = (h > 0) and h or 0
    self.speeds.w = sw or 15
    self.speeds.h = sh or 15
end

--- Set thickness. imm=true syncs immediately.
function Window:SetThickness(t, imm)
    self.target.thickness = t or 5
    if (imm) then self.thickness = self.target.thickness end
end

function Window:SetOuterColor(c)  self.outer = c end
function Window:SetInnerColor(c)  self.inner = c end
function Window:SetOuterAlpha(a) self.outerAlpha = a end
function Window:SetInnerAlpha(a) self.innerAlpha = a end

function Window:SetVisible(v) self.visible = (v ~= false) end

function Window:SetLayer(layer)
    self.layer = layer
    if (self._entry) then
        self._entry.layer = layer
        Layers.mark_dirty()
    end
end

--- Smooth toward target. Call from scene.update.
function Window:Update(dt)
    self.x = smooth(self.x, self.target.x, self.speeds.x)
    self.y = smooth(self.y, self.target.y, self.speeds.y)
    self.w = smooth(self.w, self.target.w, self.speeds.w)
    self.h = smooth(self.h, self.target.h, self.speeds.h)
    self.thickness = smooth(self.thickness, self.target.thickness, self.speeds.t)
end

--- Return centre coordinates
function Window:GetCenter()
    return self.x + self.w / 2, self.y + self.h / 2
end

--- Whether a point falls inside the window rect (including the thick border)
function Window:ContainsPoint(px, py)
    local t = self.thickness
    return px >= self.x - t and px <= self.x + self.w + t
       and py >= self.y - t and py <= self.y + self.h + t
end

--- Destroy (idempotent)
function Window:Destroy()
    if (self._destroyed) then return end
    self._destroyed = true
    if (self._entry) then
        Layers.remove_external(self._entry)
        self._entry = nil
    end
end
Window.Remove = Window.Destroy

return Window
