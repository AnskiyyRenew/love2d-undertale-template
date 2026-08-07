local scene = {}
local mus, ins = Audio.PlayMusic("End.ogg", 0, true)
ins:VolumeTransition(0, 1, 3)

local leaving = false
local alpha = 0

local t = Typers.InstText.New("Thanks for Playing!", {320, 220}, 1)
t.alpha = 0
t:SetAlign("center")

local strs = {
    "Start.ogg made by Anskiyy",
    "End.ogg made by Anskiyy",
    "HOWEVER I'M BAD AT THESE↑",
    "I'M TEST TEXT TEST.",
    "NYEH HEH HEH"
}
local _ts = {}
for i = 1, #strs
do
    local _t = Typers.InstText.New(strs[i], {320, 480}, 1)
    _t:SetAlign("center")
    table.insert(_ts, _t)
end

local black = Sprites.CreateSprite("px.png", 10)
black:Scale(640, 480)
black.color = {0, 0, 0}
black.alpha = 0

local time = 0
function scene.update(dt)
    time = time + 1

    if (not leaving) then
        alpha = math.min(0.5, alpha + 0.002)
        t.alpha = t.alpha + 0.02

        local rain = Sprites.CreateSprite("px.png", 0)
        rain.alpha = alpha
        rain:MoveTo(math.random(20, 720), -10)
        rain:Scale(1, math.random(10, 15))
        rain.ypivot = 1
        rain.rotation = 20
        rain.Step = function (self)
            self.alpha = alpha
            self:Move(-math.sin(math.rad(self.rotation)) * 1 * self.yscale, math.cos(math.rad(self.rotation)) * 1 * self.yscale)
            if (self.y > 500) then
                self:Destroy()
            end
        end

        if (time == 120) then
            Tween.CreateTween(function (v)
                t.y = v
            end, "Quad", "InOut", 220, 60, 60)

            for i = 1, #_ts
            do
                Tween.CreateTween(function (v)
                    _ts[i].y = v
                end, "Back", "Out", _ts[i].y, 150 + 50 * i, 180, 20 + i * 10)
            end
        end

        if (Keyboard.GetState("confirm") == 1) then
            ins:VolumeTransition(1, 0, 3)
            leaving = true
            time = 0
        end
    else
        if (time <= 100) then
            black.alpha = black.alpha + 0.01
        else
            Scenes.switchTo("scene_logo")
        end
    end
end

function scene.draw()
end

function scene.clear()
    Audio.Clear()
    Layers.clear()
end

return scene