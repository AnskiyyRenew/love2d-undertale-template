local sprites = {
    images = {}
}
sprites.imageCache = {}

local rectangulation = require("Scripts.Libraries.PerfectPixel")

local functions = {
    MoveTo = function(self, x, y)
        self.x = x
        self.y = y
    end,
    Move = function(self, x, y)
        self.x = self.x + x
        self.y = self.y + y
    end,
    SetSpeed = function(self, x, y)
        self.velocity.x = x
        self.velocity.y = y
    end,
    Scale = function(self, x, y)
        self.xscale = x
        self.yscale = y
    end,
    Pivot = function(self, x, y)
        self.xpivot = x
        self.ypivot = y
    end,
    Shear = function(self, x, y)
        self.xshear = x
        self.yshear = y
    end,
    Set = function(self, path)
        self.image = love.graphics.newImage("Resources/Sprites/" .. path)
        self.image:setFilter("nearest", "nearest")
        self.imagedata = love.image.newImageData("Resources/Sprites/" .. path)

        -- Change path and realName
        self.path = path
        self.realName = self.path:sub(1, #self.path - 4)
        if (self.isBullet) then
            self.collision.area = rectangulation.rectangulate(self.imagedata)
        end
    end,
    GetPosition = function(self)
        return self.x, self.y
    end,
    SetAnimation = function(self, frames, interval, mode)
        self.animation.mode = (mode or "loop")
        self.animation.index = 0
        self.animation.frames = frames
        self.animation.interval = interval
    end,
    SetStencils = function(self, stencils)
        self.stencils.use = true
        self.stencils.sources = (stencils or {})
        if (#self.stencils.sources == 0) then
            self.stencils.use = false
        end
    end,
    SetShaders = function(self, shaders)
        self.shaders.use = true
        self.shaders.sources = (shaders or {})
        if (#self.shaders.sources == 0) then
            self.shaders.use = false
        end
    end,
    SetParent = function(self, parent)
        if (parent) then
            self.parent = parent
            self.x = 0
            self.y = 0
        else
            self.parent = nil
        end
    end,
    SetPPCollision = function (self, bool)
        self.collision.pp = bool

        if (bool) then
            self.collision.area = rectangulation.rectangulate(self.imagedata)
        else
            self.collision.area = {}
        end
    end,
    GetCollisionRectangles = function(self)
        local collisionRects = {}

        if not self.collision.pp or not self.collision.area then
            return collisionRects
        end

        local rects = self.collision.area
        local cos = math.cos(math.rad(self.rotation))
        local sin = math.sin(math.rad(self.rotation))
        local pivotOffsetX = self.xpivot * self.width
        local pivotOffsetY = self.ypivot * self.height

        for i = 1, #rects do
            local x, y, w, h = unpack(rects[i])
            local originalCenterX = x + w / 2
            local originalCenterY = y + h / 2
            local localX = originalCenterX - pivotOffsetX
            local localY = originalCenterY - pivotOffsetY
            local scaledX = localX * self.xscale
            local scaledY = localY * self.yscale
            local scaledW = w * self.xscale
            local scaledH = h * self.yscale
            local rotatedCenterX = scaledX * cos - scaledY * sin
            local rotatedCenterY = scaledX * sin + scaledY * cos
            local worldCenterX = self.x + rotatedCenterX
            local worldCenterY = self.y + rotatedCenterY

            table.insert(collisionRects, {
                x = worldCenterX,      -- 中心X
                y = worldCenterY,      -- 中心Y
                w = scaledW,           -- 实际宽度
                h = scaledH,           -- 实际高度
                angle = self.rotation,     -- 旋转角度
            })
        end

        return collisionRects
    end,
    Dust = function(self, sound)
        self.dust.totaltime = 1.2
        self.dust.use = true
        self.dust.shader = love.graphics.newShader("Scripts/Shaders/dust")
        self.dust.shader:send("screen_size_inv", {1 / self.width, 1 / self.height})
        self.dust.shader:send("scale_factor", {self.xscale, self.yscale})

        self.color[4] = self.alpha
        self.dust.shader:send("sColor", self.color or {1, 1, 1, 1})
        self.dust.image = love.graphics.newCanvas(self.width, self.height)
        self.dust.iter_image = love.graphics.newCanvas(self.width, self.height)
        love.graphics.setCanvas(self.dust.image)
        love.graphics.draw(self.image)
        love.graphics.setCanvas()
        if (sound) then
            audio.PlaySound("snd_dust.wav")
        end
    end,
    Destroy = function(self)
        for k, sprite in ipairs(sprites.images) do
            if (sprite == self) then
                sprite.isactive = false

                if (sprite.dust and sprite.dust.shader) then
                    if sprite.dust.shader.release then sprite.dust.shader:release() end
                    sprite.dust.shader = nil
                end
                if (sprite.dust and sprite.dust.image) then
                    if sprite.dust.image.release then sprite.dust.image:release() end
                    sprite.dust.image = nil
                end
                if (sprite.dust and sprite.dust.iter_image) then
                    if sprite.dust.iter_image.release then sprite.dust.iter_image:release() end
                    sprite.dust.iter_image = nil
                end
                table.remove(sprites.images, k)
                break
            end
        end
        for k, layer in ipairs(layers.objects) do
            if (layer == self) then
                table.remove(layers.objects, k)
                break
            end
        end
    end,
    Remove = function(self)
        self:Destroy()
    end
}
functions.__index = functions

function sprites.CreateSprite(path, layer)
    local sprite = {}

    sprite.shaders = {
        use = false,
        sources = {}
    }
    sprite.stencils = {
        use = false,
        sources = {}
    }

    sprite.path = path
    sprite.parent = nil
    sprite.realName = sprite.path:sub(1, #sprite.path - 4)
    sprite.isBullet = false
    if (sprites.imageCache[sprite.path]) then
        sprite.image = sprites.imageCache[sprite.path]
    else
        sprites.imageCache[sprite.path] = love.graphics.newImage("Resources/Sprites/" .. sprite.path)
        sprites.imageCache[sprite.path]:setFilter("nearest", "nearest")
        sprite.image = sprites.imageCache[sprite.path]
    end
    sprite.imagedata = love.image.newImageData("Resources/Sprites/" .. sprite.path)
    sprite.layer = layer
    sprite.dust = {
        use = false,
        time = 0,
        shader = nil
    }

    sprite.visible = true
    sprite.isactive = true

    sprite.alpha = 1
    sprite.color = {1, 1, 1}
    sprite.width = sprite.image:getWidth()
    sprite.height = sprite.image:getHeight()
    sprite.xpivot = 0.5
    sprite.ypivot = 0.5
    sprite.rotation = 0
    sprite.x = 320
    sprite.y = 240
    sprite.relx = 0
    sprite.rely = 0
    sprite.velocity = {x = 0, y = 0}
    sprite.speed = {x = 0, y = 0}
    sprite.xshear = 0
    sprite.yshear = 0
    sprite.xscale = 1
    sprite.yscale = 1

    -- Collision.
    sprite.collision = {
        pp = false,
        area = {}
    }

    -- Animation.
    sprite.animation = {
        mode = "loop",
        index = 0,
        frames = {},
        interval = 0,
        time = 0
    }

    function sprite:Draw()
        if not (sprite.isactive and sprite.visible) then return end
        if not sprite.image then return end

        love.graphics.push()
        local finalDrawable = sprite.image

        if sprite.shaders.use and (#sprite.shaders.sources > 0) then
            for _, shader in ipairs(sprite.shaders.sources) do
                love.graphics.setShader(shader)
            end
        end

        if sprite.dust.use and sprite.dust.shader then
            love.graphics.setShader(sprite.dust.shader)
        end

        if sprite.stencils.use then
            love.graphics.clear(false, false, true, 0)
            masks.Draw(sprite.stencils.sources)
            love.graphics.setStencilTest("greater", 0)
        end

        if sprite.alpha > 1 then sprite.alpha = 1 end
        if sprite.alpha < 0 then sprite.alpha = 0 end

        sprite.color[4] = sprite.alpha
        love.graphics.setColor(sprite.color)
        sprite.width = sprite.image:getWidth()
        sprite.height = sprite.image:getHeight()
        local drawX = sprite.x or 0
        local drawY = sprite.y or 0
        local drawR = math.rad(sprite.rotation or 0)
        local drawSX = sprite.xscale or 1
        local drawSY = sprite.yscale or 1
        local drawOX = (sprite.xpivot or 0.5) * sprite.width
        local drawOY = (sprite.ypivot or 0.5) * sprite.height
        local drawKX = sprite.xshear or 0
        local drawKY = sprite.yshear or 0

        love.graphics.draw(finalDrawable, drawX, drawY, drawR, drawSX, drawSY, drawOX, drawOY, drawKX, drawKY)

        if sprite.dust.use and sprite.dust.shader then
            love.graphics.setShader()
        end

        if sprite.stencils.use then
            masks.reset()
            love.graphics.setStencilTest()
        end

        love.graphics.setShader()
        love.graphics.setColor(1, 1, 1, 1)

        love.graphics.pop()
    end

    setmetatable(sprite, functions)
    table.insert(sprites.images, sprite)
    table.insert(layers.objects, sprite)
    return sprite
end


function sprites.CreateSpriteAtlas(path, x, y, w, h, layer)
    local sprite = sprites.CreateSprite(path, layer)
    sprite.quad = love.graphics.newQuad(x, y, w, h, sprite.image:getDimensions())
    sprite.quadArea = {
        x = x,
        y = y,
        w = w,
        h = h
    }
    sprite.xpivot = (x + w / 2) / sprite.width
    sprite.ypivot = (y + h / 2) / sprite.height

    function sprite:Draw()
        if (self.isactive) then
            love.graphics.push()

                if sprite.shaders.use and (#sprite.shaders.sources > 0) then
                    for _, shader in ipairs(sprite.shaders.sources) do
                        love.graphics.setShader(shader)
                    end
                end

                if (sprite.dust.use) then
                    love.graphics.setShader(sprite.dust.shader)
                end

                if (sprite.stencils.use) then
                    love.graphics.clear(false, false, true, 0)
                    masks.Draw(sprite.stencils.sources)
                    love.graphics.setStencilTest("greater", 0)
                end

                if (sprite.alpha > 1) then sprite.alpha = 1 end
                if (sprite.alpha < 0) then sprite.alpha = 0 end
                sprite.color[4] = sprite.alpha
                love.graphics.setColor(sprite.color)

                sprite.width = sprite.quadArea.w
                sprite.height = sprite.quadArea.h

                if (sprite.dust.use) then
                    love.graphics.draw(sprite.dust.image, sprite.quad, sprite.x, sprite.y, math.rad(sprite.rotation), sprite.xscale, sprite.yscale, sprite.xpivot * sprite.width, sprite.ypivot * sprite.height, sprite.xshear, sprite.yshear)
                else
                    love.graphics.draw(sprite.image, sprite.quad, sprite.x, sprite.y, math.rad(sprite.rotation), sprite.xscale, sprite.yscale, sprite.xpivot * sprite.width, sprite.ypivot * sprite.height, sprite.xshear, sprite.yshear)
                end

                if (sprite.dust.use) then
                    love.graphics.setShader()
                end

                masks.reset()
                love.graphics.setShader()

            love.graphics.pop()
        end
    end

    return sprite
end

function sprites.Update(dt)
    for _, sprite in ipairs(sprites.images) do
        local prevX, prevY = sprite.x, sprite.y

        sprite.x = sprite.x + sprite.velocity.x
        sprite.y = sprite.y + sprite.velocity.y

        sprite.speed.x = sprite.x - prevX
        sprite.speed.y = sprite.y - prevY

        if (#sprite.animation.frames > 0) then
            sprite.animation.time = sprite.animation.time + 1
            if (sprite.animation.time >= sprite.animation.interval) then
                sprite.animation.time = 0

                sprite.animation.index = sprite.animation.index + 1
                if (sprite.animation.index > #sprite.animation.frames) then
                    if (sprite.animation.mode == "loop") then
                        sprite.animation.index = 1
                    elseif (sprite.animation.mode == "oneshot") then
                        sprite.animation.index = #sprite.animation.frames
                    elseif (sprite.animation.mode == "oneshot-empty") then
                        sprite.animation.index = 1
                        sprite:Destroy()
                    end
                end
                sprite:Set(sprite.animation.frames[sprite.animation.index])
            end
        end

        if (sprite.parent) then
            local parentX, parentY = sprite.parent.x, sprite.parent.y
            sprite.x = parentX + sprite.relx
            sprite.y = parentY + sprite.rely
        end

        if (sprite.dust.use) then
            sprite.dust.time = sprite.dust.time + dt
            local time_rate = sprite.dust.time / sprite.dust.totaltime

            local shader = sprite.dust.shader
            shader:send("dt", dt)
            if (time_rate <= 1.0) then
                --local position_rate = time_rate * time_rate * (3 - 2 * time_rate)
                local position_rate = time_rate * time_rate * time_rate * (time_rate * (time_rate * 6 - 15) + 10)
                shader:send("scan_y", position_rate)
                love.graphics.setCanvas(sprite.dust.iter_image)
                    love.graphics.clear()
                    love.graphics.setShader(shader)
                        love.graphics.draw(sprite.dust.image)
                    love.graphics.setShader()
                love.graphics.setCanvas()
                sprite.dust.image, sprite.dust.iter_image = sprite.dust.iter_image, sprite.dust.image
            end

            if (time_rate >= 1.0) then
                sprite:Destroy()
            end
        end
    end
end

function sprites.Draw()
    for _, sprite in ipairs(sprites.images) do
        sprite:Draw()
    end
end

function sprites.RemoveImage(path)
    for i = #sprites.images, 1, -1
    do
        local sprite = sprites.images[i]
        if (sprite.path == path) then
            sprite:Destroy()
            table.remove(sprites.images, i)
        end
    end
    sprites.imageCache[path] = nil
end

function sprites.clear()
    for i = #sprites.images, 1, -1 do
        local sprite = sprites.images[i]

        if sprite then
            if sprite.tempCanvas and sprite.tempCanvas.release then sprite.tempCanvas:release() sprite.tempCanvas = nil end
            if sprite.dust then
                if sprite.dust.image and sprite.dust.image.release then sprite.dust.image:release() sprite.dust.image = nil end
                if sprite.dust.iter_image and sprite.dust.iter_image.release then sprite.dust.iter_image:release() sprite.dust.iter_image = nil end
                if sprite.dust.shader and sprite.dust.shader.release then sprite.dust.shader:release() sprite.dust.shader = nil end
            end

            if sprite.shaders and sprite.shaders.sources then
                for j = #sprite.shaders.sources, 1, -1 do
                    local sh = sprite.shaders.sources[j]
                    if sh and sh.release then sh:release() end
                    sprite.shaders.sources[j] = nil
                end
            end

            for k = #layers.objects, 1, -1 do
                if layers.objects[k] == sprite then
                    table.remove(layers.objects, k)
                end
            end

            sprite.image:release()
            sprite:Destroy()

            table.remove(sprites.images, i)
        end
    end

    for path, img in pairs(sprites.imageCache) do
        if img and img.release then img:release() end
        sprites.imageCache[path] = nil
    end
end

return sprites