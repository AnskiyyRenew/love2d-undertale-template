local camera = {}
camera.__index = camera

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

function camera:setPosition(x, y)
    self.x = x
    self.y = y
end

function camera:setSize(x, y)
    self.w = x
    self.h = y
end

function camera:setScale(x, y)
    self.xscale = x
    self.yscale = y
end

function camera:setBounds(min_x, min_y, max_x, max_y)
    self.min_x = min_x
    self.min_y = min_y
    self.max_x = max_x
    self.max_y = max_y
end

function camera:setBoundsBox(x, y, width, height)
    self.min_x = x - width * 0.5
    self.min_y = y - height * 0.5
    self.max_x = x + width * 0.5
    self.max_y = y + height * 0.5
end

function camera:unBounds()
    self.min_x = -math.huge
    self.max_X = math.huge
    self.min_y = -math.huge
    self.max_y = math.huge
end

function camera:setAngle(r)
    self.r = (r or 0)
end

function camera:shake(mag, duration, decay)
    self.shaker = {
        mag = (mag or 3),
        duration = (duration or 10),
        decay = (decay ~= false)
    }

    self.shaker._start = self.shaker.mag
    self.shaker._time = self.shaker.duration
end

function camera:Update(dt)
    self.w = self.xscale * CANVAS_WIDTH
    self.h = self.yscale * CANVAS_HEIGHT
    self.x = math.max(self.min_x or -math.huge, math.min(self.x, self.max_x or math.huge))
    self.y = math.max(self.min_y or -math.huge, math.min(self.y, self.max_y or math.huge))

    -- shaker
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

function camera:apply()
    SE.graphics.push()
    SE.graphics.translate(CANVAS_WIDTH * 0.5, CANVAS_HEIGHT * 0.5)
    SE.graphics.rotate(math.rad(self.r))
    SE.graphics.scale(1 / self.xscale, 1 / self.yscale)
    SE.graphics.translate(-self.x - self.shaker.x, -self.y - self.shaker.y)
end

function camera:unload()
    SE.graphics.pop()
end

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