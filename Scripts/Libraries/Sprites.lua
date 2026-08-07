local sprites = {
    images = {},
    cache = {}
}

-- LRU cache housekeeping
local last_cache_cleanup = 0
local CACHE_CLEAN_INTERVAL = 5 -- seconds between cleanup runs
local function getLRUThreshold()
    local ok, v = pcall(function()
        return Global.GetVariable("OPT_LRU_SPRITES")[2]
    end)
    if ok and type(v) == "number" and v > 0 then
        return v
    end
    return 180
end

local pixel_smooth_shader = nil
local function getPixelPerfectShader()
    if not pixel_smooth_shader then
        pixel_smooth_shader = SE.graphics.newShader("Scripts/Shaders/PixelSmooth.glsl")
    end
    return pixel_smooth_shader
end

local dust_shader = nil
local function getDustShader()
    if not dust_shader then
        dust_shader = SE.graphics.newShader("Scripts/Shaders/Dust.glsl")
    end
    return dust_shader
end

local temp_canvases = {}
local function createStencilCanvas(width, height)
    local ok, canvas = pcall(function()
        return SE.graphics.newCanvas(width, height, nil, {
            stencil = true,
            readable = true
        })
    end)

    if not ok then
        canvas = SE.graphics.newCanvas(width, height, nil, {
            format = "stencil",
            readable = true
        })
    end

    canvas:setFilter("nearest", "nearest")
    return canvas
end

local function getTempCanvas(width, height)
    local key = width .. "x" .. height
    if not temp_canvases[key] then
        temp_canvases[key] = createStencilCanvas(width, height)
    end
    return temp_canvases[key]
end

local function loadImageSafe(path)
    local success, result = pcall(function()
        return SE.graphics.newImage(path)
    end)

    if not success then
        print("[WARNING] Failed to load image: " .. path)
        print("  Error: " .. tostring(result))

        local fallback_data = SE.image.newImageData(1, 1)
        local placeholder = SE.graphics.newImage(fallback_data)
        placeholder:setFilter("nearest", "nearest")
        return placeholder, fallback_data, false
    end

    result:setFilter("nearest", "nearest")

    -- Also load raw pixel data for pixel-level operations
    local imgData
    local ok, data = pcall(function()
        return SE.image.newImageData(path)
    end)
    if ok then
        imgData = data
    else
        imgData = nil
    end

    return result, imgData, true
end

local function normalizeSpritePath(path)
    if not path or path == "" then
        return nil
    end

    path = path:gsub("\\", "/")

    if path:sub(1, 1) == "/" then
        return path
    end

    if path:sub(1, #"Resources/Sprites/") == "Resources/Sprites/" then
        return path
    end

    return "Resources/Sprites/" .. path
end

local function findSpriteFromCache(path)
    local normalized_path = normalizeSpritePath(path)
    if not normalized_path then
        return nil, false
    end

    local entry = sprites.cache[normalized_path]
    if entry then
        return entry.img, entry.loaded
    end

    local img, imgData, loaded = loadImageSafe(normalized_path)

    sprites.cache[normalized_path] = {
        img = img,
        imageData = imgData,
        loaded = loaded,
        last_used = os.time()
    }

    return img, loaded
end

function sprites.MultiDust(sprs, sound, remove, time)
    if not sprs or #sprs == 0 then return end
    time = time or 1.5

    -- Calculate bounding box of all sprites in world space
    local min_x, min_y = math.huge, math.huge
    local max_x, max_y = -math.huge, -math.huge

    for _, spr in ipairs(sprs) do
        local w = spr.width
        local h = spr.height
        local left = spr.x - spr.xpivot * w
        local top = spr.y - spr.ypivot * h
        local right = left + w
        local bottom = top + h
        if left < min_x then min_x = left end
        if top < min_y then min_y = top end
        if right > max_x then max_x = right end
        if bottom > max_y then max_y = bottom end
    end

    local canvas_w = math.max(1, math.ceil(max_x - min_x))
    local canvas_h = math.max(1, math.ceil(max_y - min_y))

    -- Bake all sprites onto a combined canvas
    local dust_canvas = createStencilCanvas(canvas_w, canvas_h)
    local prev = SE.graphics.getCanvas()
    SE.graphics.setCanvas(dust_canvas)
    SE.graphics.clear(0, 0, 0, 0)
    for _, spr in ipairs(sprs) do
        if spr.image and spr.visible then
            local ox, oy = spr:GetPivotOffset()
            SE.graphics.setColor(spr.color[1], spr.color[2], spr.color[3], spr.alpha)
            spr.image:setFilter("nearest", "nearest")
            SE.graphics.draw(
                spr.image,
                spr.x - min_x, spr.y - min_y,
                math.rad(spr.rotation),
                spr.xscale, spr.yscale,
                ox, oy
            )
        end
    end
    SE.graphics.setColor(1, 1, 1, 1)
    SE.graphics.setCanvas(prev)

    -- Hide individual sprites
    for _, spr in ipairs(sprs) do
        spr.visible = false
    end

    -- Create composite dust entity
    local dust_obj = {
        type = "object",
        layer = sprs[1].layer or 0,
        _dust = {
            use = true,
            time = time,
            duration = time,
            remove = remove or false,
            canvas = dust_canvas,
            sprs = sprs,
            x = min_x + canvas_w / 2,
            y = min_y + canvas_h / 2,
            w = canvas_w,
            h = canvas_h
        }
    }

    function dust_obj:Draw()
        if not self._dust.use then return end
        local shader = getDustShader()
        local progress = 1.0 - (self._dust.time / self._dust.duration)
        local eased = progress * progress * (3 - 2 * progress)
        shader:send("dt", self._dust.duration - self._dust.time)
        shader:send("scan_y", math.min(eased, 1.0))
        shader:send("screen_size_inv", {1/self._dust.w, 1/self._dust.h})
        shader:send("scale_factor", {1, 1})
        SE.graphics.setShader(shader)
        SE.graphics.draw(
            self._dust.canvas,
            self._dust.x, self._dust.y, 0, 1, 1,
            self._dust.w / 2, self._dust.h / 2
        )
        SE.graphics.setShader()
    end

    function dust_obj:Update(dt)
        if not self._dust.use then return end
        self._dust.time = self._dust.time - dt
        if self._dust.time <= 0 then
            self._dust.use = false
            self._dust.canvas = nil
            if self._dust.remove then
                for _, spr in ipairs(self._dust.sprs) do
                    spr:Destroy()
                end
            else
                for _, spr in ipairs(self._dust.sprs) do
                    spr.visible = true
                end
            end
            -- Clean up self
            Layers.remove(self)
            for i = #sprites.images, 1, -1 do
                if sprites.images[i] == self then
                    table.remove(sprites.images, i)
                    break
                end
            end
        end
    end

    Layers.add(dust_obj)
    table.insert(sprites.images, dust_obj)

    if (sound) then
        Audio.PlaySound("snd_dust.wav")
    end
end

function sprites.CreateSprite(path, layer)
    if (Global.GetVariable("SE_MEMORY_SAFETY")) then
        if (#sprites.images >= 2 * Global.GetVariable("OPT_COUNT_SPRITES")) then
            print("[Too many sprites warning] The number of sprite instances has reached 4000. Further generation has been disabled. To continue generating, set the SE_MEMORY_SAFETY variable to false, or increase the OPT_COUNT_SPRITES value.")
            return {}
        elseif (#sprites.images >= Global.GetVariable("OPT_COUNT_SPRITES")) then
            print("[Too many sprites warning] The number of sprite instances has reached 2000. Please check for any uncleared sprites.")
        end
    end

    local sprite = {}

    -- Metatable to intercept `.layer` writes and automatically mark Layers as dirty
    setmetatable(sprite, {
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

    sprite.type = "object"
    sprite._id = nil
    sprite._layer_id = nil
    sprite._layer_value = layer or 0
    sprite.is_moving = false
    sprite.path = path
    sprite.pixel_smooth = false
    local full_path = "Resources/Sprites/" .. path
    sprite.image, sprite._loaded = findSpriteFromCache(full_path)

    sprite.width = sprite.image:getWidth()
    sprite.height = sprite.image:getHeight()

    sprite.x = 320
    sprite.y = 240
    sprite.xscale = 1
    sprite.yscale = 1
    sprite.rotation = 0
    sprite.move_speed = 1

    sprite.velocity = {
        x = 0,
        y = 0,
        r = 0
    }

    sprite.speed = {
        x = 0,
        y = 0
    }

    sprite.xpivot = 0.5
    sprite.ypivot = 0.5
    sprite.xpivot_px = 0
    sprite.ypivot_px = 0
    sprite.xanchor = 0
    sprite.yanchor = 0
    sprite.xanchor_px = 0
    sprite.yanchor_px = 0

    sprite.color = {1, 1, 1}
    sprite.alpha = 1
    sprite.visible = true
    -- Optional outline: {r, g, b, a, thickness} drawn from the four
    -- cardinal directions (up/down/left/right). Set to nil to remove.
    sprite.outline = nil

    sprite.parent = nil
    sprite.children = {}
    sprite.follow_mode = "position"

    sprite._has_move_to = false
    sprite._move_to_x = 0
    sprite._move_to_y = 0

    sprite._shaders = {}
    sprite._stencils = {}
    sprite._dust = {
        use = false,
        time = 0,
        duration = 0,
        remove = false
    }

    sprite._four_point = {
        enabled = false,
        p1 = {0, 0},  -- top-left
        p2 = {0, 0},  -- top-right
        p3 = {0, 0},  -- bottom-left
        p4 = {0, 0},  -- bottom-right
    }

    sprite.animation = {
        textures = {},
        interval = 1 / 10,
        mode = "loop",
        time = 0,
        frame = 1,
        done = false
    }

    function sprite:Draw()
        if not self.visible then return end
        if not self.image then return end

        local ox, oy = self:GetPivotOffset()

        -- Apply stencils if any (masks clip the sprite to specific areas)
        local stencil_active = (#self._stencils > 0)
        if stencil_active then
            Masks.Draw(self._stencils)  -- Write masks into stencil buffer
            Masks.Use()                 -- Activate stencil test
        end

        -- Dust effect takes precedence over all other shaders
        -- Uses the baked canvas so shader UV space is always axis-aligned (rotation-independent)
        if self._dust.use then
            local shader = getDustShader()
            -- Smoothstep ease-in-out: scan line starts slow, speeds up, then slows down
            local progress = 1.0 - (self._dust.time / self._dust.duration)
            local eased = progress * progress * (3 - 2 * progress)
            local elapsed = self._dust.duration - self._dust.time
            shader:send("dt", elapsed)
            shader:send("scan_y", math.min(eased, 1.0))
            shader:send("screen_size_inv", {1/self.width, 1/self.height})
            shader:send("scale_factor", {1, 1})
            SE.graphics.setShader(shader)
            SE.graphics.setColor(self.color[1], self.color[2], self.color[3], self.alpha)
            SE.graphics.draw(
                self._dust.canvas,
                self.x, self.y,
                math.rad(self.rotation),
                self.xscale, self.yscale,
                ox, oy
            )
            SE.graphics.setShader()
            SE.graphics.setColor(1, 1, 1, 1)
            if stencil_active then Masks.Clear() end
            return
        end

        -- Draw 4-directional outline (up/down/left/right) behind the sprite
        if self.outline and not self._four_point.enabled then
            self:_drawOutline(ox, oy)
        end

        local shaders = self._shaders or {}

        if (#shaders > 0) then
            if (#shaders == 1) then
                SE.graphics.setShader(shaders[1])
                self:_drawImage(ox, oy)
                SE.graphics.setShader()
            else
                self:_drawWithShaderChain(ox, oy, shaders)
            end
        else
            self:_drawImage(ox, oy)
        end

        if stencil_active then Masks.Clear() end
    end

    function sprite:_drawImage(ox, oy)
        -- Four-point mode: draw with a mesh using the four corner positions
        if self._four_point.enabled then
            self.image:setFilter("nearest", "nearest")
            self:_drawFourPointImage()
            return
        end

        local use_pixel_smooth = self.pixel_smooth and
                                #self._shaders == 0 and
                                math.abs(self.rotation) > 0.001

        if (use_pixel_smooth) then
            -- Pixel-smooth rendering via PixelSmooth shader:
            -- Set filter to linear for smooth interpolation,
            -- then apply shader to keep pixel-art crispness at rotation boundaries
            self.image:setFilter("linear", "linear")

            local shader = getPixelPerfectShader()
            SE.graphics.setShader(shader)
            shader:send("texture_pixel_size", {1/self.width, 1/self.height})

            SE.graphics.setColor(self.color[1], self.color[2], self.color[3], self.alpha)
            SE.graphics.draw(
                self.image,
                self.x, self.y,
                math.rad(self.rotation),
                self.xscale, self.yscale,
                ox, oy
            )
            SE.graphics.setShader()
            SE.graphics.setColor(1, 1, 1, 1)
        else
            self.image:setFilter("nearest", "nearest")
            SE.graphics.setColor(self.color[1], self.color[2], self.color[3], self.alpha)
            SE.graphics.draw(
                self.image,
                self.x, self.y,
                math.rad(self.rotation),
                self.xscale, self.yscale,
                ox, oy
            )
            SE.graphics.setColor(1, 1, 1, 1)
        end
    end

    --- Draw a 4-directional outline (up/down/left/right) behind the sprite.
    --- Only the four cardinal directions are drawn (no diagonal corners).
    --- The outline is unshaded and always rendered with nearest-neighbor
    --- filtering so it stays crisp regardless of rotation/pixel_smooth mode.
    function sprite:_drawOutline(ox, oy)
        local outline = self.outline
        if not outline then return end

        local t = outline[5]
        if not t or t <= 0 then return end

        local a = outline[4]
        if not a or a <= 0 then return end

        self.image:setFilter("nearest", "nearest")
        SE.graphics.setColor(outline[1] or 0, outline[2] or 0, outline[3] or 0, a)

        local rot = math.rad(self.rotation)
        SE.graphics.draw(self.image, self.x - t, self.y, rot, self.xscale, self.yscale, ox, oy)
        SE.graphics.draw(self.image, self.x + t, self.y, rot, self.xscale, self.yscale, ox, oy)
        SE.graphics.draw(self.image, self.x, self.y - t, rot, self.xscale, self.yscale, ox, oy)
        SE.graphics.draw(self.image, self.x, self.y + t, rot, self.xscale, self.yscale, ox, oy)

        SE.graphics.setColor(1, 1, 1, 1)
    end

    --- Internal: draw the sprite using a four-point deformation shader.
    --- The texture is stretched so that its four corners align with
    --- the user-defined points (p1=top-left, p2=top-right, p3=bottom-left, p4=bottom-right).
    function sprite:_drawFourPointImage()
        local fp = self._four_point

        -- Cache the shader
        if not sprites._four_point_shader then
            sprites._four_point_shader = SE.graphics.newShader("Scripts/Shaders/FourPoint.glsl")
        end
        local shader = sprites._four_point_shader

        -- Calculate bounding box of the 4 corners
        local min_x = math.min(fp.p1[1], fp.p2[1], fp.p3[1], fp.p4[1])
        local min_y = math.min(fp.p1[2], fp.p2[2], fp.p3[2], fp.p4[2])
        local max_x = math.max(fp.p1[1], fp.p2[1], fp.p3[1], fp.p4[1])
        local max_y = math.max(fp.p1[2], fp.p2[2], fp.p3[2], fp.p4[2])
        local box_w = max_x - min_x
        local box_h = max_y - min_y

        if box_w <= 0 or box_h <= 0 then return end

        -- Send corner positions to shader
        shader:send("p1", {fp.p1[1], fp.p1[2]})
        shader:send("p2", {fp.p2[1], fp.p2[2]})
        shader:send("p3", {fp.p3[1], fp.p3[2]})
        shader:send("p4", {fp.p4[1], fp.p4[2]})

        -- Apply shader and draw the sprite image stretched to fill the bounding box
        -- The shader will compute correct UV for each pixel to achieve the deformation
        SE.graphics.setShader(shader)
        SE.graphics.setColor(self.color[1], self.color[2], self.color[3], self.alpha)
        self.image:setFilter("nearest", "nearest")
        SE.graphics.draw(
            self.image,
            min_x, min_y,
            0,
            box_w / self.width, box_h / self.height,
            0, 0
        )
        SE.graphics.setShader()
        SE.graphics.setColor(1, 1, 1, 1)
    end

    function sprite:_drawWithShaderChain(ox, oy, shaders)
        local prev_canvas = SE.graphics.getCanvas()
        local canvas1 = getTempCanvas(self.width, self.height)
        local canvas2 = getTempCanvas(self.width, self.height)

        SE.graphics.setCanvas(canvas1)
        SE.graphics.clear(0, 0, 0, 0)
        SE.graphics.setColor(self.color[1], self.color[2], self.color[3], self.alpha)
        SE.graphics.draw(self.image, 0, 0, 0, 1, 1, ox, oy)
        SE.graphics.setColor(1, 1, 1, 1)

        local source = canvas1
        local target = canvas2

        for _, shader in ipairs(shaders) do
            SE.graphics.setCanvas(target)
            SE.graphics.clear(0, 0, 0, 0)
            SE.graphics.setShader(shader)
            SE.graphics.draw(source)
            SE.graphics.setShader()
            source, target = target, source
        end

        SE.graphics.setCanvas(prev_canvas)
        SE.graphics.setColor(1, 1, 1, 1)
        SE.graphics.draw(
            source,
            self.x, self.y,
            math.rad(self.rotation),
            self.xscale, self.yscale,
            ox, oy
        )
        SE.graphics.setColor(1, 1, 1, 1)
    end

    function sprite:Update(dt)
        -- Record previous position for movement tracking
        local prev_x, prev_y = self.x, self.y

        -- Apply parent-anchored position first (base position from parent)
        if self.parent and self.parent.image then
            if self.follow_mode == "full" then
                local angle = math.rad(self.parent.rotation)
                local cos_a = math.cos(angle)
                local sin_a = math.sin(angle)
                self.x = self.parent.x + self.xanchor_px * cos_a - self.yanchor_px * sin_a
                self.y = self.parent.y + self.xanchor_px * sin_a + self.yanchor_px * cos_a
            else
                self.x = self.parent.x + self.xanchor_px
                self.y = self.parent.y + self.yanchor_px
            end
        end

        -- Apply velocity on top of parent (highest priority — even with a parent,
        -- setting velocity will directly move the sprite)
        self.x = self.x + self.velocity.x * self.move_speed
        self.y = self.y + self.velocity.y * self.move_speed
        self.rotation = self.rotation + self.velocity.r
        -- Track actual movement: set is_moving and record actual pixel delta into speed
        local dx = self.x - prev_x
        local dy = self.y - prev_y
        self.is_moving = (dx ~= 0 or dy ~= 0)
        self.speed.x = dx
        self.speed.y = dy

        if (self.Step) then
            self:Step(dt)
        end

        local anim = sprite.animation
        if (#anim.textures > 0) then
            anim.time = anim.time + dt
            if (anim.time >= anim.interval) then
                if (anim.mode == "loop") then
                    sprite:Set(anim.textures[anim.frame])
                    anim.frame = anim.frame % #anim.textures + 1
                elseif (anim.mode == "oneshot") then
                    sprite:Set(anim.textures[anim.frame])
                    anim.frame = anim.frame + 1

                    if (anim.frame > #anim.textures) then
                        anim.textures = {}
                    end
                elseif (anim.mode == "oneshot-empty" or anim.mode == "empty") then
                    if (anim.textures[anim.frame]) then
                        sprite:Set(anim.textures[anim.frame])
                    end
                    anim.frame = anim.frame + 1

                    if (anim.frame > #anim.textures + 1) then
                        anim.textures = {}
                        sprite.visible = false
                    end
                elseif (anim.mode == "looponce") then
                    -- Play through the sequence once, then return to the first
                    -- frame and hold there until it is triggered again.
                    if (not anim.done) then
                        sprite:Set(anim.textures[anim.frame])
                        anim.frame = anim.frame + 1

                        if (anim.frame > #anim.textures) then
                            anim.frame = 1
                            anim.done = true
                        end
                    end
                end
                anim.time = 0
            end
        end

        if (sprite._dust.use) then
            sprite._dust.time = sprite._dust.time - dt
            if sprite._dust.time <= 0 then
                sprite._dust.use = false
                sprite._dust.canvas = nil
                if sprite._dust.remove then
                    sprite:Destroy()
                end
            end
        end
    end

    function sprite:GetPivotOffset()
        if (self.xpivot_px ~= 0 or self.ypivot_px ~= 0) then
            return self.xpivot_px, self.ypivot_px
        else
            return self.xpivot * self.width, self.ypivot * self.height
        end
    end

    function sprite:GetFilter()
        return self.image:getFilter()
    end

    function sprite:Dust(sound, remove, time)
        -- Bake current image onto a canvas so dust shader works in local UV space
        -- regardless of sprite rotation, and also captures any animation frame
        local w = self.width
        local h = self.height
        local dust_canvas = createStencilCanvas(w, h)
        local prev = SE.graphics.getCanvas()
        SE.graphics.setCanvas(dust_canvas)
        SE.graphics.clear(0, 0, 0, 0)
        self.image:setFilter("nearest", "nearest")
        SE.graphics.draw(self.image, 0, 0, 0, 1, 1, 0, 0)
        SE.graphics.setCanvas(prev)

        if (sound) then
            Audio.PlaySound("snd_dust.wav")
        end
        sprite._dust.canvas = dust_canvas
        sprite._dust.use = true
        sprite._dust.remove = remove or false
        sprite._dust.time = (time or 1)
        sprite._dust.duration = sprite._dust.time
    end

    --- Add or remove a 4-directional outline on the sprite.
    --- Outline is drawn from up/down/left/right only (no diagonal corners).
    --- Calling without valid colors, or setting self.outline = nil, removes it.
    ---@param r number Red (0-1)
    ---@param g number Green (0-1)
    ---@param b number Blue (0-1)
    ---@param a number Alpha (0-1)
    ---@param t number Thickness in pixels
    function sprite:OutLine(r, g, b, a, t)
        if r == nil or g == nil or b == nil then
            self.outline = nil
            return
        end
        self.outline = {r, g, b, a or 1, t or 1}
    end

    --- Enable or disable four-point control mode.
    --- When enabled, the sprite's texture is stretched so its four corners
    --- are drawn at the positions defined by SetFourPoint / SetFourPointP.
    --- The sprite's x, y, rotation, xscale, yscale are NOT used in this mode.
    ---@param enabled boolean
    function sprite:SetFourPointMode(enabled)
        self._four_point.enabled = enabled
    end

    --- Set all four corner points at once for four-point control.
    --- Point order: p1=top-left, p2=top-right, p3=bottom-left, p4=bottom-right.
    ---@param p1x number Top-left X
    ---@param p1y number Top-left Y
    ---@param p2x number Top-right X
    ---@param p2y number Top-right Y
    ---@param p3x number Bottom-left X
    ---@param p3y number Bottom-left Y
    ---@param p4x number Bottom-right X
    ---@param p4y number Bottom-right Y
    function sprite:SetFourPoint(p1x, p1y, p2x, p2y, p3x, p3y, p4x, p4y)
        self._four_point.p1 = {p1x, p1y}
        self._four_point.p2 = {p2x, p2y}
        self._four_point.p3 = {p3x, p3y}
        self._four_point.p4 = {p4x, p4y}
    end

    --- Set a single corner point for four-point control.
    ---@param index integer Point index (1=top-left, 2=top-right, 3=bottom-left, 4=bottom-right)
    ---@param x     number X coordinate
    ---@param y     number Y coordinate
    function sprite:SetFourPointP(index, x, y)
        local key = "p" .. index
        if self._four_point[key] then
            self._four_point[key][1] = x
            self._four_point[key][2] = y
        end
    end

    function sprite:Move(x, y)
        local prev_x, prev_y = self.x, self.y
        self.x = self.x + x
        self.y = self.y + y
        -- Recalculate anchor_px so parent tracking stays correct
        if self.parent and self.parent.image then
            local dx = self.x - self.parent.x
            local dy = self.y - self.parent.y
            if self.follow_mode == "full" then
                local angle = math.rad(self.parent.rotation)
                local cos_a = math.cos(angle)
                local sin_a = math.sin(angle)
                self.xanchor_px = dx * cos_a + dy * sin_a
                self.yanchor_px = -dx * sin_a + dy * cos_a
            else
                self.xanchor_px = dx
                self.yanchor_px = dy
            end
        end
        -- Update movement tracking immediately
        local dx = self.x - prev_x
        local dy = self.y - prev_y
        self.is_moving = (dx ~= 0 or dy ~= 0)
        self.speed.x = dx
        self.speed.y = dy
    end

    function sprite:MoveTo(x, y)
        self.x = x
        self.y = y
        -- Recalculate anchor_px so parent tracking stays correct
        if self.parent and self.parent.image then
            local dx = self.x - self.parent.x
            local dy = self.y - self.parent.y
            if self.follow_mode == "full" then
                local angle = math.rad(self.parent.rotation)
                local cos_a = math.cos(angle)
                local sin_a = math.sin(angle)
                self.xanchor_px = dx * cos_a + dy * sin_a
                self.yanchor_px = -dx * sin_a + dy * cos_a
            else
                self.xanchor_px = dx
                self.yanchor_px = dy
            end
        end
    end

    function sprite:Set(p)
        self.image = findSpriteFromCache(p)
        if self.image then
            self.width = self.image:getWidth()
            self.height = self.image:getHeight()
        end

        -- Calling Set force-replaces any active SetAnimation: the sprite shows
        -- the static image picked by Set and the animation is disabled so it can
        -- no longer override this image ("listen to Set").
        -- Internal frame-advance calls from the animation loop itself pass a
        -- frame that is already in the current texture list, so those are left
        -- alone to keep SetAnimation working.
        local anim = sprite.animation
        if (anim and #anim.textures > 0) then
            local p_norm = normalizeSpritePath(p)
            local is_anim_frame = false
            for i = 1, #anim.textures do
                if (normalizeSpritePath(anim.textures[i]) == p_norm) then
                    is_anim_frame = true
                    break
                end
            end
            if (not is_anim_frame) then
                sprite.animation = {
                    textures = {},
                    interval = 1 / 10,
                    mode = "loop",
                    time = 0,
                    frame = 1,
                    done = false
                }
            end
        end
    end

    function sprite:SetAnimation(frames, interval, mode)
        sprite.animation = {
            textures = (frames or {}),
            interval = interval,
            mode = (mode or "loop"),
            time = 0,
            frame = 1,
            done = false
        }
    end

    function sprite:Scale(x, y)
        self.xscale = x
        self.yscale = y
    end

    function sprite:Pivot(x, y)
        self.xpivot = x
        self.ypivot = y
    end

    function sprite:PivotPixel(x, y)
        self.xpivot_px = x
        self.ypivot_px = y
    end

    function sprite:Anchor(x, y)
        self.xanchor = x
        self.yanchor = y
        -- Convert proportional anchor to pixel offset using parent dimensions
        if self.parent and self.parent.image then
            self.xanchor_px = x * self.parent.width
            self.yanchor_px = y * self.parent.height
        end
    end

    function sprite:AnchorPixel(x, y)
        self.xanchor_px = x
        self.yanchor_px = y
    end

    function sprite:SetParent(spr)
        self.parent = spr
    end

    function sprite:SetChildren(children)
        self.children = children
    end

    function sprite:AddChild(child)
        table.insert(self.children, child)
        child.parent = self
    end

    function sprite:RemoveChild(child)
        for i = #self.children, 1, -1 do
            if (self.children[i] == child) then
                table.remove(self.children, i)
                child.parent = nil
                return true
            end
        end
        return false
    end

    function sprite:GetPosition()
        return self.x, self.y
    end

    function sprite:GetPositionParent()
        if self.parent and self.parent.image then
            return self.xanchor_px, self.yanchor_px
        else
            return self.x, self.y
        end
    end

    function sprite:SetStencils(stencils)
        self._stencils = {}

        if not stencils then
            return
        end

        local list = type(stencils) == "table" and stencils or {stencils}

        for _, mask in ipairs(list) do
            if mask and type(mask) == "table" and mask.shape then
                table.insert(self._stencils, mask)
            elseif mask then
                print("[WARNING] sprite:SetStencils - Invalid mask object")
            end
        end
    end

    function sprite:SetShaders(shaders)
        self._shaders = {}

        if not shaders then
            return
        end

        local shader_list = type(shaders) == "table" and shaders or {shaders}

        for _, shader in ipairs(shader_list) do
            if shader and type(shader) == "userdata" then
                table.insert(self._shaders, shader)
            elseif shader then
                print("[WARNING] sprite:SetShaders - Invalid shader object")
            end
        end
    end

    function sprite:GetShaders()
        return self._shaders
    end

    function sprite:ClearShaders()
        self._shaders = {}
    end

    function sprite:AddShader(shader)
        if (not shader) then return end
        table.insert(self._shaders, shader)
    end

    function sprite:InsertShader(index, shader)
        if (not shader) then return end
        table.insert(self._shaders, index, shader)
    end

    function sprite:RemoveShader(shader)
        for i = #self._shaders, 1, -1 do
            if (self._shaders[i] == shader) then
                table.remove(self._shaders, i)
                return true
            end
        end
        return false
    end

    function sprite:Destroy()
        Layers.remove(sprite)
        for i = #sprites.images, 1, -1 do
            if (sprites.images[i] == sprite) then
                table.remove(sprites.images, i)
                break
            end
        end
    end

    function sprite:Remove()
        self:Destroy()
    end

    Layers.add(sprite)
    table.insert(sprites.images, sprite)
    return sprite
end

function sprites.Update(dt)
    local now = os.time()

    -- Periodically clean up LRU cache entries
    if (Global.GetVariable("OPT_LRU_SPRITES")[1]) then
        if now - last_cache_cleanup >= CACHE_CLEAN_INTERVAL then
            local threshold = getLRUThreshold()

            -- Build a set of images currently referenced by active sprites
            -- This is done FIRST so `last_used` reflects real rendering activity,
            -- not cache-access timestamps (fixes issue where static sprites never refresh their cache entry)
            local in_use_images = {}
            for _, spr in ipairs(sprites.images) do
                if spr.image then
                    in_use_images[spr.image] = true
                end
            end

            for k, entry in pairs(sprites.cache) do
                if entry and entry.last_used then
                    if in_use_images[entry.img] then
                        -- Image is still used by an active sprite; keep it fresh
                        entry.last_used = now
                    elseif (now - entry.last_used) >= threshold then
                        -- No active sprite references this image and it's past the threshold; safe to release
                        pcall(function()
                            if entry.img and type(entry.img.release) == "function" then
                                entry.img:release()
                            end
                        end)
                        sprites.cache[k] = nil
                    end
                else
                    -- No timestamp or malformed entry; remove conservatively
                    sprites.cache[k] = nil
                end
            end
            last_cache_cleanup = now
        end
    end

    for i = #sprites.images, 1, -1 do
        local sprite = sprites.images[i]
        if sprite then
            sprite:Update(dt)
        end
    end
end

function sprites.CleanupCache()
    local now = os.time()
    local threshold = getLRUThreshold()

    -- Build a set of images currently referenced by active sprites
    local in_use_images = {}
    for _, spr in ipairs(sprites.images) do
        if spr.image then
            in_use_images[spr.image] = true
        end
    end

    for k, entry in pairs(sprites.cache) do
        if entry and entry.last_used then
            if in_use_images[entry.img] then
                -- Still in use; refresh timestamp
                entry.last_used = now
            elseif (now - entry.last_used) >= threshold then
                -- Not referenced by any active sprite and past threshold; safe to release
                pcall(function()
                    if entry.img and type(entry.img.release) == "function" then
                        entry.img:release()
                    end
                end)
                sprites.cache[k] = nil
            end
        else
            sprites.cache[k] = nil
        end
    end
end

--- Return debug information about the image cache.
---@return integer count Number of unique images cached.
---@return table details A list of cached paths with their last_used timestamps.
function sprites.GetCacheInfo()
    local count = 0
    local details = {}
    for k, entry in pairs(sprites.cache) do
        count = count + 1
        details[#details + 1] = {
            path = k,
            last_used = entry.last_used
        }
    end
    return count, details
end

return sprites