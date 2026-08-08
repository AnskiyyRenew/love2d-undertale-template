local scene = {}
local shop = ImportFile("Overworld.shop")
shop.SetMainText("* 哇咔咔咔。\n* 补牙补牙补牙。")

local bg = shop.GetBackground()
bg:Scale(640, 480)
bg.color = {0.1, 0.3, 0.3}

function scene.update(dt)
end

function scene.draw()
end

function scene.clear()
    Layers.clear()
end

return scene