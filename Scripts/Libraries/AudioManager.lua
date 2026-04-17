local audio = {
    sources = {},
    musicGroups = {}
}
local functions = {}

functions.VolumeTransition = function(instance, begin, target, duration)
    if instance.source then
        instance.source:setVolume(begin)
        instance.effects.volume = {
            duration = 0,
            target = target,
            begin = begin,
            total = duration
        }
    end
end

functions.PitchTransition = function(instance, begin, target, duration)
    if instance.source then
        instance.source:setPitch(begin)
        instance.effects.pitch = {
            duration = 0,
            target = target,
            begin = begin,
            total = duration
        }
    end
end

functions.Destroy = function(instance)
    for i = #audio.sources, 1, -1 do
        if audio.sources[i] == instance then
            if instance.source then
                instance.source:stop()
                instance.source:release()
                instance.source = nil
            end
            table.remove(audio.sources, i)
        end
    end
end

functions.__index = functions

function audio.PlayMusic(path, volume, looping)
    local inst = {}

    inst.name = path
    inst.type = "stream"
    inst.source = love.audio.newSource("Resources/Music/" .. path, "stream")
    inst.source:setVolume(volume or 1)
    inst.source:setLooping(looping ~= false)
    inst.source:play()

    inst.effects = {
        volume = {duration = 1, target = 1, begin = 1, total = 0},
        pitch  = {duration = 1, target = 1, begin = 1, total = 0}
    }

    setmetatable(inst, functions)
    table.insert(audio.sources, inst)

    return inst.source, inst
end

function audio.PlaySound(path, volume, looping)
    local inst = {}

    inst.name = path
    inst.type = "static"
    inst.source = love.audio.newSource("Resources/Sounds/" .. path, "static")
    inst.source:setVolume(volume or 1)
    inst.source:setLooping(looping == true)
    inst.source:play()

    inst.effects = {
        volume = {duration = 1, target = 1, begin = 1, total = 0},
        pitch  = {duration = 1, target = 1, begin = 1, total = 0}
    }

    setmetatable(inst, functions)
    table.insert(audio.sources, inst)

    return inst.source, inst
end

function audio.Update()
    local dt = love.timer.getDelta()

    for i = #audio.sources, 1, -1 do
        local inst = audio.sources[i]

        -- 音量渐变
        local v = inst.effects.volume
        if v.duration <= v.total then
            v.duration = v.duration + dt
            inst.source:setVolume(
                v.begin + (v.target - v.begin) * (v.duration / v.total)
            )
        end

        -- pitch渐变
        local p = inst.effects.pitch
        if p.duration <= p.total then
            p.duration = p.duration + dt
            inst.source:setPitch(
                p.begin + (p.target - p.begin) * (p.duration / p.total)
            )
        end
    end

    -- ===== MusicGroup 更新 =====
    for _, group in pairs(audio.musicGroups) do
        local inst = group.current
        if not inst or not inst.source then goto continue end

        -- START阶段
        if group.stage == "start" then
            if not inst.source:isPlaying() then
                group.finishedStart = true

                if group.tracks.loops and #group.tracks.loops > 0 then
                    group.stage = "loop"
                    group.loopIndex = 1

                    local _, newInst = audio.PlayMusic(
                        group.tracks.loops[1],
                        group.volume,
                        false
                    )
                    group.current = newInst
                end
            end
        end

        -- LOOP阶段
        if group.stage == "loop" then
            if not inst.source:isPlaying() then
                group.loopIndex = group.loopIndex + 1
                if group.loopIndex > #group.tracks.loops then
                    group.loopIndex = 1
                end

                local _, newInst = audio.PlayMusic(
                    group.tracks.loops[group.loopIndex],
                    group.volume,
                    false
                )
                group.current = newInst
            end
        end

        -- OUTRO阶段
        if group.stage == "outro" then
            if not inst.source:isPlaying() then
                audio.musicGroups[group.name] = nil
            end
        end

        ::continue::
    end
end

function audio.CreateMusicGroup(name, config, volume)
    local group = {
        name = name,
        tracks = config,
        stage = "start",
        loopIndex = 1,
        finishedStart = false,
        volume = volume or 1,
        current = nil
    }

    audio.musicGroups[name] = group

    if config.start then
        local _, inst = audio.PlayMusic(config.start, group.volume, false)
        group.current = inst
    end

    return group
end

function audio.SetGroupStage(name, stage, opt)
    local group = audio.musicGroups[name]
    if not group then return end

    opt = opt or {}
    local fade = opt.fade
    local duration = opt.duration or 1
    local loopIndex = opt.loopIndex or 1

    local old = group.current
    if old then
        if fade then
            old:VolumeTransition(old.source:getVolume(), 0, duration)
        end
        old:Destroy()
    end

    group.stage = stage

    -- START
    if stage == "start" and group.tracks.start then
        group.finishedStart = false
        local _, inst = audio.PlayMusic(
            group.tracks.start,
            fade and 0 or group.volume,
            false
        )
        group.current = inst
        if fade then inst:VolumeTransition(0, group.volume, duration) end
    end

    -- LOOP
    if stage == "loop" then
        group.loopIndex = loopIndex
        local track = group.tracks.loops[loopIndex]
        if track then
            local _, inst = audio.PlayMusic(
                track,
                fade and 0 or group.volume,
                false
            )
            group.current = inst
            if fade then inst:VolumeTransition(0, group.volume, duration) end
        end
    end

    -- OUTRO
    if stage == "outro" and group.tracks.outro then
        local _, inst = audio.PlayMusic(
            group.tracks.outro,
            fade and 0 or group.volume,
            false
        )
        group.current = inst
        if fade then inst:VolumeTransition(0, group.volume, duration) end
    end
end

function audio.IsGroupStartFinished(name)
    local g = audio.musicGroups[name]
    return g and g.finishedStart or false
end

function audio.GetGroupStage(name)
    local g = audio.musicGroups[name]
    return g and g.stage or nil
end

function audio.NextMusicSegment(name)
    local g = audio.musicGroups[name]
    if not g or g.stage ~= "loop" then return end

    g.loopIndex = g.loopIndex + 1
    if g.loopIndex > #g.tracks.loops then
        g.loopIndex = 1
    end

    audio.SetGroupStage(name, "loop", {loopIndex = g.loopIndex})
end

function audio.PlayGroupOutro(name)
    audio.SetGroupStage(name, "outro")
end

function audio.GroupFade(name, fadeIn, duration)
    local g = audio.musicGroups[name]
    if not g or not g.current then return end

    local inst = g.current
    if fadeIn then
        inst:VolumeTransition(0, g.volume, duration or 1)
    else
        inst:VolumeTransition(inst.source:getVolume(), 0, duration or 1)
    end
end

return audio