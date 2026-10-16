local masks = {}

---Generate a new mask.
---@param shape string  "rect"/"rectangle", "ellipse"/"circle", or "image"/"img"
---@param x number
---@param y number
---@param w number  rect/ellipse: bbox width; image: target width (0 = native image width)
---@param h number  rect/ellipse: bbox height; image: target height (0 = native image height)
---@param r number  Rotation in degrees
---@param value number  Stencil layer value
---@param image love.Image|table  Optional. love.Image or sprite table (with .image). Used for "image" shape.
---@return table
function masks.New(shape, x, y, w, h, r, value, image)
    local self = {
        shape = shape or "rect",
        x = x or 0,
        y = y or 0,
        w = w or 0,
        h = h or 0,
        r = r or 0,
        value = value or 1,
        isactive = true,
        -- "image" shape only:
        image = image,    -- love.Image, or sprite table with .image field
        scaleX = nil,     -- manual X scale (overrides w-based scale when set)
        scaleY = nil,     -- manual Y scale (overrides h-based scale when set)
        ox = nil,         -- origin X (defaults to imageWidth / 2)
        oy = nil,         -- origin Y (defaults to imageHeight / 2)
    }

    ---Let a mask follow a sprite's position, scale, and rotation.
    ---For image masks, the w/h track the sprite's scaled size so manual
    ---scaleX/scaleY still take effect when set.
    ---@param sprite table
    function self:Follow(sprite)
        self.x = sprite.x
        self.y = sprite.y
        self.w = sprite.width * sprite.xscale
        self.h = sprite.height * sprite.yscale
        self.r = sprite.rotation
    end

    return self
end

---Write masks into the stencil buffer (call this before drawing masked content).
---Uses LÖVE 12's setStencilState API.
---@param tab table  Array of mask objects
function masks.Draw(tab)
    if not tab or #tab == 0 then return end

    SE.graphics.push()
    local ok, err = pcall(function()
        SE.graphics.setColorMask(false)
        SE.graphics.setStencilState("increment", "always", 1)

        for _, mask in ipairs(tab) do
            if mask.isactive ~= false then
                SE.graphics.push()
                SE.graphics.translate(mask.x, mask.y)
                SE.graphics.rotate(math.rad(mask.r))

                if mask.shape == "rect" or mask.shape == "rectangle" then
                    SE.graphics.rectangle("fill", -mask.w / 2, -mask.h / 2, mask.w, mask.h)
                elseif mask.shape == "ellipse" or mask.shape == "circle" then
                    SE.graphics.ellipse("fill", 0, 0, mask.w / 2, mask.h / 2)
                elseif mask.shape == "image" or mask.shape == "img" then
                    -- Mask shape follows the image's per-pixel alpha: only
                    -- fragments that the sprite shader actually emits are
                    -- incremented into the stencil buffer, so fully
                    -- transparent pixels of the ImageData never become mask.
                    local img = mask.image
                    if img and type(img) == "table" and img.image then
                        img = img.image  -- tolerate sprite tables
                    end

                    if img then
                        local iw, ih = img:getDimensions()
                        local sx = mask.scaleX or (mask.w and mask.w > 0 and mask.w / iw or 1)
                        local sy = mask.scaleY or (mask.h and mask.h > 0 and mask.h / ih or 1)
                        local ox = mask.ox or (iw / 2)
                        local oy = mask.oy or (ih / 2)

                        SE.graphics.draw(img, 0, 0, 0, sx, sy, ox, oy)
                    end
                end

                SE.graphics.pop()
            end
        end
    end)

    SE.graphics.setColorMask(true)
    SE.graphics.setStencilState()
    SE.graphics.pop()

    if not ok then
        print("[WARNING] Masks.Draw - stencil masking unavailable: " .. tostring(err))
    end
end

---Activate stencil test so subsequent drawing is clipped to mask areas.
function masks.Use(value)
    local ok, err = pcall(function()
        SE.graphics.setStencilState("keep", "greater", value or 0)
    end)

    if not ok then
        print("[WARNING] Masks.Use - stencil masking unavailable: " .. tostring(err))
    end
end

---Disable stencil test and zero the stencil buffer.
---
---Merely calling setStencilState() (no args) only switches the test OFF --
---the values already written into the buffer stay where they are. Because
---Masks.Draw uses "increment" and Masks.Use defaults to "greater" than 0,
---any pixel ever touched by a mask keeps passing the test forever, leaking
---across frames and across waves (a large mask in turn A still lets bullets
---render in its area during turn B even though turn B only set a small mask).
---
---To prevent that, Clear first overwrites the whole buffer with 0 using
---setStencilState("replace", "always", 0) + a full-canvas rectangle, then
---disables the test. The rectangle is drawn through push/origin so it covers
---the canvas regardless of any camera transform the caller has active, and
---setColorMask(false) keeps it from touching colour.
---
---Caveat: this zeroes the buffer for EVERYONE on this canvas, so a caller
---that relied on the buffer persisting across multiple Draw/Use/Clear cycles
---within the same frame would see later masks need to re-Draw themselves.
---The engine's sprite pipeline (Sprites.lua) calls Draw -> Use -> draw ->
---Clear once per sprite, so each sprite re-writes its own masks and is
---unaffected.
function masks.Clear()
    local ok, err = pcall(function()
        SE.graphics.push("all")
        SE.graphics.origin()
        SE.graphics.setColorMask(false)
        SE.graphics.setStencilState("replace", "always", 0)
        local w, h = SE.graphics.getDimensions()
        if (w and h and w > 0 and h > 0) then
            SE.graphics.rectangle("fill", 0, 0, w, h)
        end
        SE.graphics.setColorMask(true)
        SE.graphics.setStencilState()
        SE.graphics.pop()
    end)

    if not ok then
        print("[WARNING] Masks.Clear - stencil masking unavailable: " .. tostring(err))
    end
end

return masks