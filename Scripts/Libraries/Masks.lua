local masks = {}

---Generate a new mask.
---@param shape string
---@param x number
---@param y number
---@param w number
---@param h number
---@param r number
---@param value number
---@return table
function masks.New(shape, x, y, w, h, r, value)
    local self = {
        shape = shape or "rect",
        x = x or 0,
        y = y or 0,
        w = w or 0,
        h = h or 0,
        r = r or 0,
        value = value or 1,
        isactive = true
    }

    ---Let a mask follow a sprite's position, scale, and rotation.
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
            SE.graphics.push()
            SE.graphics.translate(mask.x, mask.y)
            SE.graphics.rotate(math.rad(mask.r))

            if mask.shape == "rect" or mask.shape == "rectangle" then
                SE.graphics.rectangle("fill", -mask.w / 2, -mask.h / 2, mask.w, mask.h)
            elseif mask.shape == "ellipse" or mask.shape == "circle" then
                SE.graphics.ellipse("fill", 0, 0, mask.w / 2, mask.h / 2)
            end

            SE.graphics.pop()
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

---Disable stencil test and restore normal rendering.
function masks.Clear()
    local ok, err = pcall(function()
        SE.graphics.setStencilState()
    end)

    if not ok then
        print("[WARNING] Masks.Clear - stencil masking unavailable: " .. tostring(err))
    end
end

return masks