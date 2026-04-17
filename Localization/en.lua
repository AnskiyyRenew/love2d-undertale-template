return {
    EncounterText = "* You encountered nothing!",
    Enemies = {
        Poseur = {
            Name = "Poseur",
            Actions = {
                "Check", "Appreciate"
            }
        },
        TheOther = {
            Name = "EnemyName",
            Actions = {
                "Check", "Appreciate"
            }
        },
    },
    Items = {
        Chocolate = "Chocolate",
        End = "I'm end"
    },
    ItemsPage = "PAGE %s",
    Spare = "Spare",
    Flee = "Flee",

    FleeTexts = {
        "* You fled from the battle.\n* You feel refreshed."
    },

    Act11 = {
        "* Poseur - 1 ATK 99 DEF[wait:30]\n* The default enemy.", 
        "[colorHEX:9900ff]* Carrying warm memories..."
    },
    Act12 = {
        "* You posed with Poseur.\n[colorHEX:00ffff]* Time seems to have frozen in\n  this moment...", 
        "* Enjoy the time!"
    },
    Act21 = {
        "* Posette - 1 ATK -1 DEF[wait:30]\n* Poseur's friend.",
        "[colorHEX:9900ff]* Carrying warm memories too..."
    },
    Act22 = {
        "* You posed with Posette.\n[colorHEX:00ffff]* Time seems to have frozen in\n  this moment...",
        "[colorHEX:11ff11]* Enjoy the time!!!"
    },

    Overworld = {
        Menu = {
            Items = "ITEM",
            Stats = "STAT",
            Cell = "CELL",
            ItemActions = " Use    [offsetX=120]Info   [offsetX=230]Drop",
            WeaponLabel = "Weapon: ",
            ArmorLabel = "Armor: ",
            GoldLabel = "Gold:",
            BoxTitle = "Inventory           Box",
            UseBoxPrompt = "* Use the box?[space:2, 38]\n\n        Yes           No[function:player_choosing_start|chestbox,%d]",
            SaveOptions = "Save       Cancel",
            SaveSuccess = "Saved Successfully",
            SavePreview = "%s    LV %d    %02d:%02d"
        },
        Equipment = {
            weapon = {
                stick = "Stick"
            },
            armor = {
                bandage = "Bandage"
            }
        },
        Items = {
            donut = {
                name = "Donut",
                use = {
                    "* You ate the Donut.",
                    "[colorHEX:9900ff]* It has been eaten."
                },
                inspect = {
                    "* You checked the Donut.",
                    "[colorHEX:9900ff]* How much is there to inspect on a donut?"
                },
                drop = {
                    "* You threw away the Donut.",
                    "[colorHEX:9900ff]* Yep. It's gone."
                }
            },
            mystery_gift = {
                name = "Mystery Gift",
                use = {
                    "* You opened the Mystery Gift.",
                    "* There is something mysterious inside.",
                    "* Oh, it looks like another little gift!",
                    "* (You got a Tiny Mystery Gift.)"
                },
                inspect = {
                    "* You checked the Mystery Gift.",
                    "[colorHEX:9900ff]* Open it and see what's inside."
                },
                drop = {
                    "* You threw away the Mystery Gift.",
                    "[colorHEX:9900ff]* But the little gift came back!"
                }
            },
            tiny_mystery_gift = {
                name = "Tiny Mystery Gift",
                use = {
                    "* You opened the Tiny Mystery Gift.",
                    "* Oh. You got opened instead.",
                    "* (You learned that you are currently in [pattern:english]%s[pattern:chinese].)"
                },
                inspect = {
                    "* You checked the Tiny Mystery Gift.",
                    "[colorHEX:9900ff]* Open it and see what's inside."
                },
                drop = {
                    "* You threw away the Tiny Mystery Gift.",
                    "[colorHEX:9900ff]* But the little gift came back!"
                }
            },
            iron_kettle = {
                name = "Iron Kettle",
                use = {
                    "* You opened the Iron Kettle.",
                    "* [sound:snd_doghurt1.wav]Bang[sound:snd_slice.wav]! [sound:snd_save.wav]Clang[sound:snd_menu_0.wav]! [sound:snd_levelup.wav][sound:snd_ding.wav]Crash![sound:snd_dimbox.wav]Bzz[sound:snd_bomb.wav]zt[sound:snd_drumroll.wav]pow[sound:snd_icespell.ogg]clang[sound:snd_notice.wav][sound:snd_mysterygo.wav]![sound:snd_mtt_burst.wav]Woo[sound:snd_saber3.wav]oo[sound:snd_spawn_0.wav]sh[sound:snd_snowgrave.ogg]hh[sound:snd_warning_0.wav]!",
                    "* Ah, what beautiful music.",
                    "* (You panic and throw the Iron Kettle away.)"
                },
                inspect = {
                    "* You checked the Iron Kettle.",
                    "* This Iron Kettle looks like a musician."
                },
                drop = {
                    "* You threw away the Iron Kettle.",
                    "[sound:snd_doghurt1.wav]* Looks like the musical is over."
                }
            },
            eat_me = {
                name = "Eat Me",
                use = {
                    "* If you want to be eaten that badly,\n  down the hatch.",
                    "* (Your HP was fully restored.)"
                },
                inspect = {
                    "* You checked Eat Me.",
                    "* It says: [wait:30][pattern:english]eat me[pattern:chinese]."
                },
                drop = {
                    "[colorHEX:ff0000]* You threw away Eat Me."
                }
            },
            undyne_letter = {
                name = "Undyne's Letter",
                use = {
                    "* You tried to open Undyne's Letter.",
                    "* It's sealed too tightly. You can't open it."
                },
                inspect = {
                    "* You checked Undyne's Letter.",
                    "* [voice:v_flowey.wav]Hey![wait:30] What are you looking at!?",
                    "* Startled, you quickly put the letter back."
                },
                drop = {
                    "* You threw away Undyne's Letter.",
                    "[colorHEX:9900ff]* The letter followed you back!"
                }
            },
            flyer = {
                name = "Flyer",
                inspect = {
                    "* You checked the flyer.",
                    "* It's about the first five missing children."
                },
                drop = {
                    "[colorHEX:ffff33]* For justice, please don't give up."
                }
            },
            dont_bully_me = {
                name = "Don't Bully Me",
                use = {
                    "* You opened the \"Don't Bully Me\" note.",
                    "* What's this?[wait:30] [pattern:english]end[pattern:chinese]?",
                    "* [colorHEX:99ff99]Pinch it."
                },
                inspect = {
                    "* You checked the \"Don't Bully Me\" note.",
                    "* It says: [wait:30][pattern:english]end[pattern:chinese]."
                },
                drop = {
                    "* You threw away the \"Don't Bully Me\" note.",
                    "[colorHEX:ffff99]* Bullying people is wrong."
                }
            },
            bully_once = {
                name = "Bully Once",
                use = {
                    "* You opened the \"Bully Once\" note.",
                    "* [colorHEX:ffff33][effect:shake, 1]You really deserve that."
                },
                inspect = {
                    "* You checked the \"Bully Once\" note.",
                    "* It says: [wait:30][pattern:english]end[pattern:chinese]."
                },
                drop = {
                    "* You threw away the \"Bully Once\" note.",
                    "[colorHEX:ffff99]* Bullying people is wrong."
                }
            },
            spider = {
                name = "[red]Spider",
                use = {
                    "* You took out the [colorHEX:ff0000]Spider[function:drawredSpider][colorHEX:ffffff] from your inventory."
                },
                inspect = {
                    "* Spider[wait:30] - maybe a giant crab.",
                    "* Generally speaking, I'm afraid of spiders."
                },
                drop = {
                    "* You threw away the Spider.",
                    "* But nothing happened."
                }
            },
            invisible_me = {
                name = "[yellow]Can't See Me",
                use = {
                    "* You used Can't See Me.",
                    "* ...But you still feel visible."
                },
                inspect = {
                    "* You checked Can't See Me.",
                    "* Maybe this item is trying very hard not to be noticed."
                },
                drop = {
                    "* You threw away Can't See Me."
                }
            }
        }
    },

    GameoverText = {
        "[voice:v_fluffybuns.wav][speed:0.5]* Our fate rests\n  upon you...",
        "[voice:v_fluffybuns.wav][speed:0.5]* %s!\n* Stay determined.",
    }
}
