local scene = {}
local shop = ImportFile("Overworld.shop")
shop.SetMainText("* 哇咔咔咔。\n* 补牙补牙补牙。")
shop.SetGoods({"CrabApple", "HotCat", "CrabApple", "HotCat", "CrabApple", "HotCat"})
shop.SetPrice("CrabApple", 7)
shop.SetPrice("HotCat", 18)

local bg = shop.GetBackground()
bg:Scale(2, 2)
bg:SetAnimation({
    "Scene/Waterfall/spr_starpattern_0.png",
    "Scene/Waterfall/spr_starpattern_1.png",
    "Scene/Waterfall/spr_starpattern_2.png",
    "Scene/Waterfall/spr_starpattern_3.png",
}, 0.1)

function scene.update(dt)
    shop.Update(dt)
end

function scene.draw()
end

function scene.clear()
    shop.Clear()
    Layers.clear()
end

return scene