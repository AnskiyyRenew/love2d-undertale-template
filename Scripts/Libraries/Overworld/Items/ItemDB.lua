local ItemDB = {}

ItemDB["[preset=chd]甜甜圈"] = {
    use = function(player, stat)
        local t = typers.CreateText({
            "* [pattern:chinese]你吃了甜甜圈。",
            "[colorHEX:9900ff]* [pattern:chinese]吃了。",
            "[noskip][function:RemoveBlocks][next]"
        }, {TPos(60, 400 - 55)}, 10004, {0, 0}, "manual")
        table.remove(stat.items, stat.initem)
    end,
    inspect = function(player, stat)
        local t = typers.CreateText({
            "* [pattern:chinese]你查看了甜甜圈。",
            "[colorHEX:9900ff]* [pattern:chinese]一个甜甜圈有什么好查看的？",
            "[noskip][function:RemoveBlocks][next]"
        }, {TPos(60, 400 - 55)}, 10004, {0, 0}, "manual")
    end,
    drop = function(player, stat)
        local t = typers.CreateText({
            "* [pattern:chinese]你丢弃了甜甜圈。",
            "[colorHEX:9900ff]* [pattern:chinese]对的，就是扔了。",
            "[noskip][function:RemoveBlocks][next]"
        }, {TPos(60, 400 - 55)}, 10004, {0, 0}, "manual")
        table.remove(stat.items, stat.initem)
    end
}

ItemDB["[preset=chd]神秘小礼物"] = {
    use = function(player, stat)
        local t = typers.CreateText({
            "* [pattern:chinese]你打开了神秘小礼物。",
            "* [pattern:chinese]里面有一个神秘的东西。",
            "* [pattern:chinese]噢，看起来是另一个小礼物！",
            "* [pattern:chinese]（你得到了神秘小小礼物。）",
            "[noskip][function:RemoveBlocks][next]"
        }, {TPos(60, 400 - 55)}, 10004, {0, 0}, "manual")
        table.remove(stat.items, stat.initem)
        table.insert(stat.items, "[preset=chd]神秘小小礼物")
    end,
    inspect = function(player, stat)
        local t = typers.CreateText({
            "* [pattern:chinese]你查看了神秘小礼物。",
            "[colorHEX:9900ff]* [pattern:chinese]打开它，看看里面有什么吧。",
            "[noskip][function:RemoveBlocks][next]"
        }, {TPos(60, 400 - 55)}, 10004, {0, 0}, "manual")
    end,
    drop = function(player, stat)
        local t = typers.CreateText({
            "* [pattern:chinese]你丢弃了神秘小礼物。",
            "[colorHEX:9900ff]* [pattern:chinese]但是小礼物又回去了！",
            "[noskip][function:RemoveBlocks][next]"
        }, {TPos(60, 400 - 55)}, 10004, {0, 0}, "manual")
    end
}

ItemDB["[preset=chd]神秘小小礼物"] = {
    use = function(player, stat)
        local t = typers.CreateText({
            "* [pattern:chinese]你打开了神秘小小礼物。",
            "* [pattern:chinese]噢，你被开了。",
            "* [pattern:chinese]（你得知你现在位于[pattern:english]" .. global:GetVariable("ROOM") .. "[pattern:chinese]房间中）",
            "[noskip][function:RemoveBlocks][next]"
        }, {TPos(60, 400 - 55)}, 10004, {0, 0}, "manual")
        table.remove(stat.items, stat.initem)
    end,
    inspect = function(player, stat)
        local t = typers.CreateText({
            "* [pattern:chinese]你查看了神秘小小礼物。",
            "[colorHEX:9900ff]* [pattern:chinese]打开它，看看里面有什么吧。",
            "[noskip][function:RemoveBlocks][next]"
        }, {TPos(60, 400 - 55)}, 10004, {0, 0}, "manual")
    end,
    drop = function(player, stat)
        local t = typers.CreateText({
            "* [pattern:chinese]你丢弃了神秘小小礼物。",
            "[colorHEX:9900ff]* [pattern:chinese]但是小礼物又回去了！",
            "[noskip][function:RemoveBlocks][next]"
        }, {TPos(60, 400 - 55)}, 10004, {0, 0}, "manual")
    end
}

ItemDB["[preset=chd]安黛因的信"] = {
    use = function(player, stat)
        local t = typers.CreateText({
            "* [pattern:chinese]你尝试打开安黛因的信。",
            "* [pattern:chinese]封的太死了，你打不开。",
            "[noskip][function:RemoveBlocks][next]"
        }, {TPos(60, 400 - 55)}, 10004, {0, 0}, "manual")
    end,
    inspect = function(player, stat)
        local t = typers.CreateText({
            "* [pattern:chinese]你查看了安黛因的信。",
            "* [pattern:chinese][voice:v_flowey.wav]嘿！[wait:30]看什么呢！？",
            "* [pattern:chinese]你吓得连忙把信放回包里。",
            "[noskip][function:RemoveBlocks][next]"
        }, {TPos(60, 400 - 55)}, 10004, {0, 0}, "manual")
    end,
    drop = function(player, stat)
        local t = typers.CreateText({
            "* [pattern:chinese]你丢弃了安黛因的信。",
            "[colorHEX:9900ff]* [pattern:chinese]信又跟了回去！",
            "[noskip][function:RemoveBlocks][next]"
        }, {TPos(60, 400 - 55)}, 10004, {0, 0}, "manual")
    end
}

ItemDB["[preset=chd]铁壶"] = {
    use = function(player, stat)
        local t = typers.CreateText({
            "* [pattern:chinese]你打开了铁壶。",
            "* [pattern:chinese][sound:snd_doghurt1.wav]嘭[sound:snd_slice.wav]啪[sound:snd_save.wav]嘭[sound:snd_menu_0.wav]啪[sound:snd_levelup.wav][sound:snd_ding.wav]！[sound:snd_dimbox.wav]霹[sound:snd_bomb.wav]雳[sound:snd_drumroll.wav]乓[sound:snd_icespell.ogg]啷[sound:snd_notice.wav][sound:snd_mysterygo.wav]！[sound:snd_mtt_burst.wav]呜[sound:snd_saber3.wav]呜[sound:snd_spawn_0.wav]渣[sound:snd_snowgrave.ogg]渣[sound:snd_warning_0.wav]！",
            "* [pattern:chinese]啊，多么好听的音乐啊。",
            "* [pattern:chinese]（你吓得赶紧把铁壶扔了。）",
            "[noskip][function:RemoveBlocks][next]"
        }, {TPos(60, 400 - 55)}, 10004, {0, 0}, "manual")
        table.remove(stat.items, stat.initem)
        global:SetVariable("KEY", true)
    end,
    inspect = function(player, stat)
        local t = typers.CreateText({
            "* [pattern:chinese]你查看了铁壶。",
            "* [pattern:chinese]这位铁壶看起来是一名音乐家。",
            "[noskip][function:RemoveBlocks][next]"
        }, {TPos(60, 400 - 55)}, 10004, {0, 0}, "manual")
    end,
    drop = function(player, stat)
        local t = typers.CreateText({
            "* [pattern:chinese]你丢弃了铁壶。",
            "[sound:snd_doghurt1.wav]* [pattern:chinese]看来音乐剧到此结束了。",
            "[noskip][function:RemoveBlocks][next]"
        }, {TPos(60, 400 - 55)}, 10004, {0, 0}, "manual")
    end
}

ItemDB["[preset=chd]别欺负我"] = {
    use = function(player, stat)
        local t = typers.CreateText({
            "* [pattern:chinese]你打开了别欺负我纸条。",
            "* [pattern:chinese]这是什么？[wait:30][pattern:english]end[pattern:chinese]？",
            "* [pattern:chinese][colorHEX:99ff99]捏一下。",
            "[noskip][function:RemoveBlocks][next]"
        }, {TPos(60, 400 - 55)}, 10004, {0, 0}, "manual")
        table.remove(stat.items, stat.initem)
        table.insert(stat.items, "[preset=chd]欺负一下")
    end,
    inspect = function(player, stat)
        local t = typers.CreateText({
            "* [pattern:chinese]你查看了别欺负我纸条。",
            "* [pattern:chinese]上面写着：[wait:30][pattern:english]end[pattern:chinese]。",
            "[noskip][function:RemoveBlocks][next]"
        }, {TPos(60, 400 - 55)}, 10004, {0, 0}, "manual")
    end,
    drop = function(player, stat)
        local t = typers.CreateText({
            "* [pattern:chinese]你丢弃了别欺负我纸条。",
            "[colorHEX:ffff99]* [pattern:chinese]欺负人可是不对的。",
            "[noskip][function:RemoveBlocks][next]"
        }, {TPos(60, 400 - 55)}, 10004, {0, 0}, "manual")
        table.remove(stat.items, stat.initem)
    end
}

ItemDB["[preset=chd]欺负一下"] = {
    use = function(player, stat)
        local t = typers.CreateText({
            "* [pattern:chinese]你打开了欺负一下纸条。",
            "* [pattern:chinese][colorHEX:ffff33][effect:shake, 1]你真该死啊。",
            "[noskip][function:RemoveBlocks][next]"
        }, {TPos(60, 400 - 55)}, 10004, {0, 0}, "manual")
        table.remove(stat.items, stat.initem)
    end,
    inspect = function(player, stat)
        local t = typers.CreateText({
            "* [pattern:chinese]你查看了欺负一下纸条。",
            "* [pattern:chinese]上面写着：[wait:30][pattern:english]end[pattern:chinese]。",
            "[noskip][function:RemoveBlocks][next]"
        }, {TPos(60, 400 - 55)}, 10004, {0, 0}, "manual")
    end,
    drop = function(player, stat)
        local t = typers.CreateText({
            "* [pattern:chinese]你丢弃了欺负一下纸条。",
            "[colorHEX:ffff99]* [pattern:chinese]欺负人可是不对的。",
            "[noskip][function:RemoveBlocks][next]"
        }, {TPos(60, 400 - 55)}, 10004, {0, 0}, "manual")
        table.remove(stat.items, stat.initem)
    end
}

ItemDB["[preset=chd]传单"] = {
    use = function(player, stat)
        OPENED_ARC = true
        RemoveBlocks()
        stat.page = "ARCPAGE"
        local poseur = sprites.CreateSprite("poseur.png", 20000 - 1)
        poseur:MoveTo(TPos(320, 240))
        stat.blocks[#stat.blocks + 1] = poseur
    end,
    inspect = function(player, stat)
        local t = typers.CreateText({
            "* [pattern:chinese]你查看了传单。",
            "* [pattern:chinese]是关于前五个丢失的孩子的。",
            "[noskip][function:RemoveBlocks][next]"
        }, {TPos(60, 400 - 55)}, 10004, {0, 0}, "manual")
    end,
    drop = function(player, stat)
        local t = typers.CreateText({
            "[colorHEX:ffff33]* [pattern:chinese]为了正义，请不要放弃。",
            "[noskip][function:RemoveBlocks][next]"
        }, {TPos(60, 400 - 55)}, 10004, {0, 0}, "manual")
    end
}

ItemDB["[preset=chd]吃我"] = {
    use = function(player, stat)
        local t = typers.CreateText({
            "* [pattern:chinese]这么想被吃就乖乖下肚。",
            "* [pattern:chinese]（血量回满了。）",
            "[noskip][function:RemoveBlocks][next]"
        }, {TPos(60, 400 - 55)}, 10004, {0, 0}, "manual")
        table.remove(stat.items, stat.initem)
        player.hp = player.maxhp
    end,
    inspect = function(player, stat)
        local t = typers.CreateText({
            "* [pattern:chinese]你查看了吃我。",
            "* [pattern:chinese]上面写着：[wait:30][pattern:english]eat me[pattern:chinese]。",
            "[noskip][function:RemoveBlocks][next]"
        }, {TPos(60, 400 - 55)}, 10004, {0, 0}, "manual")
    end,
    drop = function(player, stat)
        local t = typers.CreateText({
            "[colorHEX:ff0000]* [pattern:chinese]你丢弃了吃我。",
            "[noskip][function:RemoveBlocks][next]"
        }, {TPos(60, 400 - 55)}, 10004, {0, 0}, "manual")
        table.remove(stat.items, stat.initem)
    end
}

ItemDB["[preset=chd][red]蜘蛛"] = {
    use = function(player, stat)
        local t = typers.CreateText({
            "* [pattern:chinese]你从背包中拿出了[colorHEX:ff0000]蜘蛛[function:drawredSpider][colorHEX:ffffff]。",
            "[noskip][function:RemoveBlocks][function:runSpider][next]"
        }, {TPos(60, 400 - 55)}, 10004, {0, 0}, "manual")
        table.remove(stat.items, stat.initem)
    end,
    inspect = function(player, stat)
        local t = typers.CreateText({
            "* [pattern:chinese]蜘蛛[wait:30] - 也许是大螃蟹。",
            "* [pattern:chinese]总的来讲，我怕蜘蛛。",
            "[noskip][function:RemoveBlocks][next]"
        }, {TPos(60, 400 - 55)}, 10004, {0, 0}, "manual")
    end,
    drop = function(player, stat)
        local t = typers.CreateText({
            "* [pattern:chinese]你丢弃了蜘蛛。",
            "* [pattern:chinese]但是什么都没发生。",
            "[noskip][sound:snd_phurt.wav][function:RemoveBlocks][function:encounterSpider][next]"
        }, {TPos(60, 400 - 55)}, 10004, {0, 0}, "manual")
        table.remove(stat.items, stat.initem)
    end
}

return ItemDB