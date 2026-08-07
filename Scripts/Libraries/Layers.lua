---@class LayerSystem
local layers = {
    layers = {},
    objects = {},
    external_draws = {},
    all_draws = {},
    next_id = 1,
    dirty = true
}

--- Find a layer object by its name.
---@param name string The layer name to search for.
---@return table|nil The layer object if found, or nil.
local function find_layer_obj(name)
    for _, layer in ipairs(layers.layers) do
        if layer.name == name then
            return layer
        end
    end
    return nil
end

--- Safely convert a value to a numeric layer, resolving string layer names.
--- If the value is a string, it looks up the layer by name via `find_layer_obj`.
--- If not found, it prints a warning and returns 0.
---@param v any The layer value (number or string).
---@return number The numeric layer value.
local function to_numeric_layer(v)
    if type(v) == "number" then
        return v
    elseif type(v) == "string" then
        local target = find_layer_obj(v)
        if target then
            return target.layer
        end
        print("[WARNING] Layers: Layer \"" .. tostring(v) .. "\" not found, defaulting to 0")
        return 0
    end
    return tonumber(v) or 0
end

--- Perform a stable sort on a table by `layer` (numeric), then by `_id`.
---@param t table The table to sort in-place.
local function stable_sort(t)
    table.sort(t, function(a, b)
        local la = to_numeric_layer(a.layer)
        local lb = to_numeric_layer(b.layer)
        if la ~= lb then
            return la < lb
        end
        return (a._id or 0) < (b._id or 0)
    end)
end

local objects_sort_dirty = true

--- Mark all sort/dirty caches as needing a rebuild.
local function mark_dirty()
    layers.dirty = true
    objects_sort_dirty = true
end

--- Re-sort the main objects list if it has been marked dirty.
local function sort()
    if (not objects_sort_dirty) then return end
    stable_sort(layers.objects)
    objects_sort_dirty = false
end

--- Clear all elements from an array-like table (set them to nil).
---@param t table The table to clear.
local function clear_table(t)
    for i = #t, 1, -1 do
        t[i] = nil
    end
end

--- Wrap an internal layer object into a public-facing layer API table.
---@param layer_obj table The internal layer object.
---@return table The wrapped layer interface with methods.
local function wrap_layer(layer_obj)
    return {
        name = layer_obj.name,
        layer = layer_obj.layer,
        _id = layer_obj._id,

        --- Add an object to this layer.
        ---@param obj table The object to add.
        ---@return table The added object.
        add = function(self, obj)
            obj.layer = layer_obj.layer
            obj._layer_id = layer_obj._id
            obj._id = layers.next_id
            layers.next_id = layers.next_id + 1
            table.insert(layer_obj.objects, obj)
            table.insert(layers.objects, obj)
            mark_dirty()
            return obj
        end,

        --- Remove an object from this layer.
        ---@param obj table The object to remove.
        ---@return boolean True if the object was successfully removed.
        remove = function(self, obj)
            local removed = false
            for i = #layer_obj.objects, 1, -1 do
                if layer_obj.objects[i] == obj then
                    table.remove(layer_obj.objects, i)
                    break
                end
            end

            for i = #layers.objects, 1, -1 do
                if layers.objects[i] == obj then
                    if obj.Destroy then obj:Destroy() end
                    if obj.Remove then obj:Remove() end
                    table.remove(layers.objects, i)
                    mark_dirty()
                    removed = true
                    break
                end
            end
            return removed
        end,

        --- Clear all objects from this layer.
        clear = function(self)
            for i = #layer_obj.objects, 1, -1 do
                local obj = layer_obj.objects[i]
                if obj.Destroy then obj:Destroy() end
                if obj.Remove then obj:Remove() end
                table.remove(layer_obj.objects, i)
            end

            for i = #layers.objects, 1, -1 do
                if layers.objects[i]._layer_id == layer_obj._id then
                    table.remove(layers.objects, i)
                end
            end

            mark_dirty()
        end,

        --- Draw all active objects in this layer.
        draw = function(self)
            if not layer_obj._active then return end
            for _, obj in ipairs(layer_obj.objects) do
                if obj.Draw then
                    obj:Draw()
                end
            end
        end,

        --- Return the number of objects in this layer.
        ---@return integer
        count = function(self)
            return #layer_obj.objects
        end,

        --- Return the internal objects table of this layer.
        ---@return table
        get_objects = function(self)
            return layer_obj.objects
        end,

        --- Change the numeric layer value for this layer and all its objects.
        --- If `new_layer` is a string, it will be resolved via `find_layer_obj`.
        --- If the named layer is not found, a warning is printed and the value defaults to 0.
        ---@param new_layer number|string The new layer value (number) or layer name (string) to switch to.
        set_layer = function(self, new_layer)
            if type(new_layer) == "string" then
                local target = find_layer_obj(new_layer)
                if target then
                    new_layer = target.layer
                else
                    print("[WARNING] Layers.set_layer: Layer \"" .. tostring(new_layer) .. "\" not found, defaulting to 0")
                    new_layer = 0
                end
            end

            self.layer = new_layer
            layer_obj.layer = new_layer

            for _, obj in ipairs(layer_obj.objects) do
                obj.layer = new_layer
            end

            mark_dirty()
        end,

        --- Set whether this layer is active (visible).
        ---@param active boolean
        set_active = function(self, active)
            self._active = active
            layer_obj._active = active
            mark_dirty()
        end,

        --- Return whether this layer is currently active.
        ---@return boolean
        is_active = function(self)
            return layer_obj._active
        end
    }
end

--- Create a new layer with the given name and numeric layer value.
---@param name string The layer's name.
---@param layer number|nil The numeric layer value (defaults to 0).
---@return table The wrapped layer interface.
function layers.new_layer(name, layer)
    layer = layer or 0

    local layer_obj = {
        name = name,
        layer = layer,
        objects = {},
        _id = layers.next_id,
        _active = true
    }
    layers.next_id = layers.next_id + 1

    table.insert(layers.layers, layer_obj)
    mark_dirty()

    return wrap_layer(layer_obj)
end

--- Retrieve a wrapped layer interface by its name.
---@param name string The layer name to look up.
---@return table|nil The wrapped layer interface, or nil if not found.
function layers.get_layer(name)
    local layer_obj = find_layer_obj(name)
    if not layer_obj then return nil end
    return wrap_layer(layer_obj)
end

--- Remove a layer by its name, destroying all its objects.
---@param name string The layer name to remove.
---@return boolean True if the layer was found and removed.
function layers.remove_layer(name)
    for i = #layers.layers, 1, -1 do
        if layers.layers[i].name == name then
            local layer = layers.layers[i]

            for _, obj in ipairs(layer.objects) do
                if obj.Destroy then obj:Destroy() end
                if obj.Remove then obj:Remove() end
            end

            for j = #layers.objects, 1, -1 do
                if layers.objects[j]._layer_id == layer._id then
                    table.remove(layers.objects, j)
                end
            end

            table.remove(layers.layers, i)
            mark_dirty()
            return true
        end
    end
    return false
end

--- Enable or disable a layer by its name.
---@param name string The layer name.
---@param active boolean Whether the layer should be active.
---@return boolean True if the layer was found.
function layers.set_layer_active(name, active)
    local layer_obj = find_layer_obj(name)
    if not layer_obj then return false end
    layer_obj._active = active
    mark_dirty()
    return true
end

--- Add an object to the layer system. If `obj.layer` is a string, it is resolved
--- to a numeric layer value via `find_layer_obj`. If the named layer is not found,
--- a warning is printed and the value defaults to 0.
---@param obj table The object to add.
---@return table The added object.
function layers.add(obj)
    obj.layer = obj.layer or 0

    -- Resolve string layer names to their numeric values, so sorting works correctly
    if type(obj.layer) == "string" then
        local layer_obj = find_layer_obj(obj.layer)
        if layer_obj then
            obj.layer = layer_obj.layer
            obj._layer_id = layer_obj._id
        else
            print("[WARNING] Layers.add: Layer \"" .. tostring(obj.layer) .. "\" not found, defaulting to 0")
            obj.layer = 0
        end
    end

    obj._id = layers.next_id
    layers.next_id = layers.next_id + 1
    table.insert(layers.objects, obj)
    mark_dirty()

    return obj
end

--- Remove an object from the layer system.
---@param obj table The object to remove.
---@return boolean True if the object was found and removed.
function layers.remove(obj)
    for i = #layers.objects, 1, -1 do
        if layers.objects[i] == obj then
            table.remove(layers.objects, i)
            mark_dirty()
            return true
        end
    end
    return false
end

--- Add an external draw function to the layer system.
---@param draw_func function The draw function.
---@param layer number|string|nil The numeric layer value or string layer name (defaults to 0).
---@return table The external draw entry.
function layers.add_external(draw_func, layer)
    local t = {
        func = draw_func,
        layer = to_numeric_layer(layer),
        _id = layers.next_id,
        _active = true
    }
    layers.next_id = layers.next_id + 1
    table.insert(layers.external_draws, t)
    mark_dirty()
    return t
end

--- Remove a specific external draw entry.
---@param t table The external draw entry to remove.
---@return boolean True if the entry was found and removed.
function layers.remove_external(t)
    if (not t or not t._active) then return false end

    for i = #layers.external_draws, 1, -1 do
        if layers.external_draws[i] == t then
            table.remove(layers.external_draws, i)
            t._active = false
            mark_dirty()
            return true
        end
    end
    return false
end

--- Remove all external draw entries in the given list.
---@param list table A list of external draw entries to remove.
function layers.remove_externals(list)
    for _, t in ipairs(list) do
        layers.remove_external(t)
    end
end

--- Remove all external draw entries at the given numeric layer value.
---@param layer number|string The numeric layer value or string layer name to filter by.
---@return integer The number of removed entries.
function layers.remove_external_by_layer(layer)
    local num_layer = to_numeric_layer(layer)
    local removed = 0
    for i = #layers.external_draws, 1, -1 do
        if layers.external_draws[i].layer == num_layer then
            layers.external_draws[i]._active = false
            table.remove(layers.external_draws, i)
            removed = removed + 1
        end
    end
    if removed > 0 then
        mark_dirty()
    end
    return removed
end

--- Clear all external draw entries.
function layers.clear_external()
    for _, t in ipairs(layers.external_draws) do
        t._active = false
    end
    layers.external_draws = {}
    clear_table(layers.all_draws)
    mark_dirty()
end

--- Force a re-sort of the objects list.
function layers.sort()
    sort()
end

--- Mark the layer system as dirty, forcing a rebuild of the draw list
--- and re-sort on the next draw call.
function layers.mark_dirty()
    mark_dirty()
end

--- Draw all objects and external draw functions in layer order.
function layers.draw()

    if layers.dirty or #layers.all_draws == 0 then
        local all_draws = layers.all_draws
        clear_table(all_draws)

        local active_by_layer_id = {}
        for _, l in ipairs(layers.layers) do
            active_by_layer_id[l._id] = l._active
        end

        for _, obj in ipairs(layers.objects) do
            local skip = false
            if obj._layer_id then
                skip = (active_by_layer_id[obj._layer_id] == false)
            end
            if not skip then
                table.insert(all_draws, {
                    type = "object",
                    obj = obj,
                    layer = to_numeric_layer(obj.layer),
                    _id = obj._id or 0
                })
            end
        end

        for _, draw in ipairs(layers.external_draws) do
            if draw._active then
                table.insert(all_draws, {
                    type = "external",
                    func = draw.func,
                    layer = to_numeric_layer(draw.layer),
                    _id = draw._id or 0
                })
            end
        end

        stable_sort(all_draws)
        layers.dirty = false
    end

    for _, item in ipairs(layers.all_draws) do
        if item.type == "object" then
            if item.obj.Draw then
                item.obj:Draw()
            end
        else
            item.func()
        end
    end
end

--- Clear all layers, objects, and external draws, resetting the system.
function layers.clear()
    Typers.ClearAll()
    for i = #layers.objects, 1, -1 do
        local o = layers.objects[i]
        if (o.Destroy) then o:Destroy() end
        if (o.Remove) then o:Remove() end
        table.remove(layers.objects, i)
    end

    layers.layers = {}
    layers.external_draws = {}
    clear_table(layers.all_draws)
    layers.next_id = 1
    mark_dirty()
end

--- Return the total number of managed objects.
---@return integer
function layers.count()
    return #layers.objects
end

--- Return the number of external draw entries.
---@return integer
function layers.external_count()
    return #layers.external_draws
end

--- Find an object, layer, or external draw by its unique ID.
---@param id integer The ID to search for.
---@return table|nil The found entity, or nil.
function layers.find_by_id(id)
    for _, obj in ipairs(layers.objects) do
        if obj._id == id then return obj end
    end
    for _, layer_obj in ipairs(layers.layers) do
        if layer_obj._id == id then return wrap_layer(layer_obj) end
    end
    for _, ext in ipairs(layers.external_draws) do
        if ext._id == id then return ext end
    end
    return nil
end

--- Print debug information about the current state of the layer system.
function layers.debug()
    print("=== Layers Debug ===")
    print("Objects:", #layers.objects)
    print("Layers:", #layers.layers)
    print("External draws:", #layers.external_draws)
    print("Next ID:", layers.next_id)
    print("Dirty:", layers.dirty)
    print("====================")
end

return layers