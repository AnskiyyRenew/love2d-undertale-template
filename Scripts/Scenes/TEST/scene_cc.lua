local scene = {}

local c = Typers.CCAdd("TEST TEXT", 320, 240, 0, "center", function (self)
    self.time = self.time + 1
    if (self.time == 1) then
        Tween.CreateTween(function (v)
            self.inst.alpha = v
        end, "Linear", "", 0, 1, 40)
        Tween.CreateTween(function (v)
            self.inst.alpha = v
        end, "Linear", "", 1, 0, 40, 70)
        Tween.CreateTween(function (v)
            self.inst.y = v
        end, "Quad", "Out", self.inst.y, self.inst.y - 30, 50)
        Tween.CreateTween(function (v)
            self.inst.y = v
        end, "Quad", "In", self.inst.y - 30, self.inst.y - 60, 50, 70)
    end
end)

function scene.update(dt)
end

function scene.draw()
end

function scene.clear()
    Layers.clear()
end

return scene