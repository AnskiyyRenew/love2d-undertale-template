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

--- Make a sprite shake in place for a short time.
--- The offset is applied ONLY at draw time, so the stored x / y (and therefore
--- movement via Move / MoveTo / velocity / parents) is never disturbed.
---@param sprite   table          The sprite instance to shake.
---@param magnitude number|table  Max offset in pixels. A plain number shakes BOTH
---                               axes. To shake only one axis (or use different
---                               amounts per axis) pass a table {x = .., y = ..}
---                               (or {.., ..}); any axis that is omitted / 0 stays
---                               still, e.g. {x = 3} shakes only x, {y = 3} only y.
---@param duration number|nil     How long the shake lasts, in seconds. Default 0.5.
---@param speed    number|nil     How long the shake keeps near-full strength before
---                               settling down: 1 fades out across the whole duration,
---                               higher values rattle at full strength longer then
---                               stop quickly. Default 1.
function sprites.ShakeSprite(sprite, magnitude, duration, speed)
    if ((not sprite) or (not sprite.image)) then return end

    local mx, my
    if (type(magnitude) == "table") then
        mx = math.abs(magnitude.x or magnitude[1] or 0)
        my = math.abs(magnitude.y or magnitude[2] or 0)
    else
        mx = math.abs(magnitude or 0)
        my = mx
    end

    if (mx <= 0 and my <= 0) then return end

    local shake = sprite._shake
    if (not shake) then shake = {}; sprite._shake = shake end

    shake.use = true
    shake.duration = duration or 0.5
    shake.time = shake.duration
    shake.magnitude = {mx, my}
    shake.speed = speed or 1
    shake.dx = 0
    shake.dy = 0
end

--- Spawn a fading "shadow" copy of a sprite (like Player.AddParticle).
--- The shadow is a brand-new sprite that starts right on top of the source,
--- follows its position every frame while it lives, exponentially grows toward
--- `target_scale`, fades out over `duration` seconds, then destroys itself.
---@param sprite       table        The sprite to copy.
---@param target_scale number|nil   Scale the shadow grows toward (both axes). Default 2.
---@param duration     number|nil   Lifetime of the shadow, in seconds. Default 0.5.
---@param speed        number|nil   How fast the shadow grows/settles (higher = faster).
---                                 Default 8 (keeps a similar feel to AddParticle).
---@return table|nil The spawned shadow sprite (nil if it could not be created).
function sprites.ShadowSprite(sprite, target_scale, duration, speed)
    if ((not sprite) or (not sprite.image)) then return nil end

    -- Draw just behind the source when possible (only numeric layers can be offset).
    local layer = sprite.layer
    if (type(layer) == "number") then layer = layer - 0.1 end
    local shadow = sprites.CreateSprite(sprite.path, layer)
    if ((not shadow) or (not shadow.image)) then return nil end

    shadow:MoveTo(sprite:GetPosition())
    shadow.color = {sprite.color[1], sprite.color[2], sprite.color[3]}
    shadow.alpha = sprite.alpha or 1
    shadow.xscale = sprite.xscale or 1
    shadow.yscale = sprite.yscale or 1
    shadow.rotation = sprite.rotation or 0

    local life = duration or 0.5
    shadow._shadow = {
        use = true,
        source = sprite,
        target_scale = target_scale or 2,
        duration = life,
        time = life,
        speed = speed or 8,
        base_alpha = shadow.alpha
    }

    shadow.Step = function (self, dt)
        local st = self._shadow
        if ((not st) or (not st.use)) then return end

        -- Follow the source so a moving sprite leaves a smooth trail behind it.
        if (st.source and st.source.image) then
            self:MoveTo(st.source:GetPosition())
        end

        -- Grow toward the target scale (dt-safe exponential smoothing).
        local factor = math.min(1, (dt or 0) * st.speed)
        self:Scale(
            self.xscale + (st.target_scale - self.xscale) * factor,
            self.yscale + (st.target_scale - self.yscale) * factor
        )

        -- Fade out over the lifetime, then remove the shadow.
        st.time = st.time - (dt or 0)
        if (st.time <= 0) then
            st.use = false
            self:Destroy()
        else
            self.alpha = st.base_alpha * (st.time / st.duration)
        end
    end

    return shadow
end

--- A Sprite instance created by sprites.CreateSprite / sprites.CreateSpriteQuad.
--- The heavy methods are shared behind a prototype table and exposed through each
--- instance's metatable, so this class annotation keeps editor autocomplete and
--- type checks working as if the methods lived directly on the instance.
---@class Sprite
---@field type string
---@field path string
---@field image userdata|nil
---@field quad table|nil
---@field width number
---@field height number
---@field x number
---@field y number
---@field xscale number
---@field yscale number
---@field rotation number
---@field move_speed number
---@field color table
---@field alpha number
---@field visible boolean
---@field layer number|string
---@field parent Sprite|nil
---@field children Sprite[]
---@field Step? fun(self:Sprite, dt:number)
---@field velocity {x:number, y:number, r:number}
---@field speed {x:number, y:number}
---@field Draw fun(self:Sprite)
---@field Update fun(self:Sprite, dt:number)
---@field GetPivotOffset fun(self:Sprite):number, number
---@field GetFilter fun(self:Sprite):string, string
---@field Dust fun(self:Sprite, sound:boolean?, remove:boolean?, time:number?)
---@field OutLine fun(self:Sprite, r:number?, g:number?, b:number?, a:number?, t:number?)
---@field SetFourPointMode fun(self:Sprite, enabled:boolean)
---@field SetFourPoint fun(self:Sprite, p1x:number, p1y:number, p2x:number, p2y:number, p3x:number, p3y:number, p4x:number, p4y:number)
---@field SetFourPointP fun(self:Sprite, index:integer, x:number, y:number)
---@field Move fun(self:Sprite, x:number, y:number)
---@field MoveTo fun(self:Sprite, x:number, y:number)
---@field Set fun(self:Sprite, p:string)
---@field SetAnimation fun(self:Sprite, frames:table?, interval:number?, mode:string?)
---@field Scale fun(self:Sprite, x:number, y:number)
---@field Pivot fun(self:Sprite, x:number, y:number)
---@field PivotPixel fun(self:Sprite, x:number, y:number)
---@field Anchor fun(self:Sprite, x:number, y:number)
---@field AnchorPixel fun(self:Sprite, x:number, y:number)
---@field SetParent fun(self:Sprite, spr:Sprite?)
---@field SetChildren fun(self:Sprite, children:Sprite[])
---@field AddChild fun(self:Sprite, child:Sprite)
---@field RemoveChild fun(self:Sprite, child:Sprite):boolean
---@field GetPosition fun(self:Sprite):number, number
---@field GetPositionParent fun(self:Sprite):number, number
---@field SetStencils fun(self:Sprite, stencils:table?)
---@field SetShaders fun(self:Sprite, shaders:table?)
---@field GetShaders fun(self:Sprite):table
---@field ClearShaders fun(self:Sprite)
---@field AddShader fun(self:Sprite, shader:userdata)
---@field InsertShader fun(self:Sprite, index:integer, shader:userdata)
---@field RemoveShader fun(self:Sprite, shader:userdata):boolean
---@field Destroy fun(self:Sprite)
---@field Remove fun(self:Sprite)
local sprite_methods = {}
local sprite_methods_ready = false

---@param path string Sprite path, relative to Resources/Sprites/ (no prefix).
---@param layer number|string|nil Layer to place the sprite on.
---@return Sprite
function sprites.CreateSprite(path, layer)
    if (Global.GetVariable("SE_MEMORY_SAFETY")) then
        if (#sprites.images >= 2 * Global.GetVariable("OPT_COUNT_SPRITES")) then
            print("[Too many sprites warning] The number of sprite instances has reached 4000. Further generation has been disabled. To continue generating, set the SE_MEMORY_SAFETY variable to false, or increase the OPT_COUNT_SPRITES value.")
            return {}
        elseif (#sprites.images >= Global.GetVariable("OPT_COUNT_SPRITES")) then
            print("[Too many sprites warning] The number of sprite instances has reached 2000. Please check for any uncleared sprites.")
        end
    end

    ---@type Sprite
    local sprite = {}

    -- Metatable to intercept `.layer` writes and automatically mark Layers as dirty
    setmetatable(sprite, {
        __index = function(t, k)
            if k == "layer" then
                return rawget(t, "_layer_value")
            elseif k == "x" or k == "y" then
                return rawget(t, "_" .. k)
            end
            local v = rawget(t, k)
            if (v ~= nil) then return v end
            -- Shared sprite methods (see the Sprite class annotation above).
            return sprite_methods[k]
        end,
        __newindex = function(t, k, v)
            if k == "layer" then
                rawset(t, "_layer_value", v)
                Layers.mark_dirty()
            elseif (k == "x" or k == "y") then
                local prev = rawget(t, "_" .. k)
                if (prev ~= v and t.speed) then
                    local d = v - prev
                    if (k == "x") then
                        t.speed.x = t.speed.x + d
                    else
                        t.speed.y = t.speed.y + d
                    end
                    rawset(t, "is_moving", true)
                end
                rawset(t, "_" .. k, v)
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

    -- Shake effect state (see sprites.ShakeSprite). Visual only: the offset is
    -- applied at draw time and never written into x / y.
    sprite._shake = {
        use = false,
        time = 0,
        duration = 0,
        speed = 1,
        magnitude = {0, 0},
        dx = 0,
        dy = 0
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

    -- Shared sprite methods: instead of re-creating ~37 closures for EVERY sprite,
    -- they are defined ONCE (on the very first CreateSprite call) into the
    -- module-level `sprite_methods` table, then resolved by every instance through
    -- the metatable __index fallback above. `sprite` is temporarily rebound to the
    -- shared table so the `function sprite:...` blocks below populate it instead of
    -- this instance; the method bodies only use `self`, so they are safe to share.
    if (not sprite_methods_ready) then
        sprite_methods_ready = true
        local _instance = sprite
        sprite = sprite_methods

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

        -- Shake effect (visual only): temporarily shift the draw position by the
        -- per-frame shake offset. Uses rawset on the underlying "_x"/"_y" storage
        -- (the metatable maps x -> _x, y -> _y) to bypass the coordinate-tracking
        -- hooks, then restores the values below so the stored position (and any
        -- Move / MoveTo / velocity logic) is never modified.
        local shake_dx, shake_dy = 0, 0
        if (self._shake and self._shake.use) then
            shake_dx = self._shake.dx or 0
            shake_dy = self._shake.dy or 0
            if (shake_dx ~= 0 or shake_dy ~= 0) then
                rawset(self, "_x", self.x + shake_dx)
                rawset(self, "_y", self.y + shake_dy)
            end
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

        -- Restore the base position after the shaken draw.
        if (shake_dx ~= 0 or shake_dy ~= 0) then
            rawset(self, "_x", self.x - shake_dx)
            rawset(self, "_y", self.y - shake_dy)
        end
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
        -- Coordinate writes below are tracked by the metatable.
        self.speed.x = 0
        self.speed.y = 0
        self.is_moving = false

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

        if (self.Step) then
            self:Step(dt)
        end

        local anim = self.animation
        if (#anim.textures > 0) then
            anim.time = anim.time + dt
            if (anim.time >= anim.interval) then
                if (anim.mode == "loop") then
                    self:Set(anim.textures[anim.frame])
                    anim.frame = anim.frame % #anim.textures + 1
                elseif (anim.mode == "oneshot") then
                    self:Set(anim.textures[anim.frame])
                    anim.frame = anim.frame + 1

                    if (anim.frame > #anim.textures) then
                        anim.textures = {}
                    end
                elseif (anim.mode == "oneshot-empty" or anim.mode == "empty") then
                    if (anim.textures[anim.frame]) then
                        self:Set(anim.textures[anim.frame])
                    end
                    anim.frame = anim.frame + 1

                    if (anim.frame > #anim.textures + 1) then
                        anim.textures = {}
                        self.visible = false
                    end
                elseif (anim.mode == "looponce") then
                    -- Play through the sequence once, then return to the first
                    -- frame and hold there until it is triggered again.
                    if (not anim.done) then
                        self:Set(anim.textures[anim.frame])
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

        if (self._dust.use) then
            self._dust.time = self._dust.time - dt
            if self._dust.time <= 0 then
                self._dust.use = false
                self._dust.canvas = nil
                if self._dust.remove then
                    self:Destroy()
                end
            end
        end

        -- Shake effect (visual only): tick the timer and refresh the random
        -- draw offset. Draw() consumes it, so x / y are never touched.
        if (self._shake and self._shake.use) then
            local shake = self._shake
            shake.time = shake.time - dt
            if (shake.time <= 0) then
                shake.use = false
                shake.dx = 0
                shake.dy = 0
            else
                -- Amplitude eases out over the shake's life; "speed" keeps it at
                -- near-full strength longer (higher) or ramps down the whole time (1).
                local life = math.max(0, shake.time / shake.duration)
                local amp_x = shake.magnitude[1] * math.min(1, life * shake.speed)
                local amp_y = shake.magnitude[2] * math.min(1, life * shake.speed)
                shake.dx = (amp_x > 0) and ((math.random() * 2 - 1) * amp_x) or 0
                shake.dy = (amp_y > 0) and ((math.random() * 2 - 1) * amp_y) or 0
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
        self._dust.canvas = dust_canvas
        self._dust.use = true
        self._dust.remove = remove or false
        self._dust.time = (time or 1)
        self._dust.duration = self._dust.time
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
        local anim = self.animation
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
                self.animation = {
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
        self:Set(frames[1])
        self.animation = {
            textures = (frames or {}),
            interval = interval,
            mode = (mode or "loop"),
            time = 0,
            frame = 2,
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
        Layers.remove(self)
        for i = #sprites.images, 1, -1 do
            if (sprites.images[i] == self) then
                table.remove(sprites.images, i)
                break
            end
        end
    end

    function sprite:Remove()
        self:Destroy()
    end

        sprite = _instance
    end

    Layers.add(sprite)
    table.insert(sprites.images, sprite)
    return sprite
end

--- Create a sprite that shows only a rectangular region ("quad") of a sprite sheet.
--- The requested region is baked into its own cropped image (cached per region), so
--- every existing sprite feature — pivot, outline, dust, scaling, four-point, etc. —
--- works using the region's own width & height, with no draw-time changes required.
---@param path  string              Sprite sheet path (same format as CreateSprite, i.e.
---                                 without the "Resources/Sprites/" prefix).
---@param quad  table               Region to show: {x = .., y = .., width = .., height = ..}
---@param layer number|string|nil   Layer for the sprite (same as CreateSprite).
---@return Sprite The new sprite (an empty table {} when it could not be created).
function sprites.CreateSpriteQuad(path, quad, layer)
    if ((not path) or (not quad)) then return {} end

    local qx = math.floor(quad.x or 0)
    local qy = math.floor(quad.y or 0)
    local qw = math.floor(quad.width or 0)
    local qh = math.floor(quad.height or 0)
    if (qw <= 0 or qh <= 0) then return {} end

    -- Build the sprite with the exact same logic as CreateSprite...
    ---@type Sprite
    local sprite = sprites.CreateSprite(path, layer)
    if ((not sprite) or (not sprite.image)) then return sprite end

    -- ...then swap in a cropped copy of the sheet, so the sprite's width / height
    -- (and therefore pivot / outline / dust handling) match the requested region
    -- instead of the whole sheet.
    local full_path = "Resources/Sprites/" .. path
    local sheet_w = sprite.image:getWidth()
    local sheet_h = sprite.image:getHeight()

    -- Clamp the region to the real sheet bounds (also handles the 1x1 fallback image).
    if (qx + qw > sheet_w) then qw = sheet_w - qx end
    if (qy + qh > sheet_h) then qh = sheet_h - qy end
    if (qw <= 0 or qh <= 0) then return sprite end

    -- Cache the cropped image per region so multiple sprites can share the same crop.
    local crop_key = full_path .. "#" .. qx .. "," .. qy .. "," .. qw .. "," .. qh
    local entry = sprites.cache[crop_key]
    if (not entry) then
        local ok, crop_img, crop_data = pcall(function()
            local data = SE.image.newImageData(qw, qh)
            local source_entry = sprites.cache[full_path]
            local src_data = (source_entry and source_entry.imageData) or sprite.image:getImageData()
            if (src_data) then
                data:paste(src_data, 0, 0, qx, qy, qw, qh)
            end
            local img = SE.graphics.newImage(data)
            img:setFilter("nearest", "nearest")
            return img, data
        end)
        if (ok and crop_img) then
            entry = {
                img = crop_img,
                imageData = crop_data,
                loaded = true,
                last_used = os.time()
            }
            sprites.cache[crop_key] = entry
        end
    end

    if (entry) then
        sprite.image = entry.img
        sprite.width = qw
        sprite.height = qh
        sprite.quad = {x = qx, y = qy, width = qw, height = qh}
    end
    -- On any crop failure the sprite keeps the full sheet image, so it still works.

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