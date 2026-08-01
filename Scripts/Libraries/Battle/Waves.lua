local wave = {
    _end = false,
    _paths = {},
    objects = {}
}

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
    wave._end = true
end

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