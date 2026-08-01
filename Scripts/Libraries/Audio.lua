local audio = {
    _path_sound = "Resources/Sounds/",
    _path_music = "Resources/Music/",

    insts = {},
    cache = {}
}

---@param inst table
---@return table
local function attachInstMethods(inst)
    ---@param self table
    ---@param startVolume number
    ---@param targetVolume number
    ---@param duration number
    ---@return table
    function inst:VolumeTransition(startVolume, targetVolume, duration)
        return audio.VolumeTransition(self, startVolume, targetVolume, duration)
    end

    ---@param self table
    ---@param startPitch number
    ---@param targetPitch number
    ---@param duration number
    ---@return table
    function inst:PitchTransition(startPitch, targetPitch, duration)
        return audio.PitchTransition(self, startPitch, targetPitch, duration)
    end

    ---@param self table
    ---@param duration number
    ---@param targetVolume number
    ---@return table
    function inst:FadeIn(duration, targetVolume)
        return audio.FadeIn(self, duration, targetVolume)
    end

    ---@param self table
    ---@param duration number
    ---@param targetVolume number
    ---@return table
    function inst:FadeOut(duration, targetVolume)
        return audio.FadeOut(self, duration, targetVolume)
    end

    ---@param self table
    ---@return table
    function inst:Pause()
        return audio.Pause(self)
    end

    ---@param self table
    ---@return table
    function inst:Resume()
        return audio.Resume(self)
    end

    ---@param self table
    ---@return table
    function inst:Stop()
        return audio.Stop(self)
    end

    ---@param self table
    ---@param introEndTime number
    ---@param outroStartTime number
    ---@return table
    function inst:SetLoopingPoint(introEndTime, outroStartTime)
        return audio.SetLoopingPoint(self, introEndTime, outroStartTime)
    end

    ---@param self table
    ---@return table
    function inst:FollowLoop()
        return audio.FollowLoop(self)
    end

    ---@param self table
    ---@return table
    function inst:FollowOutro()
        return audio.FollowOutro(self)
    end

    return inst
end

---@param inst table
---@param transition table
---@param property string
---@param dt number
---@return boolean
local function updateTransition(inst, transition, property, dt)
    if not inst or not inst.source or not transition then
        return false
    end

    transition.elapsed = transition.elapsed + dt
    local t = transition.duration > 0 and math.min(transition.elapsed / transition.duration, 1) or 1
    local value = transition.from + (transition.to - transition.from) * t

    local ok = pcall(function()
        if property == "volume" then
            inst.source:setVolume(value)
        elseif property == "pitch" then
            inst.source:setPitch(value)
        end
    end)

    if not ok or t >= 1 then
        transition.finished = true
        return true
    end

    return false
end

---@param inst table
---@param startVolume number
---@param targetVolume number
---@param duration number
---@return table
function audio.VolumeTransition(inst, startVolume, targetVolume, duration)
    if not inst then
        return {}
    end

    inst._volume_transition = {
        from = startVolume or 0,
        to = targetVolume or 0,
        duration = duration or 0,
        elapsed = 0,
        finished = false
    }

    if inst.source then
        pcall(function()
            inst.source:setVolume(startVolume or 0)
        end)
    end

    return inst
end

---@param inst table
---@param startPitch number
---@param targetPitch number
---@param duration number
---@return table
function audio.PitchTransition(inst, startPitch, targetPitch, duration)
    if not inst then
        return {}
    end

    inst._pitch_transition = {
        from = startPitch or 1,
        to = targetPitch or 1,
        duration = duration or 0,
        elapsed = 0,
        finished = false
    }

    if inst.source then
        pcall(function()
            inst.source:setPitch(startPitch or 1)
        end)
    end

    return inst
end

---@param inst table
---@param duration number
---@param targetVolume number
---@return table
function audio.FadeIn(inst, duration, targetVolume)
    if not inst then
        return {}
    end

    return audio.VolumeTransition(inst, 0, targetVolume or 1, duration or 0.5)
end

---@param inst table
---@param duration number
---@param targetVolume number
---@return table
function audio.FadeOut(inst, duration, targetVolume)
    if not inst then
        return {}
    end

    local currentVolume = 0
    if inst.source then
        local ok = pcall(function()
            currentVolume = inst.source:getVolume() or 0
        end)
        if not ok then
            currentVolume = 0
        end
    end

    return audio.VolumeTransition(inst, currentVolume, targetVolume or 0, duration or 0.5)
end

---@param inst table
---@return table
function audio.Pause(inst)
    if not inst or not inst.source then
        return {}
    end

    inst.paused = true
    pcall(function()
        inst.source:pause()
    end)

    return inst
end

---@param inst table
---@return table
function audio.Resume(inst)
    if not inst or not inst.source then
        return {}
    end

    inst.paused = false
    pcall(function()
        inst.source:play()
    end)

    return inst
end

---@param inst table
---@return table
function audio.Stop(inst)
    if not inst then
        return {}
    end

    if inst.source then
        pcall(function()
            inst.source:stop()
            inst.source:release()
        end)
    end

    inst.stopped = true
    inst.paused = false

    for i = #audio.insts, 1, -1 do
        if audio.insts[i] == inst then
            table.remove(audio.insts, i)
            break
        end
    end

    return inst
end

---@param inst table
---@param introEndTime number
---@param outroStartTime number
---@return table
function audio.SetLoopingPoint(inst, introEndTime, outroStartTime)
    if not inst then
        return {}
    end

    inst._looping_point = {
        intro_end = introEndTime or 0,
        outro_start = outroStartTime or 0,
        mode = "loop",
        triggered = false
    }

    return inst
end

---@param inst table
---@return table
function audio.FollowLoop(inst)
    if not inst then
        return {}
    end

    if inst._looping_point then
        inst._looping_point.mode = "loop"
    end

    return inst
end

---@param inst table
---@return table
function audio.FollowOutro(inst)
    if not inst then
        return {}
    end

    if inst._looping_point then
        inst._looping_point.mode = "outro"
    end

    return inst
end

---@param sound string
---@param volume number|nil
---@param loop boolean|nil
---@return any, table
function audio.PlaySound(sound, volume, loop)
    local inst = {}
    local source = SE.audio.newSource(audio._path_sound .. sound, "static")
    source:setVolume(volume or Global.GetVariable("Volume").Master * Global.GetVariable("Volume").Sounds)
    source:setLooping(loop or false)
    source:play()
    inst.source = source

    -- mark whether this instance is looping so Update can clean non-looping finished sources
    inst.loop = loop or false
    inst.paused = false
    inst.stopped = false

    attachInstMethods(inst)

    table.insert(audio.insts, inst)
    return inst.source, inst
end

---@param music string
---@param volume number|nil
---@param loop boolean|nil
---@return any, table
function audio.PlayMusic(music, volume, loop)
    local inst = {}
    local source = SE.audio.newSource(audio._path_music .. music, "stream")
    source:setVolume(volume or Global.GetVariable("Volume").Master * Global.GetVariable("Volume").Music)
    source:setLooping(loop ~= false)
    source:play()
    inst.source = source

    -- mark whether this instance is looping so Update can clean non-looping finished sources
    inst.loop = loop ~= false
    inst.paused = false
    inst.stopped = false

    attachInstMethods(inst)

    table.insert(audio.insts, inst)
    return inst.source, inst
end

---@param dt number
function audio.Update(dt)
    for i = #audio.insts, 1, -1 do
        local a = audio.insts[i]
        if not a or not a.source then
            table.remove(audio.insts, i)
        else
            if a._volume_transition then
                if updateTransition(a, a._volume_transition, "volume", dt) then
                    a._volume_transition = nil
                end
            end

            if a._pitch_transition then
                if updateTransition(a, a._pitch_transition, "pitch", dt) then
                    a._pitch_transition = nil
                end
            end

            if a._looping_point and not a.paused and a.source then
                local ok_position = pcall(function()
                    return a.source:tell()
                end)
                local position = 0
                if ok_position then
                    position = a.source:tell()
                end

                if position >= (a._looping_point.intro_end or 0) then
                    if not a._looping_point.triggered then
                        a._looping_point.triggered = true
                        if a._looping_point.mode == "outro" then
                            pcall(function()
                                a.source:seek(a._looping_point.outro_start or 0)
                            end)
                        else
                            pcall(function()
                                a.source:seek(0)
                            end)
                        end
                    end
                else
                    a._looping_point.triggered = false
                end
            end

            if not a.paused then
                -- if this source is not looping and not playing anymore, release and remove it
                local ok_isPlaying = pcall(function() return a.source:isPlaying() end)
                local isPlaying = false
                if ok_isPlaying then
                    isPlaying = a.source:isPlaying()
                end

                if (not a.loop) and (not isPlaying) then
                    pcall(function() a.source:release() end)
                    table.remove(audio.insts, i)
                end
            end
        end
    end
end

return audio