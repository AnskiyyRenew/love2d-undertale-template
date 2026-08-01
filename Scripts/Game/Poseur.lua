local encounter = {
    narration = "* Poseur strikes a pose!",
    can_flee = true,
    flee_percent = 0.75,
    enemy_id = 1,
    enemies = {
        {
            id = "Poseur",
            name = Localize.localizeText("Battle.EnemiesName.Poseur"),
            animation = require("Scripts.Game.Animations.Poseur"),

            maxdamage = 400,
            dmg_float = 2,  -- Some random stuff......I hate them

            show_hpbar = true, -- Sans... stop hiding your hp bar.
            maxhp = 100,
            hp = 100,
            gold = 1,
            exp = 1,

            defensetext = "MISS",
            misstext = "MISS",

            canspare = true,
            killable = true,

            position = {320, 140},
            actions = {
                {id = "Check", name = Localize.localizeText("Battle.Actions.Names.Check")},
                {id = "Pose",  name = Localize.localizeText("Battle.Actions.Names.Pose")},
            }
        },
        {
            id = "Poseur",
            name = Localize.localizeText("Battle.EnemiesName.Poseur"),
            animation = require("Scripts.Game.Animations.Poseur"),

            maxdamage = 400,
            dmg_float = 2,  -- Some random stuff......I hate them

            show_hpbar = true, -- Sans... stop hiding your hp bar.
            maxhp = 100,
            hp = 100,
            gold = 1,
            exp = 1,

            defensetext = "MISS",
            misstext = "MISS",

            canspare = true,
            killable = true,

            position = {120, 140},
            actions = {
                {id = "Check", name = Localize.localizeText("Battle.Actions.Names.Check")},
                {id = "Pose",  name = Localize.localizeText("Battle.Actions.Names.Pose")},
            }
        },
    },

    player = {
        name = "anskiy",
        lv = 20,
        maxhp = 99,
        hp = 99
    },

    items = {
        {id = "CHOCOLATE", _color = {0.4, 1, 1}, name = "Chocolate"},
        {id = "END", _color = {0.4, 0, 1}, name = "END"},
    }
}

-- Assign internal _id to each statically-defined enemy
for i = 1, #encounter.enemies
do
    local e = encounter.enemies[i]
    e._id = encounter.enemy_id
    encounter.enemy_id = encounter.enemy_id + 1
end

-- The following methods are now provided by Battle.game_apis via metatable:
--   encounter:AddEnemy(data)  — adds a validated enemy with auto-assigned _id
--   encounter:AddItem(item)    — adds a validated item
--   encounter:forceAttack(id, value) — applies forced damage to an enemy by _id

return encounter
