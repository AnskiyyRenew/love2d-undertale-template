--[[


How to use:

local text = Typers.InstText.New("Hello 你好\nWorld 世界", {320, 60}, 0)
text:SetAlign("center")

Draws the full text instantly (no typing animation).
Automatically splits English/CJK characters and renders them
with the appropriate font, scale, and positioning.

Methods:
  :SetText(new_text)   -- Dynamically change the displayed text
  :SetAlign(mode)      -- Set alignment: "left" (default), "center", "right"
  :UseBondFont(config) -- Swap bondfont config and rebuild


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

--- Release a text object AND evict it from cache so a stale released object
--- is never returned by getTextObject on re-creation.
local function releaseAndEvict(text_obj)
    if (not text_obj or not text_obj.release) then return end

    -- Scan cache for any entry holding this text_obj and remove it
    for key, entry in pairs(text_cache) do
        if (entry.text_obj == text_obj) then
            text_cache[key] = nil
            break
        end
    end

    text_obj:release()
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

function typers.New(text, position, layer, size)
    local typer = {}

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

    if (type(text) == "table") then
        text = text[1]
    end
    typer.text = tostring(text or "")
    typer.x = (position and position[1]) or 320
    typer.y = (position and position[2]) or 240
    typer._layer_value = (layer or 0)
    typer.size = (size or {640, 0})

    -- Bondfont config (default, matching ntext/stext)
    typer.bondfont = {
        engfont = {font = "determination_mono.ttf", size = 27},
        non_engfont = {font = "simsun.ttc", size = 13},
        engfunc = function()
            typer.scale = 1
        end,
        non_engfunc = function()
            typer.scale = 2
        end
    }

    typer.color = {1, 1, 1}
    typer.alpha = 1
    typer.scale = 1
    typer.outline = nil
    typer.align = "left"
    typer.effect = {}

    -- Helper: rebuild letter data from typer.text
    local function rebuildLetters()
        -- Release old text objects (evicts from cache to prevent reuse-after-free)
        if (typer.letters) then
            for _, letter in ipairs(typer.letters) do
                if (letter.text_obj) then
                    releaseAndEvict(letter.text_obj)
                end
            end
        end

        typer.letters = {}
        typer.lines = {}  -- {start, last, width}
        local offset_x = 0
        local offset_y = 0
        local relative_x = 0
        local relative_y = 0
        local line_start = 1
        local i = 1
        while (i <= #typer.text) do
            local byte = typer.text:sub(i, i)
            local len = charlen(byte)
            local char = typer.text:sub(i, i + len - 1)

            if (char == "\n") then
                -- End current line: compute its total width
                local line_width = offset_x
                for j = line_start, #typer.letters do
                    typer.letters[j].line_width = line_width
                end
                line_start = #typer.letters + 1
                offset_x = 0
                offset_y = offset_y + getFont(typer.bondfont.engfont.font, typer.bondfont.engfont.size):getHeight()
                i = i + 1
            elseif (len == 1) then
                -- English character
                if (typer.bondfont) then
                    typer.bondfont.engfunc()
                end
                local font = getFont(typer.bondfont.engfont.font, typer.bondfont.engfont.size)
                relative_y = 0
                local w = font:getWidth(char) * typer.scale
                table.insert(typer.letters, {
                    char = char,
                    font = font,
                    text_obj = getTextObject(font, char),
                    x = offset_x + relative_x,
                    y = offset_y + relative_y,
                    width = w,
                    scale = typer.scale,
                    color = {typer.color[1], typer.color[2], typer.color[3]},
                    alpha = typer.alpha,
                    outline = typer.outline,
                    effect = typer.effect,
                    line_width = 0,  -- filled after line ends
                })
                offset_x = offset_x + w
                i = i + 1
            else
                -- Non-English character (CJK, etc.)
                if (typer.bondfont) then
                    typer.bondfont.non_engfunc()
                end
                local font = getFont(typer.bondfont.non_engfont.font, typer.bondfont.non_engfont.size)
                -- Extra CJK X spacing (matches ntext non_engfunc's offset[1] += 4)
                offset_x = offset_x + 4
                relative_x = (i == 1 and 0 or 4)
                relative_y = 4  -- +4 y-offset for CJK
                local w = font:getWidth(char) * typer.scale
                table.insert(typer.letters, {
                    char = char,
                    font = font,
                    text_obj = getTextObject(font, char),
                    x = offset_x + relative_x,
                    y = offset_y + relative_y,
                    width = w,
                    scale = typer.scale,
                    color = {typer.color[1], typer.color[2], typer.color[3]},
                    alpha = typer.alpha,
                    outline = typer.outline,
                    effect = typer.effect,
                    line_width = 0,  -- filled after line ends
                })
                offset_x = offset_x + w
                i = i + len
            end
        end
        -- Final line: set line_width for remaining letters
        if (line_start <= #typer.letters) then
            local line_width = offset_x
            for j = line_start, #typer.letters do
                typer.letters[j].line_width = line_width
            end
        end
    end

    function typer:UseBondFont(config)
        typer.bondfont = config
        rebuildLetters()
    end

    rebuildLetters()

    -- Compute alignment offset for a line given its total width
    local function alignOffset(line_width)
        if (typer.align == "center") then
            return -line_width / 2
        elseif (typer.align == "right") then
            return -line_width
        end
        return 0
    end

    -- Register the instant draw function
    typer.draw_func = function()
        for _, letter in ipairs(typer.letters) do
            local eff_x, eff_y = 0, 0

            if (letter.effect and letter.effect.name == "shake") then
                local int = (letter.effect.intensity or 1)
                eff_x = math.random(-int, int)
                eff_y = math.random(-int, int)
            end

            local align_x = alignOffset(letter.line_width)
            local main_x = typer.x + letter.x + align_x + eff_x
            local main_y = typer.y + letter.y + eff_y

            SE.graphics.setFont(letter.font)
            if (letter.outline) then
                SE.graphics.setColor(letter.outline[1], letter.outline[2], letter.outline[3], letter.outline[4])
                SE.graphics.setLineWidth(letter.outline[5])
                for j = -1, 1, 2 do
                    for k = -1, 1, 2 do
                        SE.graphics.draw(letter.text_obj, main_x + j, main_y + k, 0, letter.scale or 1, letter.scale or 1)
                    end
                end
            end
            SE.graphics.setColor(typer.color[1], typer.color[2], typer.color[3], typer.alpha)
            SE.graphics.draw(letter.text_obj, main_x, main_y, 0, letter.scale or 1, letter.scale or 1)
        end
    end

    typer.external_entry = Layers.add_external(typer.draw_func, typer.layer)

    function typer:SetAlign(mode)
        typer.align = mode or "left"
    end

    function typer:SetText(new_text)
        if (type(new_text) == "table") then
            new_text = new_text[1]
        end
        typer.text = tostring(new_text or "")
        rebuildLetters()
    end

    function typer:Rebuild()
        rebuildLetters()
    end

    function typer:SetColor(r, g, b)
        typer.color = {r, g, b}
    end

    function typer:Destroy()
        if (typer.external_entry) then
            Layers.remove_external(typer.external_entry)
            typer.external_entry = nil
        end
        if (typer.letters) then
            for _, letter in ipairs(typer.letters) do
                if (letter.text_obj) then
                    releaseAndEvict(letter.text_obj)
                end
            end
        end
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

    table.insert(typers.insts, typer)
    return typer
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
