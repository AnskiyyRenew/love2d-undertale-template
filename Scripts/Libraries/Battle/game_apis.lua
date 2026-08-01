-- Battle Game APIs
-- These methods are designed to be attached to encounter tables via metatable (__index).
-- When called as encounter:AddItem(...) or encounter:AddEnemy(...), `self` refers to the encounter table.

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
---Automatically assigns a unique `_id` based on `self.enemy_id`.
---Falls back to sensible defaults for any missing fields.
function battle_methods.AddEnemy(self, enemy_data)
    local e = normalize_enemy(enemy_data)

    -- Assign a unique internal id
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

function battle_methods.InitAnimation(self, index, ...)
    local enemy = self.enemies and self.enemies[index]
    if (not enemy or not enemy.animation) then
        print("[Game - Animation] WARNING: Enemy #" .. tostring(index) .. " has no animation.")
        return
    end

    -- `enemy.animation` is either the animation *module* (from `require`) or
    -- already an independent instance. Detection is fully generic and has no
    -- monster-specific fields (e.g. `poseur`): an instance is a table whose
    -- metatable is a factory class exposing `New`, while the module itself is
    -- not an instance (it has no such metatable). This works for any enemy.
    local module = enemy.animation

    local meta = getmetatable(module)
    if (meta and meta.New) then
        return  -- already an independent instance → nothing to do
    end

    local ok, err = pcall(function (...)
        -- Factory module → produce a fresh, independent instance per enemy.
        if (module.New) then
            enemy.animation = module.New(...)
        -- Legacy module with an in-place Init() (single shared instance).
        elseif (module.Init) then
            module.Init(...)
        end
    end, ...)

    if (not ok) then
        print("[Game - Animation] Error: " .. err)
    end
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
