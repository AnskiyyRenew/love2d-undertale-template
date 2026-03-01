-- template.lua (示例 pattern)
local template = {}
template.Elements = {}     -- pattern 用来保存自己创建的 sprites
template.enemy = nil       -- Battle 会把当前 enemy 赋过来
template.finalHurt = 0
template._has_sliced = false
template._end = false

-- 可选：告诉 Battle 这个 pattern 的最大基础伤害
function template.GetMaxDamage()
    return template.enemy.maxdamage
end

-- Create: 在进入 ATTACKING 时被调用一次，创建 target/bar 等可视元素
function template.Create()
    template._has_sliced = false
    template.finalHurt = 0
    template.Elements = {}

    -- target（示例）
    local target = sprites.CreateSprite("UI/Battle Screen/spr_target_0.png", 12)
    target.y = 320
    target:MoveTo(320, target.y)
    table.insert(template.Elements, target)

    -- moving bar（示例）
    local bar = sprites.CreateSprite("UI/Battle Screen/Player Attack/spr_targetchoice_0.png", 16)
    bar.y = 320
    bar:SetAnimation({
        "UI/Battle Screen/Player Attack/spr_targetchoice_1.png",
        "UI/Battle Screen/Player Attack/spr_targetchoice_0.png"
    }, 5)
    -- 随机左右出发，保持与原逻辑兼容
    local pos = math.random(1, 2)
    if pos == 1 then
        bar.x = 320 + 280
        bar.velocity.x = -6
        bar.newPosvar = 2
    else
        bar.x = 320 - 280
        bar.velocity.x = 6
        bar.newPosvar = 1
    end
    table.insert(template.Elements, bar)
end

function template.Update(dt)
    -- 如果没有 enemy（极端情况），直接返回
    if not template.enemy then return end

    -- 如果玩家按下 confirm（这里只用示例的 keyboard.GetState，和 Battle 一致）
    if keyboard.GetState("confirm") == 1 and not template._has_sliced then
        template._has_sliced = true
        template._end = true
        print("ATTACKED BY LIBRARY")

        -- 播声音并生成 slice 特效，放在 enemy 的当前位置
        audio.PlaySound("snd_slice.wav")
        local slice = sprites.CreateSprite("UI/Battle Screen/Player Attack/spr_slice_o_0.png", 18)
        slice:SetAnimation({
            "UI/Battle Screen/Player Attack/spr_slice_o_1.png",
            "UI/Battle Screen/Player Attack/spr_slice_o_2.png",
            "UI/Battle Screen/Player Attack/spr_slice_o_3.png",
            "UI/Battle Screen/Player Attack/spr_slice_o_4.png",
            "UI/Battle Screen/Player Attack/spr_slice_o_5.png"
        }, 10, "oneshot-empty")

        -- 使用实时 enemy 位置
        local e = template.enemy
        if e and e.position then
            slice:MoveTo(e.position.x, e.position.y)
        else
            slice:MoveTo(320, 320) -- 回退到中心，避免崩溃
        end
        table.insert(template.Elements, slice)

        -- 计算伤害（示例：基于 bar 与 target 的距离）
        local damage = template.GetMaxDamage() or 0
        local tar = template.Elements[1]
        local bar = template.Elements[2]
        bar.velocity.x = 0  -- 停止移动
        if tar and bar and bar.x and tar.x then
            local absLength = math.abs(bar.x - tar.x)
            if absLength > 5 then
                damage = math.ceil(damage * 0.9 * (1 - absLength / 280))
            end
        end

        -- 将最终伤害写回 pattern，Battle 将在结算时使用它
        template.finalHurt = damage
    end

    -- 检测 bar 越界，判定为不攻击，直接输出 0 伤害
    local bar = template.Elements[2]
    if bar and (bar.x < 40 or bar.x > 600) and not template._has_sliced then
        template._has_sliced = true
        template._end = true
        template.finalHurt = -999
        bar.velocity.x = 0
    end
end

function template.Reset()
    template.finalHurt = 0
    template._has_sliced = false
    template._end = false
end

-- Destroy: 当 Battle 清理 pattern 或攻击结束时，销毁所有元素
function template.Destroy()
    for i = #template.Elements, 1, -1 do
        local s = template.Elements[i]
        if s and s.Destroy then s:Destroy() end
        table.remove(template.Elements, i)
    end
    template.Elements = {}
end

return template
