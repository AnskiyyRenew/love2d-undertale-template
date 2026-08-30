local step = {
    time = 0
}

local rho = 1
local time_target = math.huge
local _run = true
function step.Init(flag, start, range, amount)
    if (FLAG[flag] >= amount) then
        time_target = 60
        _run = false
        return
    end

    local _f = FLAG[flag]
    rho = math.min(8, amount / (amount - _f))
    time_target = rho * (start + math.random(range))
    print(time_target, rho, start, range)
end

function step.UpdateTime()
    step.time = step.time + 1

    if (not _run) then
        if (step.time >= time_target and not Global.GetVariable("OVERWORLD_NOBODYCAME")) then
            Global.SetVariable("OVERWORLD_NOBODYCAME", true)
            Overworld.SetBattleScene("Battle.scene_battle_ow", "NobodyCame")
            Overworld.Encounter()
        end
    end
end

function step.Update()
    if (not _run) then return end
    if (step.time >= time_target) then
        -- encounter
        Overworld.Encounter()
        step.time = 0
    end
end

return step