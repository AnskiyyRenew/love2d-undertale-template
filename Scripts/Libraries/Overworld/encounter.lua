local step = {
    time = 0
}

local rho = 1
local time_target = 999
function step.Init(flag, start, range, amount)
    rho = math.min(8, amount / (amount - flag))
    time_target = rho * (start + math.random(range))
    print(time_target, rho, start, range)
end

function step.UpdateTime()
    step.time = step.time + 1
end

function step.Update()
    if (step.time >= time_target) then
        -- encounter
        Overworld.Encounter()
        step.time = 0
    end
end

return step