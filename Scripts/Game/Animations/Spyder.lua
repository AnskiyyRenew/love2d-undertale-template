local anim = {
    running = true,
    x = 0,
    y = 0,
    elements = {},

    lines = {},
    center = {520, 0},
    angle = 0,
    length = 0,

    time = 0,

    js = false
}

local function direction(x, y, tx, ty, offset)
    return math.deg(math.atan2(ty - y, tx - x)) + offset
end

local function distance(x, y, tx, ty)
    return math.sqrt((x - tx) ^ 2 + (y - ty) ^ 2)
end

-- Create the sprites.
function anim.Init()
    local spider = Sprites.CreateSprite("Mascots/spyder.png", "UI")
    spider:Scale(2, 2)
    spider.color = {0.5, 0.5, 1}
    spider:MoveTo(520, -40)
    Tween.CreateTween(function (v)
        anim.angle = v
    end, "Elastic", "Out", 0, 90, 300, 0, 210)
    Tween.CreateTween(function (v)
        anim.length = v
    end, "Elastic", "Out", 0, 140, 240)
    anim.spider = spider
    table.insert(anim.elements, spider)
end

function anim.JumpScare()
    local spider = Sprites.CreateSprite("Mascots/spyder.png", "UI")
    spider:Scale(1, 1)
    spider:MoveTo(320, 320)
    Tween.CreateTween(function (v)
        spider.y = v
    end, "Quad", "Out", 320, 230, 60)
    Tween.CreateTween(function (v)
        spider.xscale = v
        spider.yscale = v
    end, "Quart", "Out", 1, 15, 60, 120)
    spider._time = 0
    spider._g = -3
    spider.Step = function (self)
        if (self._time == 60) then
            self.layer = 1000
        end
        self._time = self._time + 1
        if (self._time >= 120) then
            self._g = self._g + 0.5
            self.y = self.y + self._g
        end

        if (self._time >= 300) then
            self:Destroy()
        end
    end
end

function anim.Line(x, y)
    if (not anim.spider) then return end
    local line = Sprites.CreateSprite("px.png", anim.spider.layer - 1)
    line:MoveTo(x, y)
    line.xscale = 2
    line.color = {0.4, 0, 1}
    line.ypivot = 0
    line.Step = function (self)
        local _x = anim.center[1] + anim.length * math.cos(math.rad(anim.angle))
        local _y = anim.center[2] + anim.length * math.sin(math.rad(anim.angle))
        self.rotation = direction(self.x, self.y, _x, _y, -90)
        self.yscale = distance(self.x, self.y, _x, _y)
    end

    return line
end

function anim.Bounce()
    Tween.CreateTween(function (v)
        anim.length = v
    end, "Quad", "Out", 140, 80, 30)
    Tween.CreateTween(function (v)
        anim.length = v
    end, "Bounce", "Out", 80, 140, 60, 30)
end

function anim.Update(dt)
    if (not anim.running) then
        return
    end

    -- Put your monster's animation code here.
    --===================>
    anim.spider.x = anim.center[1] + anim.length * math.cos(math.rad(anim.angle))
    anim.spider.y = anim.center[2] + anim.length * math.sin(math.rad(anim.angle))
    anim.spider.rotation = anim.angle + 90

    anim.time = anim.time + 1
    anim.length = 140 + 5 * math.sin(math.rad(anim.time - 60) * 2)
    anim.angle = 90 + 1 * math.sin(math.rad(anim.time) * 5)
    --<===================
end

-- Destroy the anim.
-- You can also use `sprite:Dust` function here.
function anim.Destroy()
    for i = #anim.elements, 1, -1
    do
        local e = anim.elements[i]
        if (e.Destroy) then
            e:Destroy()
        end
    end
end

return anim