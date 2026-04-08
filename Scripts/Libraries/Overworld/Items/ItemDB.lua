local ItemDB = {}

local locales = {
    require("Localization.en"),
    require("Localization.zh_CN")
}

local aliasToId = {
    ["mystery_gift"] = "mystery_gift",
    ["tiny_mystery_gift"] = "tiny_mystery_gift",
    ["iron_kettle"] = "iron_kettle",
    ["eat_me"] = "eat_me",
    ["undyne_letter"] = "undyne_letter",
    ["flyer"] = "flyer",
    ["dont_bully_me"] = "dont_bully_me",
    ["bully_once"] = "bully_once",
    ["spider"] = "spider",
    ["invisible_me"] = "invisible_me",
    ["donut"] = "donut"
}

for _, lang in ipairs(locales) do
    if lang.Overworld and lang.Overworld.Items then
        for itemId, itemData in pairs(lang.Overworld.Items) do
            if itemData.name then
                aliasToId[itemData.name] = itemId
            end
        end
    end
end

local function getLocalizedItem(itemId)
    return localize.Overworld.Items[itemId]
end

local function createText(lines, args)
    local texts = {}
    for i = 1, #lines do
        if args then
            texts[i] = string.format(lines[i], unpack(args))
        else
            texts[i] = lines[i]
        end
    end
    texts[#texts + 1] = "[noskip][function:RemoveBlocks][next]"
    typers.CreateText(texts, {TPos(60, 400 - 55)}, 10004, {0, 0}, "manual")
end

function ItemDB.resolveKey(itemKey)
    if not itemKey then return itemKey end
    return aliasToId[itemKey] or itemKey
end

function ItemDB.getDisplayName(itemKey)
    local itemId = ItemDB.resolveKey(itemKey)
    local item = localize.Overworld.Items[itemId]
    return (item and item.name) or itemKey
end

local function defineItem(itemId, handlers)
    ItemDB[itemId] = handlers
end

defineItem("donut", {
    use = function(player, stat)
        createText(getLocalizedItem("donut").use)
        table.remove(stat.items, stat.initem)
    end,
    inspect = function(player, stat)
        createText(getLocalizedItem("donut").inspect)
    end,
    drop = function(player, stat)
        createText(getLocalizedItem("donut").drop)
        table.remove(stat.items, stat.initem)
    end
})

defineItem("mystery_gift", {
    use = function(player, stat)
        createText(getLocalizedItem("mystery_gift").use)
        table.remove(stat.items, stat.initem)
        table.insert(stat.items, "tiny_mystery_gift")
    end,
    inspect = function(player, stat)
        createText(getLocalizedItem("mystery_gift").inspect)
    end,
    drop = function(player, stat)
        createText(getLocalizedItem("mystery_gift").drop)
    end
})

defineItem("tiny_mystery_gift", {
    use = function(player, stat)
        createText(getLocalizedItem("tiny_mystery_gift").use, {global:GetVariable("ROOM")})
        table.remove(stat.items, stat.initem)
    end,
    inspect = function(player, stat)
        createText(getLocalizedItem("tiny_mystery_gift").inspect)
    end,
    drop = function(player, stat)
        createText(getLocalizedItem("tiny_mystery_gift").drop)
    end
})

defineItem("undyne_letter", {
    use = function(player, stat)
        createText(getLocalizedItem("undyne_letter").use)
    end,
    inspect = function(player, stat)
        createText(getLocalizedItem("undyne_letter").inspect)
    end,
    drop = function(player, stat)
        createText(getLocalizedItem("undyne_letter").drop)
    end
})

defineItem("iron_kettle", {
    use = function(player, stat)
        createText(getLocalizedItem("iron_kettle").use)
        table.remove(stat.items, stat.initem)
        global:SetVariable("KEY", true)
    end,
    inspect = function(player, stat)
        createText(getLocalizedItem("iron_kettle").inspect)
    end,
    drop = function(player, stat)
        createText(getLocalizedItem("iron_kettle").drop)
    end
})

defineItem("dont_bully_me", {
    use = function(player, stat)
        createText(getLocalizedItem("dont_bully_me").use)
        table.remove(stat.items, stat.initem)
        table.insert(stat.items, "bully_once")
    end,
    inspect = function(player, stat)
        createText(getLocalizedItem("dont_bully_me").inspect)
    end,
    drop = function(player, stat)
        createText(getLocalizedItem("dont_bully_me").drop)
        table.remove(stat.items, stat.initem)
    end
})

defineItem("bully_once", {
    use = function(player, stat)
        createText(getLocalizedItem("bully_once").use)
        table.remove(stat.items, stat.initem)
    end,
    inspect = function(player, stat)
        createText(getLocalizedItem("bully_once").inspect)
    end,
    drop = function(player, stat)
        createText(getLocalizedItem("bully_once").drop)
        table.remove(stat.items, stat.initem)
    end
})

defineItem("flyer", {
    use = function(player, stat)
        OPENED_ARC = true
        RemoveBlocks()
        stat.page = "ARCPAGE"
        local poseur = sprites.CreateSprite("poseur.png", 20000 - 1)
        poseur:MoveTo(TPos(320, 240))
        stat.blocks[#stat.blocks + 1] = poseur
    end,
    inspect = function(player, stat)
        createText(getLocalizedItem("flyer").inspect)
    end,
    drop = function(player, stat)
        createText(getLocalizedItem("flyer").drop)
    end
})

defineItem("eat_me", {
    use = function(player, stat)
        createText(getLocalizedItem("eat_me").use)
        table.remove(stat.items, stat.initem)
        player.hp = player.maxhp
    end,
    inspect = function(player, stat)
        createText(getLocalizedItem("eat_me").inspect)
    end,
    drop = function(player, stat)
        createText(getLocalizedItem("eat_me").drop)
        table.remove(stat.items, stat.initem)
    end
})

defineItem("spider", {
    use = function(player, stat)
        local texts = {
            getLocalizedItem("spider").use[1],
            "[noskip][function:RemoveBlocks][function:runSpider][next]"
        }
        typers.CreateText(texts, {TPos(60, 400 - 55)}, 10004, {0, 0}, "manual")
        table.remove(stat.items, stat.initem)
    end,
    inspect = function(player, stat)
        createText(getLocalizedItem("spider").inspect)
    end,
    drop = function(player, stat)
        local texts = {
            getLocalizedItem("spider").drop[1],
            getLocalizedItem("spider").drop[2],
            "[noskip][sound:snd_phurt.wav][function:RemoveBlocks][function:encounterSpider][next]"
        }
        typers.CreateText(texts, {TPos(60, 400 - 55)}, 10004, {0, 0}, "manual")
        table.remove(stat.items, stat.initem)
    end
})

defineItem("invisible_me", {
    use = function(player, stat)
        createText(getLocalizedItem("invisible_me").use)
    end,
    inspect = function(player, stat)
        createText(getLocalizedItem("invisible_me").inspect)
    end,
    drop = function(player, stat)
        createText(getLocalizedItem("invisible_me").drop)
        table.remove(stat.items, stat.initem)
    end
})

return ItemDB
