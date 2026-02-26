-- Get the player's soul movement functions.
local PlayerLib = require("Scripts.Libraries.Attacks.PlayerLib")

-- This is where we init the encounter.
-- All the encounter data is stored here.
local encounter = {

    -- This is your encounter text, which will be displayed at the main ARENA.
    EncounterText = localize.EncounterText,

    -- These are variables that player can get when they win the battle.
    Gold = 0,
    Exp = 0,

    -- This table is for the enemy data.
    -- You can add as many enemies as you want, but the first one will be the one that is displayed first.
    Enemies = {
        {
            name = "Poseur",
            defensetext = "MISS",
            misstext = "MISS",
            exp = 9999,
            gold = 1,
            maxhp = 100,
            hp = 100,
            maxdamage = 999,

            killable = true,
            canspare = false,
            dead = false,

            actions = localize.Enemies.Poseur.Actions,
            position = {
                x = 320,
                y = 140
            }
        },
    },

    -- This is the table that contains your inventory.
    Inventory = {
        Pattern = 1, -- Pattern 2 is not available yet.
        NoDelete = false,

        -- Your items go here.
        Items = DATA.player.items
    },

    -- The default state of the encounter.
    STATE = "ACTIONSELECT",

    -- This is the table that contains your player data.
    Player = PlayerLib.Init({
        name = DATA.player.name,
        lv = DATA.player.lv,
        maxhp = DATA.player.maxhp,
        hp = DATA.player.hp
    }),

    -- And don't touch this one...
    -- This controls whether you can win the encounter or not.
    -- If you set this to true, you will win the encounter no matter what.
    -- So the battle will end immediately.(maybe i should call it stuck)
    WIN = false
}

return encounter