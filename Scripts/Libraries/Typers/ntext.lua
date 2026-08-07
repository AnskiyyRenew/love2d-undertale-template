--[[


How to use:

local text = Typers.NText("&* One^ thing...", {
    {
        font = "determination_mono.ttf",
        fontsize = 27,
        color = {1, 0, 0},
        alpha = 0.5,
        outline = {0, 1, 1, 1, 2},
        scale = 2,

        effect = {
            name = "shake",
            intensity = 3
        },
        voices = {}
    },
})

Every "&" in the text will be treated as a new operation.
The "opts" table is a list of options for each operation, in order. If there are more operations than options, the last option will be used for the remaining operations.
Every "^" in the text will be treated as an operation's end, and will use the default options until the next "&" is encountered.


Opts table can contain the following fields:
- font: The font to use for the text.
- size: The font size to use for the text.
- color: The color to use for the text, in the format {r, g, b}.
- alpha: The alpha value to use for the text, in the range [0, 1].
- outline: The outline color to use for the text, and the outline width will be set accordingly. in the format {r, g, b, a, width}.
- scale: The scale to use for the text.
- portrait: A talking portrait (head image that animates while typing). Can be:
  - A table: {files = {"a.png", "b.png", ...}, interval = 0.05, mode = "looponce"}
    (interval and mode are optional; mode defaults to "looponce").
  - A plain list of image paths: {"a.png", "b.png"}.
  - "remove" / "hide" to remove the portrait.

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

local function hasStarPrefix(sentence)
    return type(sentence) == "string" and sentence:sub(1, 1) == "*"
end

local reserved_option_keys = {
    font = true,
    size = true,
    color = true,
    alpha = true,
    outline = true,
    scale = true,
    autowrap = true,
    wait = true,
    effect = true,
    voices = true,
    skip = true,
    portrait = true
}

local function runOptionCallbacks(typer, opt)
    if type(opt) ~= "table" then
        return
    end

    for key, callback in pairs(opt) do
        local is_reserved_key = type(key) == "string" and reserved_option_keys[key]
        if type(callback) == "function" and (type(key) ~= "string" or not is_reserved_key) then
            local ok, err = pcall(callback, typer, opt)
            if not ok then
                print("[NText] option callback error: " .. tostring(err))
            end
        end
    end
end

local function normalizeStarPrefix(sentence)
    if type(sentence) ~= "string" then
        return sentence
    end

    if sentence:sub(1, 1) == "*" and sentence:sub(1, 2) ~= "* " then
        return "* " .. sentence:sub(2)
    end

    return sentence
end

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

function typers.TextureFont(path, width, height, amount, real_pattern)
    local font = {}

    return font
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

function typers.New(text, position, layer, size, opts, mode)
    local typer = {
        letters = {},
        letter_count = 0,
        max_letters = 1000
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
    typer.portrait = {
        image = nil,
        files = {},
        index = {},
        interval = 1 / 10,
        mode = "looponce",
        scale = {2, 2},
        active = false,
        offset_applied = false
    }
    -- Create the portrait sprite eagerly (placeholder px.png) so `portrait.image`
    -- is always valid and can be read/configured at any time. `active` tells
    -- whether a real portrait is currently being shown.
    typer.portrait.image = Sprites.CreateSprite("px.png", typer.layer)
    if (typer.portrait.image and typer.portrait.image.animation) then
        typer.portrait.image:MoveTo(typer.x, typer.y + 55)
        typer.portrait.image.visible = false
    end

    if (type(text) == "string") then
        text = {text}
    end
    typer.texts = text
    typer.opts = opts
    typer.time = 0
    typer.dint = 1 / 15
    typer.interval = 1 / 15
    typer.counter = 1
    typer.sentence_index = 1

    typer.pos = {
        offset = {0, 0},
        relative = {0, 0}
    }

    typer.color = (Global.GetVariable("MainColor") or {1, 1, 1})
    typer.outline = nil
    typer.alpha = 1
    typer.opt_index = 1
    typer.scale = 1
    typer.skip = {
        canskip = true,
        skipping = false,
        skipcount = 1,
        absolute = false
    }

    typer.voices = {"v_monster.wav"}
    typer.fontsize = 27
    typer.font = "determination_mono.ttf"
    typer.processing_special = false
    typer.has_star_prefix = false
    typer.auto_wrap = false

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
    typer.next_sentence = true

    -- Bubble
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

    function typer:Reset(pattern)
        for i = #typer.letters, 1, -1
        do
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
        typer.color = (Global.GetVariable("MainColor") or {1, 1, 1})
        typer.outline = nil
        typer.alpha = 1
        typer.scale = 1
        typer.has_star_prefix = false
        typer.skip.skipping = false
        typer.skip.absolute = false
    end

    function typer:MoveTo(x, y)
        typer.x = x
        typer.y = y
    end

    function typer:SetText(texts)
        if (type(texts) == "string") then
            texts = {texts}
        end
        typer:Reset()
        typer.texts = texts
        typer.sentence_index = 1
        typer.counter = 1
        typer.opt_index = 1
        typer.time = 0
    end

    function typer:UseBondFont(config)
        typer.bondfont = config
    end

    function typer:SetupPortrait()
        local portrait = typer.portrait
        if (not portrait or not portrait.image) then return end

        if (#portrait.files == 0) then
            -- No real portrait frames -> deactivate (do not destroy the sprite).
            portrait.active = false
            portrait.image.visible = false
            if (portrait.offset_applied) then
                typer.x = typer.x - 70
                portrait.offset_applied = false
            end
            return
        end

        if (not portrait.offset_applied) then
            typer.x = typer.x + 70
            portrait.offset_applied = true
        end

        portrait.active = true
        portrait.image:MoveTo(typer.x - 70, typer.y + 55)
        portrait.image:Scale(portrait.scale[1], portrait.scale[2])
        portrait.image:SetAnimation(portrait.files, portrait.interval, portrait.mode)
        portrait.image:Set(portrait.files[1]) -- show first frame immediately
        portrait.image.visible = true
    end

    function typer:RemovePortrait()
        local portrait = typer.portrait
        if (not portrait) then return end
        portrait.active = false
        portrait.files = {}
        if (portrait.image) then
            portrait.image.visible = false
        end
        if (portrait.offset_applied) then
            typer.x = typer.x - 70
            portrait.offset_applied = false
        end
    end

    function typer:Destroy()
        typer:Reset()
        removeBubble(typer.bubble)
        typer.bubble = nil
        if (typer.portrait and typer.portrait.image) then
            typer.portrait.image:Destroy()
            typer.portrait.image = nil
        end
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

        -- Cancel key (manual mode only)
        if (typer.mode ~= "none" and Keyboard.GetState("cancel") == 1 and typer.skip.canskip and typer.sentence_index <= #typer.texts) then
            typer.skip.skipping = true
        end

        if (typer.time >= typer.interval and typer.sentence_index <= #typer.texts) then
            typer.cantype = true
            typer.interval = typer.dint
            local raw_sentence = typer.texts[typer.sentence_index]
            local sentence = normalizeStarPrefix(raw_sentence)
            typer.texts[typer.sentence_index] = sentence
            typer.has_star_prefix = hasStarPrefix(sentence)
            local current_font = getFont(typer.font, typer.fontsize)
            local sentence_len = #sentence

            repeat
                local counter = typer.counter
                local byte, char_length, char = nil, nil, nil
                current_font = getFont(typer.font, typer.fontsize)

                while (counter <= sentence_len)
                do
                    local temp_char = sentence:sub(counter, counter)

                    if (temp_char == "&") then
                        counter = counter + 1
                        if (typer.opts and #typer.opts > 0) then
                            local opt = typer.opts[typer.opt_index]
                            if (opt) then
                                if (opt.font) then
                                    typer.font = opt.font
                                    current_font = getFont(typer.font, typer.fontsize)
                                end
                                if (opt.size) then
                                    typer.fontsize = opt.size
                                    current_font = getFont(typer.font, typer.fontsize)
                                end
                                if (opt.color) then typer.color = opt.color end
                                if (opt.alpha) then typer.alpha = opt.alpha end
                                if (opt.outline) then typer.outline = opt.outline end
                                if (opt.scale) then typer.scale = opt.scale end
                                if (opt.autowrap ~= nil) then typer.auto_wrap = opt.autowrap end
                                if (opt.wait) then
                                    typer.interval = opt.wait
                                    typer.cantype = false
                                end
                                if (opt.effect) then typer.effect = opt.effect end
                                if (opt.voices) then typer.voices = opt.voices end
                                if (opt.skip) then
                                    for k, v in pairs(opt.skip) do
                                        typer.skip[k] = v
                                    end
                                end
                                if (opt.portrait) then
                                    local p = opt.portrait
                                    if (p == "remove" or p == "hide" or p == "clear" or p == "none") then
                                        typer:RemovePortrait()
                                    else
                                        local files = (type(p) == "table") and (p.files or p.frames or p) or {p}
                                        if (type(files) == "string") then files = {files} end
                                        typer.portrait.files = files
                                        typer.portrait.interval = (type(p) == "table" and p.interval) or (1 / 30)
                                        typer.portrait.mode = (type(p) == "table" and p.mode) or "looponce"
                                        typer:SetupPortrait()
                                    end
                                end
                                runOptionCallbacks(typer, opt)
                            end
                        end
                        typer.opt_index = typer.opt_index + 1
                    elseif (temp_char == "^") then
                        counter = counter + 1
                        if (not typer.skip.skipping) then
                            typer.interval = 0.3
                            typer.cantype = false
                        end
                        typer.color = {1, 1, 1}
                        typer.alpha = 1
                        typer.outline = nil
                        typer.scale = 1
                        typer.effect = {}
                    elseif (temp_char == " " or temp_char == "\n" or temp_char == "\t") then
                        local is_star_padding_space = typer.has_star_prefix and counter == 2 and temp_char == " "
                        counter = counter + 1
                        if (temp_char == "\n") then
                            typer.pos.offset[1] = 0
                            typer.pos.offset[2] = typer.pos.offset[2] + current_font:getHeight()
                        elseif (temp_char == "\t") then
                            typer.pos.offset[1] = typer.pos.offset[1] + current_font:getWidth("    ")
                        else
                            if typer.auto_wrap and not is_star_padding_space then
                                local max_width = (typer.size and typer.size[1]) or 640
                                local next_word = ""
                                local next_index = counter
                                local wrap_indent = typer.has_star_prefix and current_font:getWidth("  ") or 0
                                while (next_index <= sentence_len) do
                                    local next_char = sentence:sub(next_index, next_index)
                                    if (next_char == " " or next_char == "\n" or next_char == "\t" or next_char == "&" or next_char == "^") then
                                        break
                                    end
                                    next_word = next_word .. next_char
                                    next_index = next_index + 1
                                end

                                if (max_width > 0 and next_word ~= "" and typer.pos.offset[1] + wrap_indent + current_font:getWidth(next_word) > max_width) then
                                    typer.pos.offset[1] = wrap_indent
                                    typer.pos.offset[2] = typer.pos.offset[2] + current_font:getHeight() * typer.scale
                                else
                                    typer.pos.offset[1] = typer.pos.offset[1] + current_font:getWidth(" ")
                                end
                            else
                                typer.pos.offset[1] = typer.pos.offset[1] + current_font:getWidth(" ")
                            end
                        end
                    else
                        break
                    end
                end

                if (counter <= sentence_len and typer.cantype) then
                    if (typer._onUpdate and type(typer._onUpdate) == "function") then typer._onUpdate() end
                    if (typer.voices and #typer.voices > 0 and not typer.skip.skipping) then
                        Audio.PlaySound("/Voices/" .. typer.voices[math.random(#typer.voices)])
                    end

                    local temp_char = sentence:sub(counter, counter)
                    if (temp_char == " " or temp_char == "\n" or temp_char == "\t") then
                        char_length = 1
                        char = temp_char
                    else
                        byte = sentence:sub(counter, counter)
                        if (typer.bondfont) then
                            current_font = typers.BondFont(byte,
                                typer.bondfont.engfont,
                                typer.bondfont.non_engfont,
                                typer.bondfont.engfunc,
                                typer.bondfont.non_engfunc
                            ) or typer.font
                        else
                            current_font = getFont(typer.font, typer.fontsize)
                        end
                        char_length = charlen(byte)
                        char = sentence:sub(counter, counter + char_length - 1)

                        if typer.auto_wrap then
                            local max_width = (typer.size and typer.size[1]) or 640
                            local wrap_indent = typer.has_star_prefix and current_font:getWidth("  ") or 0
                            local char_width = current_font:getWidth(char)
                            if max_width > 0 and typer.pos.offset[1] > wrap_indent and typer.pos.offset[1] + char_width > max_width then
                                typer.pos.offset[1] = wrap_indent
                                typer.pos.offset[2] = typer.pos.offset[2] + current_font:getHeight()
                            end
                        end
                    end

                    local text_obj = getTextObject(current_font, char)

                    local new_index = #typer.letters + 1
                    typer.letters[new_index] = {
                        text = char,
                        text_obj = text_obj,
                        font = current_font,
                        x = typer.pos.offset[1] + typer.pos.relative[1],
                        y = typer.pos.offset[2] + typer.pos.relative[2],
                        width = current_font:getWidth(char),
                        scale = typer.scale,

                        color = {typer.color[1], typer.color[2], typer.color[3]},
                        alpha = typer.alpha,
                        outline = typer.outline,
                        effect = typer.effect
                    }

                    typer.pos.offset[1] = typer.pos.offset[1] + typer.letters[new_index].width * (typer.scale or 1)
                    typer.pos.offset[2] = typer.pos.offset[2]
                    typer.letter_count = typer.letter_count + 1
                    -- Trigger the talking portrait animation once per typed character.
                    if (typer.portrait and typer.portrait.active and typer.portrait.image) then
                        local panim = typer.portrait.image.animation
                        if (panim and #panim.textures > 0) then
                            panim.time = 0
                            panim.frame = 1
                            panim.done = false
                        end
                    end
                    typer.counter = counter + char_length
                    typer.time = 0
                    if (not typer.skip.skipping) then
                        break
                    end
                else
                    typer.counter = counter
                    break
                end
            until (typer.counter > sentence_len)
            if (typer.counter > sentence_len) then
                typer.skip.skipping = false
            end
        end
        if (typer.sentence_index <= #typer.texts) then
            if (typer.counter > #typer.texts[typer.sentence_index]) then
                typer.skip.skipping = false
                local should_advance = false
                if (typer.mode == "none") then
                    if (typer.next_sentence) then
                        should_advance = true
                    end
                else
                    if (Keyboard.GetState("confirm") == 1) then
                        should_advance = true
                    end
                end
                if (should_advance) then
                    typer:Reset()
                    typer.sentence_index = typer.sentence_index + 1
                    typer.counter = 1
                    if (typer.sentence_index > #typer.texts) then
                        typer:Destroy()
                    end
                end
            end
        end
    end

    function typer:Draw()
        local letters = typer.letters
        for i = 1, #letters do
            local letter = letters[i]
            local font = getFont(typer.font, typer.fontsize)
            local effect = letter.effect

            local eff_x, eff_y = 0, 0

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
                        SE.graphics.draw(letter.text_obj, main_x + j, main_y + k, 0, letter.scale or 1, letter.scale or 1)
                    end
                end
            end
            SE.graphics.setColor(letter.color[1], letter.color[2], letter.color[3], letter.alpha)
            SE.graphics.draw(letter.text_obj, main_x, main_y, 0, letter.scale or 1, letter.scale or 1)
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