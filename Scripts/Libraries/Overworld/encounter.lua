local step = {
    time = 0
}

local rho = 1
local time_target = math.huge
local _run = true
--- Configures the encounter timer from the current flag progress.
---@param flag string
---@param start number
---@param range number
---@param amount number
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

--- Advances the idle timer and starts the nobody-came battle once it expires.
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

--- Advances the encounter timer and spawns a battle when it reaches the target.
function step.Update()
    if (not _run) then return end
    if (step.time >= time_target) then
        Overworld.Encounter()
        step.time = 0
    end
end

return step