--- Encounter data for the intro fight with SOL: narration, flee odds and the enemy table.
local encounter = {
    narration = Localize.localizeText("Overworld.Text.NobodyCame"),
    can_flee = true,
    flee_percent = 0.75,
    enemy_id = 1,
    enemies = {
        {
            id = "SOL",
            _color = {1, 1, 0.5},
            name = "",
            maxdamage = 10,
            dmg_float = 2,

            show_hpbar = false,
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
            }
        },
    },

    player = DATA.player,
    state = "DEFENDING",
    wave = "nobody_came",

    items = {
        {id = "CHOCOLATE", _color = {0.4, 1, 1}, name = "Chocolate"},
        {id = "END", _color = {0.4, 0, 1}, name = "END"},
    }
}

for i = 1, #encounter.enemies
do
    local e = encounter.enemies[i]
    e._id = encounter.enemy_id
    encounter.enemy_id = encounter.enemy_id + 1
end

return encounter
