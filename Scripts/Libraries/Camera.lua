local camera = {}
camera.__index = camera

--- Creates a camera instance centered on the canvas with optional size and rotation.
---@param x number|nil
---@param y number|nil
---@param width number|nil
---@param height number|nil
---@param angle number|nil
---@return table
function camera:New(x, y, width, height, angle)
    local cam = {}
    setmetatable(cam, camera)

    cam.x = (x or CANVAS_WIDTH / 2)
    cam.y = (y or CANVAS_HEIGHT / 2)
    cam.w = (width or CANVAS_WIDTH)
    cam.h = (height or CANVAS_HEIGHT)
    cam.r = (angle or 0)
    cam.xscale = 1
    cam.yscale = 1

    cam.shaker = {
        _start = 0,
        _time = 0,
        mag = 0,
        duration = 0,
        decay = true,

        x = 0,
        y = 0,
    }

    return cam
end

--- Moves the camera to the given world coordinates.
---@param x number
---@param y number
function camera:setPosition(x, y)
    self.x = x
    self.y = y
end

--- Sets the stored width and height of the camera.
---@param x number
---@param y number
function camera:setSize(x, y)
    self.w = x
    self.h = y
end

--- Sets the horizontal and vertical zoom factors.
---@param x number
---@param y number
function camera:setScale(x, y)
    self.xscale = x
    self.yscale = y
end

--- Clamps the camera position inside the given world rectangle.
---@param min_x number
---@param min_y number
---@param max_x number
---@param max_y number
function camera:setBounds(min_x, min_y, max_x, max_y)
    self.min_x = min_x
    self.min_y = min_y
    self.max_x = max_x
    self.max_y = max_y
end

--- Clamps the camera position inside a rectangle described by its center and size.
---@param x number
---@param y number
---@param width number
---@param height number
function camera:setBoundsBox(x, y, width, height)
    self.min_x = x - width * 0.5
    self.min_y = y - height * 0.5
    self.max_x = x + width * 0.5
    self.max_y = y + height * 0.5
end

--- Removes all position limits by expanding the bounds to infinity.
function camera:unBounds()
    self.min_x = -math.huge
    self.max_x = math.huge
    self.min_y = -math.huge
    self.max_y = math.huge
end

--- Sets the rotation of the camera in radians.
---@param r number|nil
function camera:setAngle(r)
    self.r = (r or 0)
end

--- Starts a screen shake with the given strength, frame duration and decay flag.
---@param mag number|nil
---@param duration number|nil
---@param decay boolean|nil
function camera:shake(mag, duration, decay)
    self.shaker = {
        mag = (mag or 3),
        duration = (duration or 10),
        decay = (decay ~= false)
    }

    self.shaker._start = self.shaker.mag
    self.shaker._time = self.shaker.duration
end

--- Updates the camera size, applies bounds and advances the shake effect.
---@param dt number
function camera:Update(dt)
    self.w = self.xscale * CANVAS_WIDTH
    self.h = self.yscale * CANVAS_HEIGHT
    self.x = math.max(self.min_x or -math.huge, math.min(self.x, self.max_x or math.huge))
    self.y = math.max(self.min_y or -math.huge, math.min(self.y, self.max_y or math.huge))

    local _s = self.shaker
    if (_s._time > 0) then
        _s._time = _s._time - 1
        if (_s.decay) then
            _s.mag = _s.mag - (_s._start / _s.duration)
        end

        _s.x = _s.mag * math.random(-1, 1)
        _s.y = _s.mag * math.random(-1, 1)
    end
end

--- Pushes the current transform and applies the camera translation, rotation and scale.
function camera:apply()
    SE.graphics.push()
    SE.graphics.translate(CANVAS_WIDTH * 0.5, CANVAS_HEIGHT * 0.5)
    SE.graphics.rotate(math.rad(self.r))
    SE.graphics.scale(1 / self.xscale, 1 / self.yscale)
    SE.graphics.translate(-self.x - self.shaker.x, -self.y - self.shaker.y)
end

--- Pops the transform stack, undoing the effect of `apply`.
function camera:unload()
    SE.graphics.pop()
end

--- Restores the camera to its default position, size, rotation, scale and bounds.
function camera:reset()
    self.min_x = nil
    self.min_y = nil
    self.max_x = nil
    self.max_y = nil

    self.x = CANVAS_WIDTH / 2
    self.y = CANVAS_HEIGHT / 2
    self.w = CANVAS_WIDTH
    self.h = CANVAS_HEIGHT
    self.r = 0
    self.xscale = 1
    self.yscale = 1
end

return camera
