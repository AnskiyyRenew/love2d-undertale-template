return {
    EncounterText = "*[pattern:chinese] 你什么都没遭遇到！",
    Enemies = {
        Poseur = {
            Name = "[preset=chinese]颇似儿",
            Actions = {
                "[preset=chd]查看", "[preset=chd]欣赏"
            }
        },
        TheOther = {
            Name = "[preset=chinese]敌人名称",
            Actions = {
                "[preset=chd]查看", "[preset=chd]欣赏"
            }
        },
    },
    Items = {
        Chocolate = "[preset=chd]巧克力",
        End = "[preset=chd]我是你的老婆"
    },
    ItemsPage = "[preset=chd]第  页[font=determination_mono.ttf][scale=1]%s",
    Spare = "[preset=chd]饶恕",
    Flee = "[preset=chd]逃跑",

    FleeTexts = {
        "* [pattern:chinese]你逃出了战斗。\n[pattern:english]* [pattern:chinese]你感到神清气爽。"
    },

    Act11 = {
        "* [pattern:chinese]颇似儿[pattern:english] - 1 [pattern:chinese]攻[pattern:english] 99 [pattern:chinese]防[wait:30][pattern:english] \n* [pattern:chinese]默认敌人.", 
        "[colorHEX:9900ff]* [pattern:chinese]承载着温暖的回忆..."
    },
    Act12 = {
        "* [pattern:chinese]你和颇似儿一起摆姿势。\n[pattern:english][colorHEX:00ffff]* [pattern:chinese]时间似乎静止在了这一刻...", 
        "* [pattern:chinese]享受这段时光吧！"
    },
    Act21 = {
        "* [pattern:chinese]敌人名称[pattern:english] - 1 [pattern:chinese]攻[pattern:english] 99 [pattern:chinese]防[wait:30][pattern:english] \n* [pattern:chinese]默认敌人的朋友.", 
        "[colorHEX:9900ff]* [pattern:chinese]也承载着温暖的回忆..."
    },
    Act22 = {
        "* [pattern:chinese]你和不知名的敌人一起摆姿势。\n[pattern:english][colorHEX:00ffff]* [pattern:chinese]时间似乎静止在了这一刻...", 
        "[colorHEX:99ff99]* [pattern:chinese]享受这段时光吧！！！"
    },

    Overworld = {
        Menu = {
            Items = "[preset=chd][offsetX=0]物品",
            Stats = "[preset=chd][offsetX=0]状态",
            Cell = "[preset=chd][offsetX=0]电话",
            ItemActions = "[preset=chd][offsetX=20]使用       查看       丢弃",
            WeaponLabel = "[preset=chd][offsetX=0]武器： ",
            ArmorLabel = "[preset=chd][offsetX=0]防具： ",
            GoldLabel = "[preset=chd][offsetX=0]金钱：",
            BoxTitle = "[preset=chinese]物品栏                  箱子",
            UseBoxPrompt = "* [pattern:chinese]要使用箱子吗？[space:2, 20]\n\n             是                     否[function:player_choosing_start|chestbox,%d]",
            SaveOptions = "保存       取消",
            SaveSuccess = "保存成功",
            SavePreview = "%s    LV %d    %02d:%02d"
        },
        Equipment = {
            weapon = {
                stick = "[preset=chinese][offsetX=90]木棍"
            },
            armor = {
                bandage = "[preset=chinese][offsetX=90]绷带"
            }
        },
        Items = {
            donut = {
                name = "[preset=chd]甜甜圈",
                use = {
                    "* [pattern:chinese]你吃了甜甜圈。",
                    "[colorHEX:9900ff]* [pattern:chinese]吃了。"
                },
                inspect = {
                    "* [pattern:chinese]你查看了甜甜圈。",
                    "[colorHEX:9900ff]* [pattern:chinese]一个甜甜圈有什么好查看的？"
                },
                drop = {
                    "* [pattern:chinese]你丢弃了甜甜圈。",
                    "[colorHEX:9900ff]* [pattern:chinese]对的，就是扔了。"
                }
            },
            mystery_gift = {
                name = "[preset=chd]神秘小礼物",
                use = {
                    "* [pattern:chinese]你打开了神秘小礼物。",
                    "* [pattern:chinese]里面有一个神秘的东西。",
                    "* [pattern:chinese]噢，看起来是另一个小礼物！",
                    "* [pattern:chinese]（你得到了神秘小小礼物。）"
                },
                inspect = {
                    "* [pattern:chinese]你查看了神秘小礼物。",
                    "[colorHEX:9900ff]* [pattern:chinese]打开它，看看里面有什么吧。"
                },
                drop = {
                    "* [pattern:chinese]你丢弃了神秘小礼物。",
                    "[colorHEX:9900ff]* [pattern:chinese]但是小礼物又回去了！"
                }
            },
            tiny_mystery_gift = {
                name = "[preset=chd]神秘小小礼物",
                use = {
                    "* [pattern:chinese]你打开了神秘小小礼物。",
                    "* [pattern:chinese]噢，你被开了。",
                    "* [pattern:chinese]（你得知你现在位于[pattern:english]%s[pattern:chinese]房间中）"
                },
                inspect = {
                    "* [pattern:chinese]你查看了神秘小小礼物。",
                    "[colorHEX:9900ff]* [pattern:chinese]打开它，看看里面有什么吧。"
                },
                drop = {
                    "* [pattern:chinese]你丢弃了神秘小小礼物。",
                    "[colorHEX:9900ff]* [pattern:chinese]但是小礼物又回去了！"
                }
            },
            iron_kettle = {
                name = "[preset=chd]铁壶",
                use = {
                    "* [pattern:chinese]你打开了铁壶。",
                    "* [pattern:chinese][sound:snd_doghurt1.wav]嘭[sound:snd_slice.wav]啪[sound:snd_save.wav]嘭[sound:snd_menu_0.wav]啪[sound:snd_levelup.wav][sound:snd_ding.wav]！[sound:snd_dimbox.wav]霹[sound:snd_bomb.wav]雳[sound:snd_drumroll.wav]乓[sound:snd_icespell.ogg]啷[sound:snd_notice.wav][sound:snd_mysterygo.wav]！[sound:snd_mtt_burst.wav]呜[sound:snd_saber3.wav]呜[sound:snd_spawn_0.wav]渣[sound:snd_snowgrave.ogg]渣[sound:snd_warning_0.wav]！",
                    "* [pattern:chinese]啊，多么好听的音乐啊。",
                    "* [pattern:chinese]（你吓得赶紧把铁壶扔了。）"
                },
                inspect = {
                    "* [pattern:chinese]你查看了铁壶。",
                    "* [pattern:chinese]这位铁壶看起来是一名音乐家。"
                },
                drop = {
                    "* [pattern:chinese]你丢弃了铁壶。",
                    "[sound:snd_doghurt1.wav]* [pattern:chinese]看来音乐剧到此结束了。"
                }
            },
            eat_me = {
                name = "[preset=chd]吃我",
                use = {
                    "* [pattern:chinese]这么想被吃就乖乖下肚。",
                    "* [pattern:chinese]（血量回满了。）"
                },
                inspect = {
                    "* [pattern:chinese]你查看了吃我。",
                    "* [pattern:chinese]上面写着：[wait:30][pattern:english]eat me[pattern:chinese]。"
                },
                drop = {
                    "[colorHEX:ff0000]* [pattern:chinese]你丢弃了吃我。"
                }
            },
            undyne_letter = {
                name = "[preset=chd]安黛因的信",
                use = {
                    "* [pattern:chinese]你尝试打开安黛因的信。",
                    "* [pattern:chinese]封的太死了，你打不开。"
                },
                inspect = {
                    "* [pattern:chinese]你查看了安黛因的信。",
                    "* [pattern:chinese][voice:v_flowey.wav]嘿！[wait:30]看什么呢！？",
                    "* [pattern:chinese]你吓得连忙把信放回包里。"
                },
                drop = {
                    "* [pattern:chinese]你丢弃了安黛因的信。",
                    "[colorHEX:9900ff]* [pattern:chinese]信又跟了回去！"
                }
            },
            flyer = {
                name = "[preset=chd]传单",
                inspect = {
                    "* [pattern:chinese]你查看了传单。",
                    "* [pattern:chinese]是关于前五个丢失的孩子的。"
                },
                drop = {
                    "[colorHEX:ffff33]* [pattern:chinese]为了正义，请不要放弃。"
                }
            },
            dont_bully_me = {
                name = "[preset=chd]别欺负我",
                use = {
                    "* [pattern:chinese]你打开了别欺负我纸条。",
                    "* [pattern:chinese]这是什么？[wait:30][pattern:english]end[pattern:chinese]？",
                    "* [pattern:chinese][colorHEX:99ff99]捏一下。"
                },
                inspect = {
                    "* [pattern:chinese]你查看了别欺负我纸条。",
                    "* [pattern:chinese]上面写着：[wait:30][pattern:english]end[pattern:chinese]。"
                },
                drop = {
                    "* [pattern:chinese]你丢弃了别欺负我纸条。",
                    "[colorHEX:ffff99]* [pattern:chinese]欺负人可是不对的。"
                }
            },
            bully_once = {
                name = "[preset=chd]欺负一下",
                use = {
                    "* [pattern:chinese]你打开了欺负一下纸条。",
                    "* [pattern:chinese][colorHEX:ffff33][effect:shake, 1]你真该死啊。"
                },
                inspect = {
                    "* [pattern:chinese]你查看了欺负一下纸条。",
                    "* [pattern:chinese]上面写着：[wait:30][pattern:english]end[pattern:chinese]。"
                },
                drop = {
                    "* [pattern:chinese]你丢弃了欺负一下纸条。",
                    "[colorHEX:ffff99]* [pattern:chinese]欺负人可是不对的。"
                }
            },
            spider = {
                name = "[preset=chd][red]蜘蛛",
                use = {
                    "* [pattern:chinese]你从背包中拿出了[colorHEX:ff0000]蜘蛛[function:drawredSpider][colorHEX:ffffff]。"
                },
                inspect = {
                    "* [pattern:chinese]蜘蛛[wait:30] - 也许是大螃蟹。",
                    "* [pattern:chinese]总的来讲，我怕蜘蛛。"
                },
                drop = {
                    "* [pattern:chinese]你丢弃了蜘蛛。",
                    "* [pattern:chinese]但是什么都没发生。"
                }
            },
            invisible_me = {
                name = "[preset=chd][yellow]看不见我",
                use = {
                    "* [pattern:chinese]你使用了看不见我。",
                    "* [pattern:chinese]……但你好像还是看得见。"
                },
                inspect = {
                    "* [pattern:chinese]你查看了看不见我。",
                    "* [pattern:chinese]也许这件物品正在努力不被发现。"
                },
                drop = {
                    "* [pattern:chinese]你丢弃了看不见我。"
                }
            }
        }
    },

    GameoverText = {
        "[voice:v_fluffybuns.wav][speed:0.5]* [pattern:chinese]我们的命运\n  都寄托于你...",
        "[voice:v_fluffybuns.wav][speed:0.5]* %s!\n* [pattern:chinese]保持你的决心.",
    }
}
