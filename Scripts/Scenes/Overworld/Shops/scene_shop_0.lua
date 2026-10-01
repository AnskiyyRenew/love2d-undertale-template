local scene = {}
local shop = ImportFile("Overworld.shop")
shop.SetMainText("* 哇咔咔咔。\n* 补牙补牙补牙。")
shop.SetEndText("* 下次再来哦。")

shop.SetGoods({"CrabApple", "HotCat"})
shop.SetAmount("CrabApple", 4)
shop.SetBuyPrice("CrabApple", 7)
shop.SetBuyPrice("HotCat", 18)

shop.SetBuyOpinion("CrabApple", "I\nmade\nthis.")
shop.SetBuyOpinion("HotCat", "It's a cat.\nIt's hot.")
shop.SetIntroduction("CrabApple", "+20 HP")
shop.SetIntroduction("HotCat", "+12 HP")

shop.SetSellable(true)
shop.SetSellPrice("CrabApple", 3)

shop.AddTalk("天气", {"* 今天也一如既往。", "* 明天大概也一样。"})
shop.AddTalk("时间", "* 地下没有白天和黑夜。\n* 所以时间只是个概念。")
shop.AddTalk("这家店", "* 这家店开了很久了。\n* 大概。")
shop.SetQueue("天气", "时间")
shop.SetTalkOpinion("想聊点什么？")
shop.SetTalkOpinion("天气", "又聊天气？")
shop.SetTalkOpinion("这家店", {"这家店啊……", "开了很久了。大概。"})

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
