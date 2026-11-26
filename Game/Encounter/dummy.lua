--- Encounter data for the dummy fight: one Poseur enemy with a negative maxdamage that heals the player.
local encounter = {
    narration = Localize.localizeText("Battle.Narration.Default"),
    can_flee = true,
    flee_percent = 0.75,
    enemy_id = 1,
    enemies = {
        {
            id = "Poseur",
            name = Localize.localizeText("Battle.EnemiesName.Poseur"),
            animation = require("Game.Animations.Poseur"),

            maxdamage = -400,
            dmg_float = 2,

            show_hpbar = true,
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
    },

    state = "DEFENDING",
    wave = "wave",

    player = {
        name = "end",
        lv = 20,
        maxhp = 99,
        hp = 99
    },

    items = {
        {id = "CHOCOLATE", _color = {0.4, 1, 1}, name = "Chocolate"},
        {id = "END", _color = {0.4, 0, 1}, name = "END", _cantdestroy = true},
        {id = "CHOCOLATE", _color = {0.4, 1, 1}, name = "Chocolate"},
        {id = "CHOCOLATE", _color = {0.4, 1, 1}, name = "Chocolate"},
        {id = "CHOCOLATE", _color = {0.4, 1, 1}, name = "Chocolate"},
    }
}

for i = 1, #encounter.enemies
do
    local e = encounter.enemies[i]
    e._id = encounter.enemy_id
    encounter.enemy_id = encounter.enemy_id + 1
end

return encounter
