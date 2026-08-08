local logic = {}

logic = {
    time = 0,
    room_name = "--",
    room = "Overworld/scene_ow_new",
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
        weapon = "stick",
        armor = "bandage",

        items = {},
        getcell = true,
        cells = {
            "Toriel"
        }
    },
}

logic.flags = {}

logic.lv_data = {
    { lv = 1,  hp = 20,  at = 10,  df = 10, totalExp = 0      },
    { lv = 2,  hp = 24,  at = 12,  df = 10, totalExp = 10     },
    { lv = 3,  hp = 28,  at = 14,  df = 10, totalExp = 30     },
    { lv = 4,  hp = 32,  at = 16,  df = 10, totalExp = 70     },
    { lv = 5,  hp = 36,  at = 18,  df = 11, totalExp = 120    },
    { lv = 6,  hp = 40,  at = 20,  df = 11, totalExp = 200    },
    { lv = 7,  hp = 44,  at = 22,  df = 11, totalExp = 300    },
    { lv = 8,  hp = 48,  at = 24,  df = 11, totalExp = 500    },
    { lv = 9,  hp = 52,  at = 26,  df = 12, totalExp = 800    },
    { lv = 10, hp = 56,  at = 28,  df = 12, totalExp = 1200   },
    { lv = 11, hp = 60,  at = 30,  df = 12, totalExp = 1700   },
    { lv = 12, hp = 64,  at = 32,  df = 12, totalExp = 2500   },
    { lv = 13, hp = 68,  at = 34,  df = 13, totalExp = 3500   },
    { lv = 14, hp = 72,  at = 36,  df = 13, totalExp = 5000   },
    { lv = 15, hp = 76,  at = 38,  df = 13, totalExp = 7000   },
    { lv = 16, hp = 80,  at = 40,  df = 13, totalExp = 10000  },
    { lv = 17, hp = 84,  at = 42,  df = 14, totalExp = 15000  },
    { lv = 18, hp = 88,  at = 44,  df = 14, totalExp = 25000  },
    { lv = 19, hp = 92,  at = 46,  df = 14, totalExp = 50000  },
    { lv = 20, hp = 99,  at = 48,  df = 14, totalExp = 99999  }
}

return logic