local scene = {}

--[[

Characters/Papyrus/Face/spr_face_papyrus_0.png
Characters/Papyrus/Face/spr_face_papyrus_1.png

]]

-- ── NText — bubble via show_bubble=true ──
local text1 = Typers.NText.New({
    "&* Hello World! 你好世界^",
    "&* Second sentence: 第二句话。",
}, {80, 20}, 0, {640, 100}, {
    {
        color = {0.7, 0.3, 1},
        effect = {name = "shake", intensity = 2},
    },
    {
        color = {0, 1, 0},
    },
}, "manual", true)

-- ── EText — bubble via [showbubble:left,0.5] tag ──
local text2 = Typers.EText.New({
    "[showbubble:left,0.1][colorRGB:178, 76, 255][effect:shake, 2]* Hello World! 你好世界",
    "[colorRGB:0, 255, 0]* Second sentence: 第二句话。",
}, {80, 120}, 0, {640, 100})

-- ── SText — bubble via self:showBubble(true) ──
local text3 = Typers.SText.New(function(self)
    self:showBubble(true, "left", 0.5)
    self:setColor(0.7, 0.3, 1)
    self:setEffect("shake", 2)
    self:addText("* Hello World! 你好世界")
    self:nextSentence()

    self:showBubble(false)
    self:setColor(0, 1, 0)
    self:addText("* Second sentence: 第二句话。")
end, {80, 220}, 0, {640, 100})

local t = Typers.InstText.New("Test instant 之 超级瞬间文本", {320, 400})
t:SetAlign("center")

-- ── EText — portrait 测试（Papyrus 大头，打字时播放口型动画） ──
-- 用法： [portrait:图片1, 图片2, ...|每帧间隔|模式]
-- 模式默认 "looponce"：每次打一个字播放一遍序列，随后回到第一张图。
local text4 = Typers.EText.New({
    "[portrait:Characters/Papyrus/Face/spr_face_papyrus_0.png, Characters/Papyrus/Face/spr_face_papyrus_1.png][colorHEX:ffffff]* 我是Papyrus！\n  我说话的时候，\n  左边的大头图会跟着动嘴～",
    "[colorHEX:ffff00]* 换行后文字\n  依旧从右移80像素的位置继续打字。",
}, {80, 320}, 0, {640, 100})

function scene.load()
end

function scene.update(dt)
end

function scene.draw()
end

function scene.keypressed(key)
end

function scene.clear()
    --Typers.ClearAll()
    Layers.clear()
end

return scene
