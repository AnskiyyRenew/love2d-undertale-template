local encounter = {
    narration = Localize.localizeText("Battle.SETRIO.Narration"),
    can_flee = true,
    flee_percent = 0.75,
    enemy_id = 1,
    enemies = {
        {
            id = "SOL",
            _color = {1, 1, 0.5},
            name = Localize.localizeText("Battle.EnemiesName.Sol"),
            maxdamage = 10,
            dmg_float = 2,  -- Some random stuff......I hate them

            show_hpbar = false, -- Sans... stop hiding your hp bar.
            maxhp = 100,
            hp = 100,
            gold = 1,
            exp = 1,

            defensetext = "MISS",
            misstext = "MISS",

            canspare = false,
            killable = true,

            position = {320, 120},
            actions = {
                {id = "CHECK", name = Localize.localizeText("Battle.Actions.Names.Sol")[1]},
                {id = "TALK",  name = Localize.localizeText("Battle.Actions.Names.Sol")[2]},
                {id = "STARE", name = Localize.localizeText("Battle.Actions.Names.Sol")[3]},
                {id = "IGNORE",name = Localize.localizeText("Battle.Actions.Names.Sol")[4]},
            }
        },
        {
            id = "SINCERA",
            _color = {0.8, 0.8, 0.8},
            name = Localize.localizeText("Battle.EnemiesName.Sincera"),
            maxdamage = 10,
            dmg_float = 2,  -- Some random stuff......I hate them

            show_hpbar = true, -- Sans... stop hiding your hp bar.
            maxhp = 100,
            hp = 100,
            gold = 1,
            exp = 1,

            defensetext = "MISS",
            misstext = "MISS",

            canspare = false,
            killable = true,

            position = {120, 120},
            actions = {
                {id = "CHECK",     name = Localize.localizeText("Battle.Actions.Names.Sincera")[1]},
                {id = "APPRECIATE", name = Localize.localizeText("Battle.Actions.Names.Sincera")[2]},
            }
        },
        {
            id = "SPIDER",
            _color = {0.5, 0.3, 1},
            name = Localize.localizeText("Battle.EnemiesName.Spider"),
            maxdamage = 10,
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

            position = {520, 120},
            actions = {
                {id = "CHECK", name = Localize.localizeText("Battle.Actions.Names.Spider")[1]},
                {id = "TALK",  name = Localize.localizeText("Battle.Actions.Names.Spider")[2]},
                {id = "KNOT",  name = Localize.localizeText("Battle.Actions.Names.Spider")[3]},
            }
        },
    },

    player = {
        name = "end",
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
