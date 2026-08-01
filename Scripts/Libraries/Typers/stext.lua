--[[


How to use:

local hp = 5
local text = Typers.SText(function (self)
    self:addText("你好")
    self:nextSentence()

    if (hp) then
        self:addText("现在血量有" .. hp .. "点。")
    else
        self:addText("我是盲人看不见血量。")
    end
end, {80, 60}, 0, {200, 100})


Builder API (available via `self` inside the builder function):

  self:addText(text)            Add text to be typed out character by character.
                                Applies the current style (font, color, etc.).
  self:setFont(name)            Switch font for subsequent addText calls.
  self:setWaitTime(time)        Pause typing for `time` seconds.
  self:setSpeed(interval)       Set typing interval (seconds per character).
  self:setColor(r, g, b)        Set text color (values 0-1 or 0-255, auto-detected).
  self:setColorHEX(hex)         Set text color via hex string (e.g. "ff0000").
  self:setOutline(r,g,b,a,w)    Set outline color (r,g,b), alpha (a), and width (w).
  self:addSkipText(text)        Add text that types instantly during skip mode.
  self:nextSentence()           Pause and wait for player confirm. On confirm,
                                all text is cleared and next sentence begins.


]]
local typers = {
    insts = {}
}

local function charlen(byte)
    local len = 0
    local byte = string.byte(byte)
    if (byte >= 0 and byte <= 127) then
        len = 1
    elseif (byte >= 192 and byte <= 223) then
        len = 2
    elseif (byte >= 224 and byte <= 239) then
        len = 3
    elseif (byte >= 240 and byte <= 247) then
        len = 4
    end
    return len
end

local fonts_cache = {}
local function getFont(name, size)
    local prepath = "Resources/Fonts/"
    local key = name .. "_" .. size
    if (fonts_cache[key]) then
        return fonts_cache[key]
    else
        local font = SE.graphics.newFont(prepath .. name, size, "mono")
        font:setFilter("nearest", "nearest")
        fonts_cache[key] = font
        return font
    end
end

local text_cache = {}
local function getTextCacheKey(font, char)
    local font_key = tostring(font):match("0x%x+") or tostring(font)
    return font_key .. "_" .. char
end

local function getTextObject(font, char)
    local key = getTextCacheKey(font, char)
    local cache_entry = text_cache[key]
    if (cache_entry) then
        cache_entry.refs = cache_entry.refs + 1
        return cache_entry.text_obj
    else
        local text_obj = SE.graphics.newText(font, char)
        text_cache[key] = {
            text_obj = text_obj,
            refs = 1
        }
        return text_obj
    end
end

local function releaseTextObject(font, char)
    local key = getTextCacheKey(font, char)
    local cache_entry = text_cache[key]
    if not cache_entry then return end

    cache_entry.refs = cache_entry.refs - 1
    if (cache_entry.refs <= 0) then
        if (cache_entry.text_obj and cache_entry.text_obj.release) then
            cache_entry.text_obj:release()
        end
        text_cache[key] = nil
    end
end

-- Helper: parse hex color string to {r,g,b} in 0-1 range
local function hexToColor(hex)
    if (type(hex) ~= "string") then return nil end
    local h = hex:gsub("#", "")
    if (#h >= 6) then
        local r = tonumber(h:sub(1, 2), 16) / 255
        local g = tonumber(h:sub(3, 4), 16) / 255
        local b = tonumber(h:sub(5, 6), 16) / 255
        if (r and g and b) then
            return {r, g, b}
        end
    end
    return nil
end

-- Helper: normalize color values (auto-detect 0-255 vs 0-1)
local function normalizeColor(r, g, b)
    if (r > 1 or g > 1 or b > 1) then
        return {r / 255, g / 255, b / 255}
    end
    return {r, g, b}
end

-- Helper: split a string into individual characters (handles multi-byte UTF-8)
local function splitChars(text)
    local chars = {}
    local i = 1
    while (i <= #text) do
        local byte = text:sub(i, i)
        local len = charlen(byte)
        table.insert(chars, text:sub(i, i + len - 1))
        i = i + len
    end
    return chars
end

function typers.BondFont(byte, engfont, non_engfont, engfunc, non_engfunc)
    if (charlen(byte) == 1) then -- English character.
        engfunc()
        return getFont(engfont.font, engfont.size)
    else
        non_engfunc()
        return getFont(non_engfont.font, non_engfont.size)
    end
end

function typers.CreateBondFont(engfont, non_engfont, engfunc, non_engfunc)
    return {
        engfont = engfont,
        non_engfont = non_engfont,
        engfunc = engfunc,
        non_engfunc = non_engfunc
    }
end

-- ══════════════════════════════════════
-- Bubble helpers
-- ══════════════════════════════════════

local function createBubble(x, y, w, h, layer)
    local bubble = {}
    local offsetX, offsetY = -10, 10
    local bubble_layer = layer - 0.0001

    bubble.main_rect_h = Sprites.CreateSprite("px.png", bubble_layer)
    bubble.main_rect_h:MoveTo(x + offsetX, y + offsetY)
    bubble.main_rect_h:Scale(w, h - 40)
    bubble.main_rect_h.alpha = 0
    bubble.main_rect_h:Pivot(0, 0)

    bubble.main_rect_v = Sprites.CreateSprite("px.png", bubble_layer)
    bubble.main_rect_v:MoveTo(
        bubble.main_rect_h.x + bubble.main_rect_h.xscale / 2,
        bubble.main_rect_h.y + bubble.main_rect_h.yscale / 2
    )
    bubble.main_rect_v:Scale(w - 40, h)
    bubble.main_rect_v.alpha = 0

    bubble.tail = Sprites.CreateSprite("Bubble/spr_bubbletail.png", bubble_layer)
    bubble.tail:MoveTo(x + offsetX, y)
    bubble.tail.alpha = 0

    bubble.corner_ul = Sprites.CreateSprite("Bubble/spr_bubblecorner.png", bubble_layer)
    bubble.corner_ul:MoveTo(bubble.main_rect_h.x + 10, bubble.main_rect_h.y - 10)
    bubble.corner_ul.alpha = 0

    bubble.corner_ur = Sprites.CreateSprite("Bubble/spr_bubblecorner.png", bubble_layer)
    bubble.corner_ur:MoveTo(bubble.main_rect_h.x + bubble.main_rect_h.xscale - 10, bubble.main_rect_h.y - 10)
    bubble.corner_ur.xscale = -1
    bubble.corner_ur.alpha = 0

    bubble.corner_dl = Sprites.CreateSprite("Bubble/spr_bubblecorner.png", bubble_layer)
    bubble.corner_dl:MoveTo(bubble.main_rect_h.x + 10, bubble.main_rect_h.y + bubble.main_rect_h.yscale + 10)
    bubble.corner_dl.yscale = -1
    bubble.corner_dl.alpha = 0

    bubble.corner_dr = Sprites.CreateSprite("Bubble/spr_bubblecorner.png", bubble_layer)
    bubble.corner_dr:MoveTo(bubble.main_rect_h.x + bubble.main_rect_h.xscale - 10, bubble.main_rect_h.y + bubble.main_rect_h.yscale + 10)
    bubble.corner_dr.xscale = -1
    bubble.corner_dr.yscale = -1
    bubble.corner_dr.alpha = 0

    return bubble
end

local function showBubble(bubble, direction, position)
    if (not bubble) then return end
    bubble.main_rect_h.alpha = 1
    bubble.main_rect_v.alpha = 1
    bubble.tail.alpha = 1
    bubble.corner_ul.alpha = 1
    bubble.corner_ur.alpha = 1
    bubble.corner_dl.alpha = 1
    bubble.corner_dr.alpha = 1

    local tail = bubble.tail
    local dir = direction:lower()
    if (dir == "left") then
        tail:MoveTo(bubble.main_rect_h.x, bubble.main_rect_h.y + (position * bubble.main_rect_h.yscale))
        tail.rotation = 0
    elseif (dir == "right") then
        tail.rotation = 180
        tail:MoveTo(bubble.main_rect_h.x + bubble.main_rect_h.xscale, bubble.main_rect_h.y + (position * bubble.main_rect_h.yscale))
    elseif (dir == "up") then
        tail.rotation = 90
        tail:MoveTo(bubble.main_rect_h.x + (position * bubble.main_rect_h.xscale), bubble.main_rect_h.y - 20)
    elseif (dir == "down") then
        tail.rotation = -90
        tail:MoveTo(bubble.main_rect_h.x + (position * bubble.main_rect_h.xscale), bubble.main_rect_h.y + bubble.main_rect_h.yscale + 20)
    end
end

local function hideBubble(bubble)
    if (not bubble) then return end
    bubble.main_rect_h.alpha = 0
    bubble.main_rect_v.alpha = 0
    bubble.tail.alpha = 0
    bubble.corner_ul.alpha = 0
    bubble.corner_ur.alpha = 0
    bubble.corner_dl.alpha = 0
    bubble.corner_dr.alpha = 0
end

local function removeBubble(bubble)
    if (not bubble) then return end
    bubble.main_rect_h:Remove()
    bubble.main_rect_v:Remove()
    bubble.tail:Remove()
    bubble.corner_ul:Remove()
    bubble.corner_ur:Remove()
    bubble.corner_dl:Remove()
    bubble.corner_dr:Remove()
end

function typers.New(fn, position, layer, size, mode)
    local typer = {
        letters = {},
        letter_count = 0,
        max_letters = 1000,
        queue = {},      -- pre-built queue of letters and break markers
        queue_index = 1,  -- current position in queue
    }

    -- Metatable to intercept `.layer` writes and automatically mark Layers as dirty
    setmetatable(typer, {
        __index = function(t, k)
            if k == "layer" then
                return rawget(t, "_layer_value")
            end
            return rawget(t, k)
        end,
        __newindex = function(t, k, v)
            if k == "layer" then
                rawset(t, "_layer_value", v)
                Layers.mark_dirty()
            else
                rawset(t, k, v)
            end
        end
    })

    typer.type = "objects"
    typer.cantype = true
    typer._layer_value = (layer or 0)
    typer.x = (position[1] or 320)
    typer.y = (position[2] or 240)
    typer.size = (size or {640, 0})

    typer.time = 0
    typer.dint = 1 / 15
    typer.interval = 1 / 15
    typer.waiting_for_confirm = false

    typer.pos = {
        offset = {0, 0},
        relative = {0, 0}
    }

    typer.color = {1, 1, 1}
    typer.outline = nil
    typer.alpha = 1
    typer.scale = 1
    typer.fontsize = 27
    typer.font = "determination_mono.ttf"
    typer.auto_wrap = false

    typer.skip = {
        canskip = true,
        skipping = false,
        skipcount = 1,
        absolute = false
    }

    typer.voices = {"v_monster.wav"}
    typer.bondfont = {
        engfont = {font = "determination_mono.ttf", size = 27},
        non_engfont = {font = "simsun.ttc", size = 13},
        engfunc = function()
            typer.scale = 1
            typer.pos.offset[1] = typer.pos.offset[1] + 0
            typer.pos.relative[1] = 4
            typer.pos.relative[2] = 0
        end,
        non_engfunc = function()
            typer.scale = 2
            typer.pos.offset[1] = typer.pos.offset[1] + 4
            typer.pos.relative[1] = 4
            typer.pos.relative[2] = 4
        end
    }

    typer.mode = mode or "manual"
    typer.bubble = nil

    function typer:ShowBubble(dir, pos)
        if (not typer.bubble) then
            local bw = (typer.size and typer.size[1]) or 640
            local bh = (typer.size and typer.size[2]) or 100
            typer.bubble = createBubble(typer.x, typer.y, bw, bh, typer.layer)
        end
        showBubble(typer.bubble, dir or "left", pos or 0.5)
    end

    function typer:HideBubble()
        hideBubble(typer.bubble)
    end

    -- Current style state for the builder
    local style = {
        font = "determination_mono.ttf",
        fontsize = 27,
        color = {1, 1, 1},
        alpha = 1,
        outline = nil,
        scale = 1,
        effect = {},
    }

    -- Builder API
    local builder = {}

    function builder:addText(text)
        local chars = splitChars(text)
        for _, char in ipairs(chars) do
            table.insert(typer.queue, {
                type = "letter",
                char = char,
                font = style.font,
                fontsize = style.fontsize,
                color = {style.color[1], style.color[2], style.color[3]},
                alpha = style.alpha,
                outline = style.outline,
                scale = style.scale,
                effect = style.effect,
                skip = false,
            })
        end
    end

    function builder:addSkipText(text)
        local chars = splitChars(text)
        for _, char in ipairs(chars) do
            table.insert(typer.queue, {
                type = "letter",
                char = char,
                font = style.font,
                fontsize = style.fontsize,
                color = {style.color[1], style.color[2], style.color[3]},
                alpha = style.alpha,
                outline = style.outline,
                scale = style.scale,
                effect = style.effect,
                skip = true,
            })
        end
    end

    function builder:setFont(name)
        style.font = name
    end

    function builder:setWaitTime(time)
        table.insert(typer.queue, {
            type = "wait",
            time = time,
        })
    end

    function builder:setSpeed(interval)
        style.speed = interval
        table.insert(typer.queue, {
            type = "speed",
            interval = interval,
        })
    end

    function builder:setEffect(name, intensity)
        style.effect = {name = name, intensity = intensity or 1}
    end

    function builder:setColor(r, g, b)
        style.color = normalizeColor(r, g, b)
    end

    function builder:setColorHEX(hex)
        local c = hexToColor(hex)
        if (c) then
            style.color = c
        end
    end

    function builder:setOutline(r, g, b, a, w)
        style.outline = {r, g, b, a, w}
    end

    function builder:nextSentence()
        table.insert(typer.queue, {type = "break"})
        -- Reset style state so next sentence starts clean
        style.effect = {}
        style.color = {1, 1, 1}
        style.outline = nil
        style.scale = 1
    end

    function builder:showBubble(visible, dir, pos)
        if (visible) then
            typer:ShowBubble(dir, pos)
        else
            typer:HideBubble()
        end
    end

    -- Run the builder function to populate the queue
    local ok, err = pcall(fn, builder)
    if (not ok) then
        print("[SText] builder error: " .. tostring(err))
    end

    -- Initialize current font from the final style
    local current_font = getFont(typer.font, typer.fontsize)

    function typer:Reset()
        for i = #typer.letters, 1, -1 do
            local letter = typer.letters[i]
            table.remove(typer.letters, i)

            if (letter and letter.text_obj and letter.font) then
                releaseTextObject(letter.font, letter.text)
            end
            letter = nil
        end

        typer.letters = {}
        typer.letter_count = 0
        typer.max_letters = 1000

        typer.pos = {
            offset = {0, 0},
            relative = {0, 0}
        }
        typer.effect = {}

        typer.waiting_for_confirm = false
    end

    function typer:MoveTo(x, y)
        typer.x = x
        typer.y = y
    end

    function typer:UseBondFont(config)
        typer.bondfont = config
    end

    function typer:Destroy()
        typer:Reset()
        removeBubble(typer.bubble)
        typer.bubble = nil
        if (typer._onComplete and type(typer._onComplete) == "function") then
            typer._onComplete()
        end
        Layers.remove(typer)

        for i = #typers.insts, 1, -1 do
            if (typers.insts[i] == typer) then
                table.remove(typers.insts, i)
                break
            end
        end
    end

    function typer:Remove()
        typer:Destroy()
    end

    function typer:Update(dt)
        typer.time = typer.time + dt

        -- Handle sentence break: wait for confirm key
        if (typer.waiting_for_confirm) then
            local should_advance = false
            if (typer.mode == "none") then
                should_advance = true
            elseif (Keyboard.GetState("confirm") == 1) then
                should_advance = true
            end
            if (should_advance) then
                -- Clear ALL letters and reset position for next sentence
                for i = #typer.letters, 1, -1 do
                    local letter = typer.letters[i]
                    table.remove(typer.letters, i)
                    if (letter and letter.text_obj and letter.font) then
                        releaseTextObject(letter.font, letter.text)
                    end
                end
                typer.letters = {}
                typer.letter_count = 0
                typer.pos = {
                    offset = {0, 0},
                    relative = {0, 0}
                }

                typer.waiting_for_confirm = false
                typer.interval = typer.dint
                typer.time = 0

                -- If no more items in queue, auto-Destroy
                if (typer.queue_index > #typer.queue) then
                    typer:Destroy()
                end
            end
            return
        end

        -- Cancel key (manual mode only)
        if (typer.mode ~= "none" and Keyboard.GetState("cancel") == 1 and typer.skip.canskip) then
            typer.skip.skipping = true
        end

        -- Process queue items (repeat loop handles skip-mode burst typing)
        if (typer.time >= typer.interval and typer.queue_index <= #typer.queue) then
            repeat
                typer.interval = typer.dint
                local item = typer.queue[typer.queue_index]

                if (item.type == "letter") then
                    local char = item.char

                    -- Whitespace: advance position instantly, no letter created, no interval consumed
                    if (char == " " or char == "\n" or char == "\t") then
                        local space_font = getFont(item.font, item.fontsize)
                        if (char == "\n") then
                            typer.pos.offset[1] = 0
                            typer.pos.offset[2] = typer.pos.offset[2] + space_font:getHeight()
                        elseif (char == "\t") then
                            typer.pos.offset[1] = typer.pos.offset[1] + space_font:getWidth("    ")
                        else
                            typer.pos.offset[1] = typer.pos.offset[1] + space_font:getWidth(" ")
                        end
                        typer.queue_index = typer.queue_index + 1
                        -- Keep typer.time unchanged so next item processes instantly

                    else
                        -- Visible character: play voice, create letter, consume interval
                        if (typer.voices and #typer.voices > 0 and not typer.skip.skipping) then
                            Audio.PlaySound("/Voices/" .. typer.voices[math.random(#typer.voices)])
                        end

                        -- Get font for this letter
                        local letter_font = getFont(item.font, item.fontsize)
                        if (typer.bondfont) then
                            local byte = char:sub(1, 1)
                            letter_font = typers.BondFont(byte,
                                typer.bondfont.engfont,
                                typer.bondfont.non_engfont,
                                typer.bondfont.engfunc,
                                typer.bondfont.non_engfunc
                            ) or letter_font
                        end

                        -- Compute position
                        local new_index = #typer.letters + 1
                        typer.letters[new_index] = {
                            text = char,
                            text_obj = getTextObject(letter_font, char),
                            font = letter_font,
                            x = typer.pos.offset[1] + typer.pos.relative[1],
                            y = typer.pos.offset[2] + typer.pos.relative[2],
                            width = letter_font:getWidth(char),
                            scale = typer.scale,

                            color = {item.color[1], item.color[2], item.color[3]},
                            alpha = item.alpha,
                            outline = item.outline,
                            effect = item.effect,
                        }

                        -- Advance position
                        typer.pos.offset[1] = typer.pos.offset[1] + typer.letters[new_index].width * (typer.scale or 1)
                        typer.letter_count = typer.letter_count + 1

                        typer.queue_index = typer.queue_index + 1
                        typer.time = 0
                    end

                elseif (item.type == "wait") then
                    if (typer.skip.skipping) then
                        -- Skip wait during skip mode
                        typer.queue_index = typer.queue_index + 1
                    else
                        typer.interval = item.time
                        typer.cantype = false
                        typer.queue_index = typer.queue_index + 1
                        typer.time = 0
                        break  -- pause here even in skip-repeat
                    end

                elseif (item.type == "speed") then
                    typer.dint = item.interval
                    typer.interval = item.interval
                    typer.queue_index = typer.queue_index + 1
                    typer.time = 0

                elseif (item.type == "break") then
                    typer.queue_index = typer.queue_index + 1
                    typer.waiting_for_confirm = true
                    typer.time = 0
                    break  -- stop repeat, wait for confirm
                end

            until (not typer.skip.skipping or typer.queue_index > #typer.queue or typer.waiting_for_confirm)
        end

        -- End of queue check
        if (typer.queue_index > #typer.queue and not typer.waiting_for_confirm) then
            typer.waiting_for_confirm = true
        end
    end

    function typer:Draw()
        local letters = typer.letters
        for i = 1, #letters do
            local letter = letters[i]
            local font = getFont(typer.font, typer.fontsize)
            local effect = letter.effect

            local eff_x, eff_y = 0, 0
            local draw_scale = letter.scale or typer.scale or 1

            if (effect.name == "shake") then
                local int = (effect.intensity or 1)
                eff_x = math.random(-int, int)
                eff_y = math.random(-int, int)
            elseif (effect.name == "rotate") then
                local int = (effect.intensity or 1)
            end

            local main_x = typer.x + letter.x + eff_x
            local main_y = typer.y + letter.y + eff_y
            SE.graphics.setFont(font)
            if (letter.outline) then
                SE.graphics.setColor(letter.outline[1], letter.outline[2], letter.outline[3], letter.outline[4])
                SE.graphics.setLineWidth(letter.outline[5])
                for j = -1, 1, 2 do
                    for k = -1, 1, 2 do
                        SE.graphics.draw(letter.text_obj, main_x + j, main_y + k, 0, draw_scale, draw_scale)
                    end
                end
            end
            SE.graphics.setColor(letter.color[1], letter.color[2], letter.color[3], letter.alpha)
            SE.graphics.draw(letter.text_obj, main_x, main_y, 0, draw_scale, draw_scale)
        end
    end

    Layers.add(typer)
    table.insert(typers.insts, typer)
    return typer
end

function typers.Update(dt)
    local insts = typers.insts
    for i = #insts, 1, -1 do
        local typer = insts[i]
        if (typer.Update) then
            typer:Update(dt)
        end
    end
end

function typers.ClearCache()
    for _, cache_entry in pairs(text_cache) do
        if (cache_entry and cache_entry.text_obj and cache_entry.text_obj.release) then
            cache_entry.text_obj:release()
        end
    end
    text_cache = {}
    fonts_cache = {}
end

return typers
