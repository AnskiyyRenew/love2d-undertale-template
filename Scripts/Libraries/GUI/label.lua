--[[
    GUI Label - text label (mixed Latin/CJK, wraps Typers.InstText)

    Reuses Typers.InstText's bondfont mechanism: Latin determination_mono(27),
    CJK simsun(13) scaled x2 (scale=2 ~= 26). InstText auto-splits Latin vs CJK
    glyphs by byte length, so callers don't handle fonts. Font caching and Text
    object reuse are handled inside InstText.

    Usage:
      local lbl = GUI.Label.New("Hello 世界", {320, 200})
      lbl:SetAlign("center")
      lbl:SetText("新文字")
      lbl:SetColor(1, 1, 0)
      lbl:Destroy()

    Coordinate convention: top-left origin (x,y) (InstText origin); text flows
    down-right. Align mode: "left" (default) / "center" / "right".
]]

local Label = {}
Label.__index = Label

--- Create a text label
---@param text string text
---@param pos table {x, y} origin
---@param layer number|nil layer (default 1000)
---@param size table|nil {boxWidth, _} auto-wrap box width (default {640,0} = no wrap)
function Label.New(text, pos, layer, size)
    local inst = Typers.InstText.New(text, pos, (layer or 1000), size)
    local self = setmetatable({ inst = inst }, Label)
    return self
end

function Label:SetText(t)
    self.inst:SetText(t)
end

function Label:SetAlign(mode)
    self.inst:SetAlign(mode or "left")
end

function Label:SetColor(r, g, b)
    self.inst:SetColor(r, g, b)
end

function Label:SetPosition(x, y)
    self.inst.x = x
    self.inst.y = y
end

function Label:SetAlpha(a)
    self.inst.alpha = a
end

--- Set the auto-wrap box width. Pass nil or 0 to disable wrapping.
function Label:SetWrapWidth(w)
    if (w and w > 0) then
        self.inst.auto_wrap = true
        self.inst.size = self.inst.size or {640, 0}
        self.inst.size[1] = w
    else
        self.inst.auto_wrap = false
    end
    self.inst:Rebuild()
end

function Label:Rebuild()
    self.inst:Rebuild()
end

-- Direct access to the underlying InstText instance (advanced; use with care)
function Label:Inst()
    return self.inst
end

function Label:Destroy()
    if (self.inst) then
        self.inst:Destroy()
        self.inst = nil
    end
end
Label.Remove = Label.Destroy

return Label
