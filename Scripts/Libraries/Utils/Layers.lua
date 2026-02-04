local layers = {
    objects = {}
}

function layers.sort()
    table.sort(layers.objects, function(a, b)
        return a.layer < b.layer
    end)

    for _, object in ipairs(layers.objects)
    do
        if (object.isactive) then
            object:Draw()
        end
    end
end

function layers.clear()
    sprites.clear()
    typers.clear()
    layers.objects = {}
end

return layers