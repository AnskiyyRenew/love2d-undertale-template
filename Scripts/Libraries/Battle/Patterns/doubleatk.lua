local template = {}
template.Elements = {}
template.enemy = nil
template.finalHurt = 0

-- 用于两次判定
local hits = 0      -- 已经按了几次（最多 2）
local damages = {0, 0}

function template.GetMaxDamage()
    return template.enemy.maxdamage
end

function template.Create()
    template.Elements = {}
    template.finalHurt = 0
    hits = 0
    damages[1], damages[2] = 0, 0

    -- center target
    local target = sprites.CreateSprite("UI/Battle Screen/spr_target_0.png", 12)
    target:MoveTo(320, 320)
    table.insert(template.Elements, target)

    -- 第一条
    local bar1 = sprites.CreateSprite("UI/Battle Screen/Player Attack/spr_targetchoice_0.png", 16)
    bar1.y = 320
    bar1:SetAnimation({
        "UI/Battle Screen/Player Attack/spr_targetchoice_1.png",
        "UI/Battle Screen/Player Attack/spr_targetchoice_0.png"
    }, 5)
    bar1.x = 320 + 280
    bar1.velocity.x = -6
    table.insert(template.Elements, bar1)

    -- 第二条先不动，第二次按键才启动
    local bar2 = sprites.CreateSprite("UI/Battle Screen/Player Attack/spr_targetchoice_0.png", 16)
    bar2:SetAnimation({
        "UI/Battle Screen/Player Attack/spr_targetchoice_1.png",
        "UI/Battle Screen/Player Attack/spr_targetchoice_0.png"
    }, 5)
    bar2.y = 320
    bar2.x = 280
    bar2.velocity.x = 0
    bar2.alpha = 0.3 -- 半透明提示
    table.insert(template.Elements, bar2)
end

function template.Update(dt)
    if not template.enemy then return end

    local target = template.Elements[1]
    local bar1 = template.Elements[2]
    local bar2 = template.Elements[3]

    if keyboard.GetState("confirm") == 1 then
        if hits == 0 then
            -- 第一次按
            hits = 1
            bar1.velocity.x = 0

            damages[1] = template.CalcDamage(target, bar1)

            -- 激活第二条
            bar2.alpha = 1
            bar2.velocity.x = 6

            audio.PlaySound("snd_slice.wav")

        elseif hits == 1 then
            -- 第二次按
            hits = 2
            bar2.velocity.x = 0

            damages[2] = template.CalcDamage(target, bar2)

            audio.PlaySound("snd_slice.wav")

            -- 储存最终伤害并结束
            template.finalHurt = math.max(0, damages[1] + damages[2])
        end
    end
end

-- 独立出一个计算器，便于阅读
function template.CalcDamage(target, bar)
    local dmg = template.GetMaxDamage() or 0
    local absLength = math.abs(bar.x - target.x)

    if absLength > 5 then
        dmg = math.ceil(dmg * 0.9 * (1 - absLength / 280))
    end
    return dmg
end

function template.Reset()
    template.finalHurt = 0
    hits = 0
    damages[1], damages[2] = 0, 0
end

function template.Destroy()
    for i = #template.Elements, 1, -1 do
        local s = template.Elements[i]
        if s and s.Destroy then s:Destroy() end
        table.remove(template.Elements, i)
    end
    template.Elements = {}
end

return template
