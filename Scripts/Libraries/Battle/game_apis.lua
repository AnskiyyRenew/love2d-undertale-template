-- Battle Game APIs, attached to encounter tables via metatable (__index), so
-- `self` is the encounter table.

local battle_methods = {}

-- Internal: validate and normalize an item definition
local function normalize_item(item)
    local _item = item

    if (not _item or type(_item) ~= "table") then
        print("[Battle - Items] WARNING: Invalid item.")
        _item = {id = "STONE", name = "Stone"}
    end

    if (not _item.id or type(_item.id) ~= "string") then
        print("[Battle - Items] WARNING: Invalid item id.")
        _item = {id = "STONE", name = "Stone"}
    end

    if (not _item.name or type(_item.name) ~= "string") then
        print("[Battle - Items] WARNING: Invalid item name.")
        _item = {id = "STONE", name = "Stone"}
    end

    if (_item._color and type(_item._color) ~= "table") then
        print("[Battle - Items] WARNING: Invalid item color.")
        _item = {id = "BLOODSTONE", _color = {1, 0, 0}, name = "BloodStone"}
    end

    return _item
end

-- Internal: validate and set defaults for an enemy definition
local function normalize_enemy(enemy_data)
    local e = {}

    if (enemy_data and type(enemy_data) == "table") then
        for k, v in pairs(enemy_data) do
            e[k] = v
        end
    end

    if (not e.id or type(e.id) ~= "string") then
        print("[Battle - Enemy] WARNING: Invalid enemy id, using default.")
        e.id = "UNKNOWN"
    end

    if (not e.name) then
        e.name = e.id
    end

    if (not e.maxhp or type(e.maxhp) ~= "number") then
        e.maxhp = 1
    end

    if (not e.hp or type(e.hp) ~= "number") then
        e.hp = e.maxhp
    end

    if (not e.defensetext) then
        e.defensetext = "MISS"
    end

    if (not e.misstext) then
        e.misstext = "MISS"
    end

    if (not e.actions or type(e.actions) ~= "table") then
        e.actions = {}
    end

    if (not e.position or type(e.position) ~= "table") then
        e.position = {320, 240}
    end

    return e
end

--- Add a validated item to the encounter's item list.
function battle_methods.AddItem(self, item)
    local _item = normalize_item(item)

    if (not self.items) then
        self.items = {}
    end

    table.insert(self.items, _item)
    return _item
end

--- Add a validated enemy to the encounter's enemy list.
---Assigns a unique `_id` and fills defaults for missing fields.
function battle_methods.AddEnemy(self, enemy_data)
    local e = normalize_enemy(enemy_data)

    if (not self.enemy_id or type(self.enemy_id) ~= "number") then
        self.enemy_id = 1
    end

    e._id = self.enemy_id
    self.enemy_id = self.enemy_id + 1

    if (not self.enemies) then
        self.enemies = {}
    end

    table.insert(self.enemies, e)
    return e
end

--- Give enemy #`index` its own animation instance, and hand that instance back.
---
--- `enemy.animation` starts as the animation *module*; this call swaps it for a
--- fresh `New(pos)` instance carrying bound methods, so a scene drives it with
--- plain dot calls. Calling this twice is harmless and returns the same handle.
---@param index integer Position in `self.enemies` (1-based).
---@return table|nil anim The instance now stored at `enemy.animation`.
function battle_methods.InitAnimation(self, index, ...)
    local enemy = self.enemies and self.enemies[index]
    if (not enemy or not enemy.animation) then
        print("[Game - Animation] WARNING: Enemy #" .. tostring(index) .. " has no animation.")
        return
    end

    -- The field holds either the animation module or an already-built instance
    -- (`_class` is the marker, see Battle.IsAnimInstance).
    local module = enemy.animation

    if (Battle.IsAnimInstance(module)) then
        -- Already built: re-binding is a no-op, but the handle is still returned.
        Battle.BindAnimation(module)
        return module
    end

    -- Contract: `New(pos)` returns an independent instance (see
    -- Game/Animations/_temp.lua). A module without New() is reported instead.
    if (type(module) ~= "table" or not module.New) then
        print("[Game - Animation] WARNING: Enemy #" .. tostring(index)
            .. " animation has no New(pos); call Game:InitAnimation from the scene.")
        return
    end

    local created_instance = false
    local ok, err = pcall(function (...)
        enemy.animation = module.New(...)
        created_instance = true
    end, ...)

    if (not ok) then
        print("[Game - Animation] Error: " .. err)
        return
    end

    -- A New() that answers with a non-table leaves enemy.animation nil, and
    -- Battle.Update then skips the enemy.
    local anim = enemy.animation
    if (not created_instance or type(anim) ~= "table") then
        return
    end

    -- The instance can read its owner (e.g. `self.enemy.canspare`);
    -- Battle.Update also refreshes shortcut fields on it every frame.
    anim.enemy = enemy

    -- Hang the module's functions on the instance (see Battle.BindAnimation).
    Battle.BindAnimation(anim, module)

    return anim
end

--- Find an enemy by its string `id` (e.g. "SOL", "SINCERA") and apply forced damage / attack.
function battle_methods.ForceAttack(self, id, value)
    for _, en in ipairs(self.enemies or {}) do
        if (en.id == id) then
            Battle.attack.Restart(en)
        end
    end

    print("[Battle - forceAttack] WARNING: No enemy found with id = " .. tostring(id))
    return nil
end

return battle_methods
