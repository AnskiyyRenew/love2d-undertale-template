local beat = {
    events = {},

    next_check_beat = 1
}
beat.bpm = 120
beat.beat = 0
beat.offset = 0

local time = 0
--- Queues a callback to fire once the given beat, plus an optional offset, is reached.
---@param target number
---@param call function
---@param offset number|nil
function beat.CreateEvent(target, call, offset)
    table.insert(beat.events, {
        _target = target,
        _call = call,
        _offset = offset or beat.offset
    })
end

--- Advances the beat counter and fires every event whose target has been passed.
---@param dt number
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

--- Sets the tempo in beats per minute, defaulting to 120.
---@param bpm number|nil
function beat.SetBPM(bpm)
    beat.bpm = (bpm or 120)
end

--- Reports whether the current beat exactly matches the given beat number.
---@param target number
---@return boolean
function beat.OnBeat(target)
    local bool = false

    if (beat.beat == target) then
        bool = true
    end

    return bool
end

return beat
