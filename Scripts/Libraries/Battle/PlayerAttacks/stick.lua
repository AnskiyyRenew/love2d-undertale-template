local atk = {_end = false, _max = false}
local enemy = {}
local attacked = false
local damage = -999
local missed = false
local time = 0

function atk.Restart(_enemy)
    atk._end = false
    time = 0
    enemy = _enemy
    attacked = false
    missed = false

    local target = Sprites.CreateSprite("UI/Battle Screen/spr_target_0.png", "UponArena")
    target.y = 320
    atk.target = target

    local bar = Sprites.CreateSprite("UI/Battle Screen/Player Attack/spr_targetchoice_0.png", "UponArena")
    bar.y = 320

    local randomer = (math.random() <= 0.5)
    bar._rand = randomer
    bar.x = (randomer and 320 - 280 or 320 + 280)
    bar.velocity.x = (randomer and 6 or -6)
    bar:SetAnimation({
        "UI/Battle Screen/Player Attack/spr_targetchoice_1.png",
        "UI/Battle Screen/Player Attack/spr_targetchoice_0.png"
    }, 0.1)
    atk.bar = bar
end

function atk.SetMaxDamage(dmg)
    atk._max = true
    damage = dmg
end

-- Interface pulled out by this attack pattern: signal that the targeted enemy
-- has been hit. The battle system dispatches to the enemy's animation Hurt()
-- based on enemy.id, so this attack never couples to a specific animation.
function atk.Hurt()
    if (not enemy or not enemy.id) then
        return
    end

    if (enemy.animation and enemy.animation.Hurt) then
        enemy.animation:Hurt()
    end
end

function atk.Destroy()
    atk.bar:Destroy()
    atk.target:Destroy()

    atk._end = true
end

function atk.Update(dt)
    local bar = atk.bar
    local tar = atk.target
    if (not bar or not tar) then return end

    if (not attacked) then
        if (bar.x < 320 - 280 or bar.x > 320 + 280) then
            bar.velocity.x = 0
            bar.alpha = 0
            attacked = true
            missed = true
        end
        if (Keyboard.GetState("confirm") == 1) then
            -- Calculate
            bar.velocity.x = 0
            local bonus_factor = math.abs(bar.x - tar.x)
            if (not atk._max) then
                if (bonus_factor <= 12) then -- Perfect
                    damage = math.ceil(enemy.maxdamage + math.random(0, enemy.dmg_float))
                else
                    damage = math.max(enemy.maxdamage * 0.2, math.ceil(0.9 * (enemy.maxdamage) * (280 - bonus_factor) / 280))
                end
            end

            -- Slice.
            Audio.PlaySound("snd_slice.wav")
            local slice = Sprites.CreateSprite("UI/Battle Screen/Player Attack/spr_slice_o_0.png", "TopAll")
            slice:SetAnimation({
                "UI/Battle Screen/Player Attack/spr_slice_o_1.png",
                "UI/Battle Screen/Player Attack/spr_slice_o_2.png",
                "UI/Battle Screen/Player Attack/spr_slice_o_3.png",
                "UI/Battle Screen/Player Attack/spr_slice_o_4.png",
                "UI/Battle Screen/Player Attack/spr_slice_o_5.png",
            }, 1 / 6, "empty")
            slice:MoveTo(enemy.position[1], enemy.position[2])

            attacked = true
        end
    else
        atk._missed = missed
        atk._attacked = attacked

        time = time + 1
        if (not missed) then
            if (time == 70) then
                if (damage > 0) then
                    Audio.PlaySound("snd_damage.wav")
                    local _start = enemy.hp / enemy.maxhp * 100
                    local _target = (enemy.hp - damage) / enemy.maxhp * 100
                    UI.newMonsterBar({enemy.position[1], enemy.position[2]}, _start, _target)

                    -- Trigger the targeted enemy's hurt animation (dispatched by id)
                    atk.Hurt()
                end
                UI.newBounceText((damage > 0 and damage or "MISS"), {enemy.position[1], enemy.position[2]})
                enemy.hp = math.max(0, enemy.hp - damage)
                atk._max = false
            elseif (time == 130) then
                atk.Destroy()
            end
        else
            if (time == 1) then
                UI.newMissText("MISS", {enemy.position[1], enemy.position[2]})
            elseif (time == 30) then
                atk.Destroy()
            end
        end
    end
end


return atk