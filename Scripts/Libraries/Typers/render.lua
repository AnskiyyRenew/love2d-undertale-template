--[[
Stencil (mask) and shader support shared by the four typer modules. Required
directly by each typer module, not through init.lua (that would be circular).
Shaders need a baked canvas because glyph UVs are atlas-relative, not 0..1;
masks and shaders combine: shader first, then the canvas goes through the mask.
]]
local render = {}

local MASKS_WARNING = "[WARNING] typer:SetStencils - invalid mask object"
local SHADERS_WARNING = "[WARNING] typer:SetShaders - invalid shader object"

-- Canvases are rounded up to this many pixels, so a growing text reuses one
-- canvas instead of allocating per frame.
local CANVAS_STEP = 32
-- Distinct canvas sizes kept alive before the oldest entry is released.
local CANVAS_CACHE_MAX = 12

local canvas_cache = {}
local canvas_order = {}

local function new_canvas(w, h)
    local ok, canvas = pcall(SE.graphics.newCanvas, w, h)

    if (not ok or not canvas) then
        print("[WARNING] Typers - could not create the shader canvas: " .. tostring(canvas))
        return nil
    end

    canvas:setFilter("nearest", "nearest")
    return canvas
end

local function release_entry(entry)
    if (not entry) then return end
    if (entry.a) then entry.a:release() end
    if (entry.b) then entry.b:release() end
end

--- Two canvases of at least w x h, used as the ping-pong pair of a shader
--- chain. Returns nil when no canvas could be created.
local function acquire_canvases(w, h)
    local bw = math.max(CANVAS_STEP, math.ceil(w / CANVAS_STEP) * CANVAS_STEP)
    local bh = math.max(CANVAS_STEP, math.ceil(h / CANVAS_STEP) * CANVAS_STEP)
    local key = bw .. "x" .. bh

    local entry = canvas_cache[key]
    if (not entry) then
        local a = new_canvas(bw, bh)
        local b = a and new_canvas(bw, bh)
        if (not b) then
            release_entry({a = a})
            return nil
        end

        entry = {a = a, b = b}
        canvas_cache[key] = entry
        table.insert(canvas_order, key)

        while (#canvas_order > CANVAS_CACHE_MAX) do
            local oldest = table.remove(canvas_order, 1)
            local old = canvas_cache[oldest]
            canvas_cache[oldest] = nil
            release_entry(old)
        end
    end

    return entry
end

local function mask_list(value)
    if (value == nil) then return {} end

    if (type(value) ~= "table") then
        print(MASKS_WARNING)
        return {}
    end

    -- A single mask works too: {shape = "rect", ...}. A list never has `shape`.
    if (value.shape) then value = {value} end

    local list = {}
    for _, mask in ipairs(value) do
        if (type(mask) == "table" and mask.shape) then
            table.insert(list, mask)
        elseif (mask) then
            print(MASKS_WARNING)
        end
    end
    return list
end

local function shader_list(value)
    if (value == nil) then return {} end

    if (type(value) ~= "table") then
        value = {value}
    end

    local list = {}
    for _, shader in ipairs(value) do
        if (type(shader) == "userdata") then
            table.insert(list, shader)
        elseif (shader) then
            print(SHADERS_WARNING)
        end
    end
    return list
end

--- Attach the mask / shader API to a typer instance and create its two lists.
--- Called once per instance by every module's New().
function render.install(typer)
    typer.stencils = {}
    typer.shaders = {}

    function typer:SetStencils(stencils)
        self.stencils = mask_list(stencils)
        return self
    end

    function typer:GetStencils()
        return self.stencils
    end

    function typer:ClearStencils()
        self.stencils = {}
        return self
    end

    function typer:SetShaders(shaders)
        self.shaders = shader_list(shaders)
        return self
    end

    function typer:GetShaders()
        return self.shaders
    end

    function typer:ClearShaders()
        self.shaders = {}
        return self
    end

    function typer:AddShader(shader)
        if (type(shader) ~= "userdata") then
            print(SHADERS_WARNING)
            return self
        end
        table.insert(self.shaders, shader)
        return self
    end

    function typer:RemoveShader(shader)
        for i = #self.shaders, 1, -1 do
            if (self.shaders[i] == shader) then
                table.remove(self.shaders, i)
                return true
            end
        end
        return false
    end
end

--- Bounding box of `letters` in local space (before `typer.x` / `typer.y`), as
--- x, y, w, h; `0, 0, 0, 0` when there is nothing to measure. Includes the
--- outline width and shake amplitude, so one bake covers every drawn copy.
---
---@param letters table  The instance's letter list.
---@param opts table|nil  Optional `align`, `scale_of` and `pad` hooks.
function render.letter_bounds(letters, opts)
    opts = opts or {}
    local align = opts.align
    local scale_of = opts.scale_of
    local pad = opts.pad or 0

    local min_x, min_y, max_x, max_y = nil, nil, nil, nil

    for i = 1, #letters do
        local letter = letters[i]
        local text_obj = letter.text_obj

        if (text_obj and text_obj.getDimensions) then
            local w, h = text_obj:getDimensions()

            local scale = 1
            if (scale_of) then
                scale = scale_of(letter) or 1
            else
                scale = letter.scale or 1
            end

            local extra = pad
            if (letter.outline) then
                extra = extra + (letter.outline[5] or 1)
            end
            if (letter.effect and letter.effect.name == "shake") then
                extra = extra + (letter.effect.intensity or 1)
            end

            local dx = 0
            if (align) then
                dx = align(letter.line_width or 0)
            end

            local x = (letter.x or 0) + dx
            local y = (letter.y or 0)
            local x0, y0 = x - extra, y - extra
            local x1, y1 = x + w * scale + extra, y + h * scale + extra

            if (min_x == nil or x0 < min_x) then min_x = x0 end
            if (min_y == nil or y0 < min_y) then min_y = y0 end
            if (max_x == nil or x1 > max_x) then max_x = x1 end
            if (max_y == nil or y1 > max_y) then max_y = y1 end
        end
    end

    if (min_x == nil) then
        return 0, 0, 0, 0
    end

    local bx = math.floor(min_x)
    local by = math.floor(min_y)
    return bx, by, math.ceil(max_x) - bx, math.ceil(max_y) - by
end

--- Bake the text into a canvas, run the shader chain over it and blit the
--- result at (x, y). Returns false when no canvas was available.
local function draw_shaded(draw_fn, x, y, w, h, shaders)
    local entry = acquire_canvases(w, h)
    if (not entry) then return false end

    local prev_canvas = SE.graphics.getCanvas()

    -- Bake in the typer's own coordinate space: the camera transform is active
    -- around Layers.draw and would offset the text inside the canvas.
    SE.graphics.push()
    SE.graphics.origin()

    local source, target = entry.a, entry.b

    SE.graphics.setCanvas(source)
    SE.graphics.clear(0, 0, 0, 0)
    draw_fn(-x, -y)

    for _, shader in ipairs(shaders) do
        SE.graphics.setCanvas(target)
        SE.graphics.clear(0, 0, 0, 0)
        SE.graphics.setShader(shader)
        SE.graphics.draw(source)
        SE.graphics.setShader()
        source, target = target, source
    end

    SE.graphics.setCanvas(prev_canvas)
    SE.graphics.pop()

    -- Unscaled blit, so every glyph keeps its baked position; each glyph's
    -- colour travels inside the canvas.
    SE.graphics.setColor(1, 1, 1, 1)
    SE.graphics.draw(source, x, y)
    return true
end

--- Draw a typer with its masks and shaders applied.
---
--- `draw_fn(offset_x, offset_y)` draws the text with both offsets added to every
--- letter. `bounds` returns x, y, w, h and is only called when a shader is set.
---
---@param draw_fn function
---@param bounds function|nil
---@param stencils table|nil
---@param shaders table|nil
function render.draw(draw_fn, bounds, stencils, shaders)
    local has_stencils = (stencils ~= nil and #stencils > 0)
    local has_shaders = (shaders ~= nil and #shaders > 0)
    local drawn = false

    if (has_shaders) then
        local x, y, w, h = 0, 0, 0, 0
        if (bounds) then
            x, y, w, h = bounds()
        end

        if (w > 0 and h > 0) then
            drawn = draw_shaded(draw_fn, x, y, w, h, shaders)
        end
    end

    local stencil_on = false
    if (has_stencils and Masks and Masks.Draw and Masks.Use and Masks.Clear) then
        Masks.Draw(stencils)
        Masks.Use()
        stencil_on = true
    end

    if (not drawn) then
        draw_fn(0, 0)
    end

    if (stencil_on) then
        Masks.Clear()
    end
end

return render
