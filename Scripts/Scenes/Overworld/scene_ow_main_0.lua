local scene = {}
local ow = ImportFile("Overworld")
ow.Init("Maps/main_scene/main_0.lua")
ow.SetMusic("Start.ogg")
Camera:setBounds(320, 210, 1080, 210)

-- 180, 50
-- 240, 50
-- 300, 50
for i = 1, 3
do
    local sign = Sprites.CreateSprite("Scene/True Lab/spr_monitor_dark_0.png", "Map")
    sign:Scale(2, 2)
    sign:MoveTo(200 + i * 160, 100)
    sign._triggered = false
    sign._i = i
    sign.Step = function (self)
        if (ow.getTouchResult("trigger", self._i, "rr")) then
            if (not self._triggered) then
                self:SetAnimation({
                    "Scene/True Lab/spr_monitor_lit_0.png",
                    "Scene/True Lab/spr_monitor_lit_1.png",
                    "Scene/True Lab/spr_monitor_lit_2.png",
                    "Scene/True Lab/spr_monitor_lit_3.png",
                }, 0.2)
                self._triggered = true
            end
        else
            self:Set("Scene/True Lab/spr_monitor_dark_0.png")
            self._triggered = false
        end
    end
end

local poseur = Sprites.CreateSprite("poseur.png", "UponPlayer")
poseur.ypivot = 1
poseur._fly = false
poseur:Scale(0.5, 0.5)
poseur.Step = function (self)
    if (self._fly) then
        self.velocity = {
            x = 3,
            y = 3,
            r = 8
        }

        if (self.x >= Camera.x + 640) then
            self:Destroy()
        end
    end
end
local obj = ow.FindObject("trigger", 7)
if (obj) then
    poseur:MoveTo(obj.x, obj.y + 40)
end

local trigger_1 = 0
local trigger_7 = false

function scene.update(dt)
    ow.Update(dt)
    --print(Keyboard.GetMousePosition())

    if (ow.getInteractResult("trigger", 1)) then
        if (Keyboard.GetState("confirm") == 1) then
            if (trigger_1 == 0) then
                ow.dialogNew({
                    "* (You notice a piece of paper\n  tucked under the clock.)",
                    "[colorhex:9900ff]* Hey[wait:0.4], Alphys![wait:0.4]\n* Why did you throw your\n  clock here?",
                    "* Wait- [wait:0.4]that's not my clock.",
                    "[colorhex:9900ff]* But this is 'public' lab\n  property.\n* Do you know what public means?",
                    "* Yes[wait:0.4], of course I do...[wait:0.4]\n* But this one is already broken.", "* And the cost of fixing it is\n  more than buying a new one.",
                    "[colorhex:9900ff]* Alright[wait:0.4], suit yourself."
                })
            else
                ow.dialogNew({
                    "* Nothing useful."
                })
            end
            trigger_1 = trigger_1 + 1
        end
    end

    if (ow.getInteractResult("trigger", 2)) then
        if (Keyboard.GetState("confirm") == 1) then
            ow.dialogNew({
                "Entry Number 01: ",
                "[colorhex:990000]* Hacked by someone."
            })
        end
    elseif (ow.getInteractResult("trigger", 3)) then
        if (Keyboard.GetState("confirm") == 1) then
            ow.dialogNew({
                "Entry Number 02: ",
                "* The leftmost door leads to the\n  shop.",
                "* Though there's also a working\n  vending machine here.",
                "* The three doors on the right\n  lead to unknown directions\n  (currently unknown).",
                "[colorhex:9900ff]* Alphys[wait:0.4], why you write this\n  on the board?",
            })
        end
    elseif (ow.getInteractResult("trigger", 4)) then
        if (Keyboard.GetState("confirm") == 1) then
            print("triggering")
            local d = ow.dialogNew({
                "Entry Number 03: ",
                "[colorhex:ff0000]* Determination.",
                "[colorhex:9900ff]* Alphys[wait:0.4], how many times have I\n  warned you[wait:0.4], this board is NOT\n  for writing scary things on.",
                "* Huh?[wait:0.4] I didn't write that.",
                "[colorhex:9900ff]* Could it be...?",
                "[font:Wingdings.ttf]GOT YOU BOTH.\nSTILL DARING TO WRITE\nNONSENSE\nON THE BOARD."
            })
        end
    elseif (ow.getInteractResult("trigger", 5)) then
        if (Keyboard.GetState("confirm") == 1) then
            ow.dialogNew({
                "* This might be the vending\n  machine.",
                "* Oops[wait:0.4], it's not working.",
                "* It looks like no one has\n  restocked the vending machine\n  for a long time..."
            })
        end
    elseif (ow.getInteractResult("trigger", 7) and not trigger_7) then
        if (Keyboard.GetState("confirm") == 1) then
            poseur._fly = true
            trigger_7 = true
        end
    end

    if (ow.getInteractResult("sign", 1)) then
        if (Keyboard.GetState("confirm") == 1) then
            ow.dialogNew({
                "* SOL, SINCERA and SPYDER"
            })
        end
    end

    if (ow.getInteractResult("warp", 1)) then
        ow.ChangeScene("Overworld.Shops.scene_shop_0")
    elseif (ow.getInteractResult("warp", 2)) then
        ow.ChangeScene("Overworld.scene_sol")
    end
end

function scene.draw()
    ow.Draw()
end

function scene.clear()
    ow.Clear()
    package.loaded["Scripts.Libraries.Overworld"] = nil
    Layers.clear()
end

return scene