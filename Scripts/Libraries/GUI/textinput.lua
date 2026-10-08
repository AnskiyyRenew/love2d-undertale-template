--[[
    GUI TextInput - editable single-line text field

    A window-style box (two stacked rects: thin border + black fill) with the
    text rendered via Typers.InstText (same Latin/CJK font split as Label) and
    a blinking cursor at the end of the text. Focus enables love.textinput so
    the OS sends character events; the scene routes textinput / keypressed to
    the focused field. Click inside to focus, click outside (or Escape) to blur.

    Layout: x,y is the top-left of the box; w,h is the outer size (including the
    border). Text is drawn left-aligned with a 6px left pad, vertically centred
    against the 27px Latin font height. The cursor is a 2px white bar.

    Usage:
      local ti = GUI.TextInput.New{
          x = 200, y = 100, w = 240, h = 32,
          placeholder = "Name", maxLen = 16,
          onSubmit = function(self) print(self:GetText()) end,
      }
      -- wire the scene callbacks:
      --   scene.mousepressed  -> (focus if click inside, else blur)
      --   scene.textinput(t)  -> ti:HandleTextInput(t)
      --   scene.keypressed(k) -> ti:HandleKeyPressed(k)
      --   scene.update(dt)    -> ti:Update(dt)   (blink)
      --   scene.clear         -> ti:Destroy()

    maxLen counts UTF-8 characters (not bytes), so a CJK glyph counts as 1.
    Backspace removes one UTF-8 codepoint (not one byte).

    Note: love.keyboard.setTextInput is enabled on Focus and disabled on Blur;
    this is what makes love.textinput fire at all. Key repeat is also toggled
    on focus so holding Backspace repeats (the rest of the engine uses edge
    detection, so enabling repeat does not cause double-fires elsewhere).
]]

local primitives = require((...):match("(.-)[^%.]+$") .. "primitives")
local Label      = require((...):match("(.-)[^%.]+$") .. "label")

local TextInput = {}
TextInput.__index = TextInput

local BORDER_COLOR = {1, 1, 1}  -- white border (unfocused)
local FOCUS_COLOR  = {1, 1, 0}  -- yellow border (focused)
local PLACEHOLDER_COLOR = {0.5, 0.5, 0.5}  -- dim placeholder text
local TEXT_PAD = 6              -- left padding inside the box
local CURSOR_W = 2
local FONT_H   = 27             -- determination_mono size; InstText default bondfont
local BLINK_PERIOD = 30         -- frames at 60fps -> ~0.5s on/off

-- Count UTF-8 codepoints (not bytes). Used for maxLen.
local function charCount(s)
    local count, i = 0, 1
    while (i <= #s) do
        local b = s:byte(i)
        if (b < 0x80) then i = i + 1
        elseif (b < 0xC0) then i = i + 1      -- invalid lead, skip
        elseif (b < 0xE0) then i = i + 2
        elseif (b < 0xF0) then i = i + 3
        else i = i + 4 end
        count = count + 1
    end
    return count
end

-- Remove the last UTF-8 codepoint from s.
local function dropLastChar(s)
    if (s == "") then return "" end
    local p = #s
    while (p > 1) do
        local b = s:byte(p)
        if (b >= 0x80 and b < 0xC0) then
            p = p - 1   -- continuation byte; keep walking back
        else
            break       -- start of a codepoint
        end
    end
    return s:sub(1, p - 1)
end

function TextInput.New(opts)
    opts = opts or {}
    local self = setmetatable({}, TextInput)
    self.x = opts.x or 0
    self.y = opts.y or 0
    self.w = opts.w or 200
    self.h = opts.h or 32
    self.thickness = opts.thickness or 3
    self.placeholder = opts.placeholder or ""
    self.maxLen = opts.maxLen or 16
    self.layer = opts.layer or 1000
    self.text = ""
    self.focused = false
    self._blink = 0
    self._cursorVisible = true
    self.onSubmit = opts.onSubmit
    self._destroyed = false
    -- Layering: the box (border + black fill) must be BELOW the text, and the
    -- cursor must be ABOVE the text. Layers sorts same-layer entries by _id
    -- (registration order), so a same-layer Label + box would let the box's
    -- black interior cover the text. Split them: box=layer, text=layer+1,
    -- cursor=layer+2. The caller-facing layer stays `self.layer`.
    local boxLayer    = self.layer
    local textLayer   = self.layer + 1
    local cursorLayer = self.layer + 2

    -- text label (left-aligned, vertically centred-ish against FONT_H)
    local textY = self.y + (self.h - FONT_H) / 2 + 2
    self._label = Label.New(self.placeholder, {self.x + TEXT_PAD, textY}, textLayer)
    self._label:SetAlign("left")
    if (self.placeholder ~= "") then
        self._label:SetColor(PLACEHOLDER_COLOR[1], PLACEHOLDER_COLOR[2], PLACEHOLDER_COLOR[3])
    end
    -- box draw entry (border + black fill) -- lowest, so the text draws on top
    self._boxEntry = Layers.add_external(function()
        if (not self._destroyed) then
            local borderColor = self.focused and FOCUS_COLOR or BORDER_COLOR
            primitives.drawWindow(self.x, self.y, self.w, self.h,
                self.thickness, borderColor, {0, 0, 0})
        end
    end, boxLayer)
    -- cursor draw entry (above the text)
    self._cursorEntry = Layers.add_external(function()
        if (not self._destroyed and self.focused and self._cursorVisible) then
            self:_drawCursor()
        end
    end, cursorLayer)
    return self
end

-- Cursor x = box x + pad + total text width (last letter.x + last letter.width).
-- For empty text, that's just box x + pad.
function TextInput:_cursorX()
    local inst = self._label:Inst()
    local letters = inst and inst.letters
    if (not letters or #letters == 0) then
        return self.x + TEXT_PAD
    end
    local last = letters[#letters]
    return self.x + TEXT_PAD + (last.x + last.width)
end

function TextInput:_drawCursor()
    local cx = self:_cursorX()
    local cy = self.y + 5
    local ch = self.h - 10
    primitives.drawRect(cx + 1, cy, CURSOR_W, ch, {1, 1, 1})
end

-- Refresh the displayed text (or placeholder when empty).
function TextInput:_refresh()
    if (self.text == "") then
        self._label:SetText(self.placeholder)
        self._label:SetColor(PLACEHOLDER_COLOR[1], PLACEHOLDER_COLOR[2], PLACEHOLDER_COLOR[3])
    else
        self._label:SetText(self.text)
        self._label:SetColor(1, 1, 1)
    end
end

--- Hit-test the box rect (including the border).
function TextInput:ContainsPoint(px, py)
    return px >= self.x and px <= self.x + self.w
       and py >= self.y and py <= self.y + self.h
end

--- Focus the field (enables OS text input + key repeat for backspace hold).
function TextInput:Focus()
    if (self.focused) then return end
    self.focused = true
    self._blink = 0
    self._cursorVisible = true
    SE.keyboard.setTextInput(true)
    SE.keyboard.setKeyRepeat(true)
end

--- Blur the field (disables OS text input + key repeat).
function TextInput:Blur()
    if (not self.focused) then return end
    self.focused = false
    SE.keyboard.setTextInput(false)
    SE.keyboard.setKeyRepeat(false)
end

function TextInput:SetFocused(v)
    if (v) then self:Focus() else self:Blur() end
end

function TextInput:SetText(t)
    self.text = tostring(t or "")
    -- truncate to maxLen characters (UTF-8 aware)
    if (self.maxLen > 0 and charCount(self.text) > self.maxLen) then
        local i, count = 1, 0
        while (i <= #self.text and count < self.maxLen) do
            local b = self.text:byte(i)
            if (b < 0x80) then i = i + 1
            elseif (b < 0xC0) then i = i + 1
            elseif (b < 0xE0) then i = i + 2
            elseif (b < 0xF0) then i = i + 3
            else i = i + 4 end
            count = count + 1
        end
        self.text = self.text:sub(1, i - 1)
    end
    self:_refresh()
end

function TextInput:GetText()
    return self.text
end

--- love.textinput handler. Append the character(s); single-line so newlines
--- are stripped. Respects maxLen (character count, UTF-8 aware).
function TextInput:HandleTextInput(text)
    if (not self.focused) then return end
    if (not text or text == "") then return end
    text = text:gsub("[\r\n]", "")
    if (text == "") then return end
    local new = self.text .. text
    -- truncate if over maxLen (character count)
    if (self.maxLen > 0 and charCount(new) > self.maxLen) then
        local i, count = 1, 0
        while (i <= #new and count < self.maxLen) do
            local b = new:byte(i)
            if (b < 0x80) then i = i + 1
            elseif (b < 0xC0) then i = i + 1
            elseif (b < 0xE0) then i = i + 2
            elseif (b < 0xF0) then i = i + 3
            else i = i + 4 end
            count = count + 1
        end
        new = new:sub(1, i - 1)
    end
    self.text = new
    self:_refresh()
end

--- love.keypressed handler. Returns true if the key was consumed.
---   backspace -> remove last UTF-8 codepoint
---   escape    -> blur
---   return/kpenter -> fire onSubmit
function TextInput:HandleKeyPressed(key)
    if (not self.focused) then return false end
    if (key == "backspace") then
        if (#self.text > 0) then
            self.text = dropLastChar(self.text)
            self:_refresh()
        end
        return true
    elseif (key == "escape") then
        self:Blur()
        return true
    elseif (key == "return" or key == "kpenter") then
        if (self.onSubmit) then self.onSubmit(self) end
        return true
    end
    return false
end

--- Advance the cursor blink. Call from scene.update.
function TextInput:Update(dt)
    if (not self.focused) then return end
    self._blink = self._blink + 1
    if (self._blink >= BLINK_PERIOD) then
        self._blink = 0
        self._cursorVisible = not self._cursorVisible
    end
end

function TextInput:SetPosition(x, y)
    self.x = x
    self.y = y
    self._label:SetPosition(x + TEXT_PAD, y + (self.h - FONT_H) / 2 + 2)
end

function TextInput:Destroy()
    if (self._destroyed) then return end
    self._destroyed = true
    if (self.focused) then
        SE.keyboard.setTextInput(false)
        SE.keyboard.setKeyRepeat(false)
    end
    if (self._label) then
        self._label:Destroy()
        self._label = nil
    end
    if (self._cursorEntry) then
        Layers.remove_external(self._cursorEntry)
        self._cursorEntry = nil
    end
    if (self._boxEntry) then
        Layers.remove_external(self._boxEntry)
        self._boxEntry = nil
    end
end
TextInput.Remove = TextInput.Destroy

return TextInput
