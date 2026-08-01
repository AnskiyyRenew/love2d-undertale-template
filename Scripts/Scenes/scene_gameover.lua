local scene = {}

local _spr = Global.GetVariable("PlayerFinalThings")
local heart = Sprites.CreateSprite(_spr.path, 0)
heart:MoveTo(_spr:GetPosition())
heart.color = _spr.color
local gameover = Sprites.CreateSprite("UI/Battle Screen/spr_gameoverbg_0.png", 5)
gameover.y = 120
gameover.alpha = 0

local time = 0
local leave = false
local mus, ins
function scene.update(dt)
    time = time + 1

    if (not leave) then
        if (time == 60) then
            Audio.PlaySound("snd_heartbreak_0.wav")
            heart:Set("Soul Library Sprites/spr_heartbreak_0.png")
        elseif (time == 120) then
            Audio.PlaySound("snd_heartbreak_1.wav")
            for i = 1, 8
            do
                local f = math.random(0, 3)
                local shard = Sprites.CreateSprite("UI/Battle Screen/Shards/spr_heartshards_" .. f .. ".png", 10)
                shard.velocity.x = math.random(-40, 40) / 10
                shard.velocity.y = -math.random(50) / 10
                shard.gravity = 1.5
                shard:SetAnimation(
                    {
                        "UI/Battle Screen/Shards/spr_heartshards_0.png",
                        "UI/Battle Screen/Shards/spr_heartshards_1.png",
                        "UI/Battle Screen/Shards/spr_heartshards_2.png",
                        "UI/Battle Screen/Shards/spr_heartshards_3.png"
                    }, 1 / 6
                )
                shard.animation.frame = f + 1
                shard:MoveTo(heart:GetPosition())
                shard.color = heart.color

                shard.Step = function (self)
                    self.velocity.y = self.velocity.y + 0.1

                    if (self.y >= 500) then
                        self:Destroy()
                    end
                end
            end
            heart:Destroy()
        elseif (time == 180) then
            mus, ins = Audio.PlayMusic("mus_gameover.ogg", 0, true)
            ins:VolumeTransition(0, 1, 1.4)
        elseif (time > 180 and time <= 280) then
            gameover.alpha = gameover.alpha + 0.01
        end

        if (time == 240) then
            local t = Typers.EText.New(Localize.localizeText("Battle.GameoverText", {Player.name}), {120, 300}, 0)
            t._onComplete = function ()
                leave = true
                time = 0
                ins:VolumeTransition(1, 0, 1.4)
            end
        end
    else
        gameover.alpha = gameover.alpha - 0.01

        if (gameover.alpha <= 0) then
            Scenes.switchTo("scene_logo")
        end
    end
end

function scene.draw()
end

function scene.clear()
    Layers.clear()
end

return scene