local wave = {
    ENDED = false,
    _paths = {},
    objects = {}
}

--- Destroys all wave objects, unloads their modules and marks the wave ended.
function wave.EndWave()
    for i = #wave.objects, 1, -1
    do
        local obj = wave.objects[i]
        if (obj.Destroy) then
            obj:Destroy()
        end
    end
    for i = #wave._paths, 1, -1
    do
        local p = wave._paths[i]
        package.loaded["Scripts.Libraries." .. p] = nil
    end
    wave.ENDED = true
end

--- Loads a wave module once and records its path for later cleanup.
---@param path string
---@return table|nil
function wave.Import(path)
    local lib
    local ok, err = pcall(function ()
        lib = ImportFile(path)
    end)

    if (not ok) then
        print("[Battle - Waves] Error: " .. err)
    else
        local _add = true
        for _, v in ipairs(wave._paths)
        do
            if (v == path) then
                _add = false
            end
        end

        if (_add) then
            table.insert(wave._paths, path)
        end

        return lib
    end
end

return wave