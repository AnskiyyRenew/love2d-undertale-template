local scene = {}

local background = Sprites.CreateSprite("px.png", -1000)
background:Scale(640, 480)
background.color = {0.2, 0.2, 0.2}

local poseur = Sprites.CreateSprite("poseur.png")
poseur:MoveTo(140, 140)
poseur.Step = function (self, dt)
    self.rotation = self.rotation + 30 * dt
end

local platform = Sprites.CreateSprite("px.png")
platform:Scale(250, 2)
platform:MoveTo(100, 400)
local water_sprite = Sprites.CreateSprite("px.png")
water_sprite:Scale(640, 0)
water_sprite.y = 480
water_sprite.ypivot = 1
water_sprite.color = {0.4, 1, 1}
water_sprite.alpha = 0.5

local cork = Sprites.CreateSprite("px.png")
cork:Scale(20, 40)
cork.color = {0.8, 0.5, 0.2}
cork.layer = -50
cork:MoveTo(400, 480)

local time = 0
print("Time: ", time)
print(poseur)
function scene.update(dt)
    time = time + 1

    platform:MoveTo(Keyboard.GetMousePosition())
    if (time % 1 == 0) then
        local rain = Sprites.CreateSprite("px.png", -100)
        rain:MoveTo(math.random(20, 720), -10)
        rain:Scale(1, math.random(10, 15))
        rain.ypivot = 1
        rain.color = {0.4, 1, 1}
        rain.rotation = 20
        rain.Step = function (self, dt)
            rain:Move(-math.sin(math.rad(self.rotation)) * 1 * self.yscale, math.cos(math.rad(self.rotation)) * 1 * self.yscale)
            if (self.x > platform.x - platform.xscale / 2 and self.x < platform.x + platform.xscale / 2 and self.y >= platform.y - platform.yscale / 2 and self.y <= platform.y + platform.yscale / 2 + 15) then
                local dot = Sprites.CreateSprite("px.png", -100)
                dot:MoveTo(self.x, platform.y - platform.yscale / 2)
                dot:Scale(2, 2)
                dot.color = self.color
                dot._spd = -2
                dot.vx = math.random(-10, 10) / 10
                dot.Step = function (s, dt)
                    s._spd = s._spd + 0.1
                    s:Move(s.vx, s._spd)
                    s.alpha = s.alpha - 0.01
                    if (s.alpha <= 0) then
                        s:Destroy()
                    end
                end
                self:Destroy()
            end
            if (self.y > water_sprite.y - water_sprite.yscale) then
                self:Destroy()
            end
        end
    end

    if (time <= 1500 and time >= 300) then
        water_sprite:Scale(640, (time - 300) / 10)
    end

    if (time == 1500) then
        water_sprite:Scale(640, 120)
    end

    if (time == 1800) then
        Tween.CreateTween(function (v)
            cork.y = v
        end, "Quad", "Out", cork.y, 480 - 120, 120)
        Tween.CreateTween(function (v)
            cork.y = v
        end, "Quad", "InOut", 480 - 120, 480, 120, 180)
    end
    if (time >= 1800 and time < 2000) then
        water_sprite.yscale = (2000 - time) * 120 / 200
    end
    if (time == 2000) then
        water_sprite.yscale = 0
        time = 0
    end
end

function scene.draw()
end

function scene.clear()
    Layers.clear()
end

return scene