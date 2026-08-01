local guard = {
    running = Global.GetVariable("SE_MEMORY_SAFETY"),
    limits = {
        sprites = Global.GetVariable("OPT_COUNT_SPRITES"),
        typers = Global.GetVariable("OPT_COUNT_TYPERS"),
        audios = Global.GetVariable("OPT_COUNT_AUDIOS"),

        memory = Global.GetVariable("OPT_MEMORY_MAXSIZE")
    },
    lru = {
        sprites = Global.GetVariable("OPT_LRU_SPRITES")
    }
}

local timers = {
    lim_spr = 0,
    lim_typ = 0,
    lim_aud = 0
}

local warning = {
    "Sprites",
    "Typers",
    "Audios"
}

function guard.Update(dt)
    if (not guard.running) then return end

    local count_sprites = #Sprites.images
    if (count_sprites >= guard.limits.sprites) then
        timers.lim_spr = timers.lim_spr + dt
    end

    for i, time in ipairs(timers)
    do
        if (time and time >= 1) then
            time = 0
        end
    end
end

return guard