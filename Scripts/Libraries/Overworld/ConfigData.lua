DATA = DATA or global:GetSaveVariable("Overworld") or
{
    time = 0,
    room_name = "--",
    room = "Overworld/scene_ow_ruins_0",
    marker = 2,
    position = {0, 0},
    direction = "down",
    savedpos = false,

    player = {
        name = "Chara",
        lv = 1,
        maxhp = 20,
        hp = 20,

        gold = 0,
        exp = 0,

        atk = 0,
        watk = 0,
        def = 0,
        edef = 0,
        weapon = "[preset=chinese]木棍",
        armor = "[preset=chinese]绷带",

        items = {
            "[preset=chinese]神秘小礼物",
            "[preset=chinese]铁壶",
            "[preset=chinese]吃我",
            "[preset=chinese]安黛因的信",
            "[preset=chinese]传单",
            "[preset=chinese]别欺负我",
        },
        cells = {}
    },
}
FLAG = FLAG or global:GetSaveVariable("Flag") or
{
    ruins_killed = 0,
    ruins_0 = {
        donut_chest = false,
        text_inst = false
    }
}
CHESTS = CHESTS or global:GetSaveVariable("Chests") or
{
    chest1 = {
        "[preset=chinese][red]蜘蛛",
    },
    chest2 = {
        "[preset=chinese][yellow]看不见我"
    }
}
levelData = {
    { lv = 1,  hp = 20,  at = 10,  df = 10,  nextExp = 10,   totalExp = 0      },
    { lv = 2,  hp = 24,  at = 12,  df = 10,  nextExp = 20,   totalExp = 10     },
    { lv = 3,  hp = 28,  at = 14,  df = 10,  nextExp = 40,   totalExp = 30     },
    { lv = 4,  hp = 32,  at = 16,  df = 10,  nextExp = 50,   totalExp = 70     },
    { lv = 5,  hp = 36,  at = 18,  df = 11,  nextExp = 80,   totalExp = 120    },
    { lv = 6,  hp = 40,  at = 20,  df = 11,  nextExp = 100,  totalExp = 200    },
    { lv = 7,  hp = 44,  at = 22,  df = 11,  nextExp = 200,  totalExp = 300    },
    { lv = 8,  hp = 48,  at = 24,  df = 11,  nextExp = 300,  totalExp = 500    },
    { lv = 9,  hp = 52,  at = 26,  df = 12,  nextExp = 400,  totalExp = 800    },
    { lv = 10, hp = 56,  at = 28,  df = 12,  nextExp = 500,  totalExp = 1200   },
    { lv = 11, hp = 60,  at = 30,  df = 12,  nextExp = 800,  totalExp = 1700   },
    { lv = 12, hp = 64,  at = 32,  df = 12,  nextExp = 1000, totalExp = 2500   },
    { lv = 13, hp = 68,  at = 34,  df = 13,  nextExp = 1500, totalExp = 3500   },
    { lv = 14, hp = 72,  at = 36,  df = 13,  nextExp = 2000, totalExp = 5000   },
    { lv = 15, hp = 76,  at = 38,  df = 13,  nextExp = 3000, totalExp = 7000   },
    { lv = 16, hp = 80,  at = 40,  df = 13,  nextExp = 5000, totalExp = 10000  },
    { lv = 17, hp = 84,  at = 42,  df = 14,  nextExp = 10000,totalExp = 15000  },
    { lv = 18, hp = 88,  at = 44,  df = 14,  nextExp = 25000,totalExp = 25000  },
    { lv = 19, hp = 92,  at = 46,  df = 14,  nextExp = 49999,totalExp = 50000  },
    { lv = 20, hp = 99,  at = 48,  df = 14,  nextExp = nil,  totalExp = 99999  }
}

if (not global:GetSaveVariable("Overworld")) then
    global:SetSaveVariable("Overworld", DATA)
end
if (not global:GetSaveVariable("Flag")) then
    global:SetSaveVariable("Flag", FLAG)
end
if (not global:GetSaveVariable("Chests")) then
    global:SetSaveVariable("Chests", CHESTS)
end