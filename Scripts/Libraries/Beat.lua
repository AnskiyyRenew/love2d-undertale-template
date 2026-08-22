local beat = {
    events = {},

    next_check_beat = 1
}
beat.bpm = 120
beat.beat = 0
beat.offset = 0

local time = 0
function beat.CreateEvent(target, call, offset)
    table.insert(beat.events, {
        _target = target,
        _call = call,
        _offset = offset or beat.offset
    })
end

function beat.Update(dt)
    time = time + dt
    beat.beat = beat.beat + dt * beat.bpm / 60

    for i = #beat.events, 1, -1
    do
        local e = beat.events[i]
        local offset_beats = e._offset / 1000 * beat.bpm / 60
        if (beat.beat >= e._target + offset_beats) then
            e._call()
            table.remove(beat.events, i)
        end
    end
end

function beat.SetBPM(bpm)
    beat.bpm = (bpm or 120)
end

function beat.OnBeat(target)
    local bool = false

    if (beat.beat == target) then
        bool = true
    end

    return bool
end

return beat