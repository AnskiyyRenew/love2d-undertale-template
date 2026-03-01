local stat = {
    page = "NONE",
    inbutton = 1,
    initem = 1,
    initemc = 1,
    incell = 1,
    interact = 0,
    under = false,
    blocks = {},
    temps = {},
    heart = nil,

    statpage = nil,
    itempage = nil,

    levelData = {
        { lv = 1,  hp = 20,  at = 10,  df = 10,  nextExp = 10,    totalExp = 0     },
        { lv = 2,  hp = 24,  at = 12,  df = 10,  nextExp = 20,    totalExp = 10    },
        { lv = 3,  hp = 28,  at = 14,  df = 10,  nextExp = 40,    totalExp = 30    },
        { lv = 4,  hp = 32,  at = 16,  df = 10,  nextExp = 50,    totalExp = 70    },
        { lv = 5,  hp = 36,  at = 18,  df = 11,  nextExp = 80,    totalExp = 120   },
        { lv = 6,  hp = 40,  at = 20,  df = 11,  nextExp = 100,   totalExp = 200   },
        { lv = 7,  hp = 44,  at = 22,  df = 11,  nextExp = 200,   totalExp = 300   },
        { lv = 8,  hp = 48,  at = 24,  df = 11,  nextExp = 300,   totalExp = 500   },
        { lv = 9,  hp = 52,  at = 26,  df = 12,  nextExp = 400,   totalExp = 800   },
        { lv = 10, hp = 56,  at = 28,  df = 12,  nextExp = 500,   totalExp = 1200  },
        { lv = 11, hp = 60,  at = 30,  df = 12,  nextExp = 800,   totalExp = 1700  },
        { lv = 12, hp = 64,  at = 32,  df = 12,  nextExp = 1000,  totalExp = 2500  },
        { lv = 13, hp = 68,  at = 34,  df = 13,  nextExp = 1500,  totalExp = 3500  },
        { lv = 14, hp = 72,  at = 36,  df = 13,  nextExp = 2000,  totalExp = 5000  },
        { lv = 15, hp = 76,  at = 38,  df = 13,  nextExp = 3000,  totalExp = 7000  },
        { lv = 16, hp = 80,  at = 40,  df = 13,  nextExp = 5000,  totalExp = 10000 },
        { lv = 17, hp = 84,  at = 42,  df = 14,  nextExp = 10000, totalExp = 15000 },
        { lv = 18, hp = 88,  at = 44,  df = 14,  nextExp = 25000, totalExp = 25000 },
        { lv = 19, hp = 92,  at = 46,  df = 14,  nextExp = 49999, totalExp = 50000 },
        { lv = 20, hp = 99,  at = 48,  df = 14,  nextExp = nil,   totalExp = 99999 }
    },

    getPlayerLevel = function(self, currentExp)
        if currentExp >= 99999 then
            return 20
        end
        for i = #self.levelData, 1, -1 do
            if currentExp >= self.levelData[i].totalExp then
                return self.levelData[i].lv
            end
        end
        return 1
    end,

    getNextExp = function(self, currentLv)
        if currentLv >= 20 then return nil end
        print(currentLv)
        return self.levelData[currentLv + 1].totalExp
    end,

    getTotalExp = function(self, currentLv)
        return self.levelData[currentLv].totalExp
    end
}
local OPENED_ARC = false
local spidermoving = false
local spidertime = 0
local spidertext = nil
local spiderencounter = false

function TPos(x, y)
    return _CAMERA_.x + x, _CAMERA_.y + y
end

function drawredSpider()
    spidertext = typers.DrawText("[preset=chd][offsetX=20][red]蜘蛛", {TPos(312, 344)}, 10004)
end

function runSpider()
    spidermoving = true
end

function encounterSpider()
    spiderencounter = true
    local bg = sprites.CreateSprite("bg.png", 2000000)
    bg:Scale(99, 99)
    bg:MoveTo(TPos(320, 240))
    -- oworld.CSTATE = "Controlling"
end

-- ITEMs = 335 * 350
-- STAT  = 335 * 410
-- CELL  = 335 * 255

function RemoveBlocks()
    stat.heart:Destroy()
    for i = #stat.blocks, 1, -1
    do
        local block = stat.blocks[i]
        if (block.white and block.black) then
            block.white:Destroy()
            block.black:Destroy()
        else
            block:Destroy()
        end
        table.remove(stat.blocks, i)
    end
    stat.page = "NONE"
    oworld.CSTATE = "Controlling"

    stat.initem = 1
    stat.initemc = 1
    stat.inbutton = 1
end

local function RemoveBlock(block)
    for k, v in pairs(stat.blocks)
    do
        if (v == block) then
            if (block.white and block.black) then
                block.white:Destroy()
                block.black:Destroy()
            else
                block:Destroy()
            end
            table.remove(stat.blocks, k)
        end
    end
end

local function CreateBlock(x, y, w, h, r)
    local block = {}

    block.white = sprites.CreateSprite("px.png", 10000)
    block.black = sprites.CreateSprite("px.png", 10001)
    block.black.color = {0, 0, 0}

    block.white:Scale(w + 10, h + 10)
    block.black:Scale(w, h)

    block.white:MoveTo(x, y)
    block.black:MoveTo(x, y)

    table.insert(stat.blocks, block)
    return block
end

local function DrawText(text, x, y)
    local sentence = typers.DrawText(text, {x, y}, 10002)
    table.insert(stat.blocks, sentence)
    return sentence
end

function stat:Update(dt)

    Player = DATA.player
    stat.items = DATA.player.items
    stat.cells = DATA.player.cells
    stat.getcell = DATA.player.getcell

    if (stat.page == "IDLE") then
        if (keyboard.GetState("down") == 1) then
            audio.PlaySound("snd_menu_0.wav", 1)
            stat.inbutton = math.min(stat.inbutton + 1, 3)
            if (not stat.getcell) then stat.inbutton = math.min(stat.inbutton, 2) end
        elseif (keyboard.GetState("up") == 1) then
            audio.PlaySound("snd_menu_0.wav", 1)
            stat.inbutton = math.max(stat.inbutton - 1, 1)
        end
        stat.heart:MoveTo(TPos(65, 208 + (stat.inbutton - 1) * 35))
    end
    if (stat.page == "ITEM") then
        if (keyboard.GetState("down") == 1) then
            audio.PlaySound("snd_menu_0.wav", 1)
            stat.initem = math.min(stat.initem + 1, #stat.items)
        elseif (keyboard.GetState("up") == 1) then
            audio.PlaySound("snd_menu_0.wav", 1)
            stat.initem = math.max(stat.initem - 1, 1)
        end
        stat.heart:MoveTo(TPos(212, 88 + (stat.initem - 1) * 35))
    end
    if (stat.page == "CELL") then
        if (keyboard.GetState("down") == 1) then
            audio.PlaySound("snd_menu_0.wav", 1)
            stat.incell = math.min(stat.incell + 1, #stat.cells)
        elseif (keyboard.GetState("up") == 1) then
            audio.PlaySound("snd_menu_0.wav", 1)
            stat.incell = math.max(stat.incell - 1, 1)
        end
        stat.heart:MoveTo(TPos(212, 88 + (stat.incell - 1) * 35))
    end
    if (stat.page == "ITEMC") then
        if (keyboard.GetState("right") == 1) then
            audio.PlaySound("snd_menu_0.wav", 1)
            stat.initemc = math.min(stat.initemc + 1, 3)
        elseif (keyboard.GetState("left") == 1) then
            audio.PlaySound("snd_menu_0.wav", 1)
            stat.initemc = math.max(stat.initemc - 1, 1)
        end
        stat.heart:MoveTo(TPos(212 + (stat.initemc - 1) * 95, 378))
    end

    if (keyboard.GetState("menu") == 1 and oworld.CSTATE == "Controlling") then
        if (stat.page == "NONE") then
            audio.PlaySound("snd_menu_0.wav", 1)
            stat.page = "IDLE"
            oworld.CSTATE = "Stopping"
            stat.inbutton = 1
            stat.heart = sprites.CreateSprite("Soul Library Sprites/spr_default_heart.png", 10003)
            stat.heart.color = {1, 0, 0}
            stat.heart:MoveTo(TPos(65, 208))
            stat.heart:Scale(1, 1)

            local x, y = TPos(100, 240)
            local dy = 134
            CreateBlock(x, y, 132, 138, 0)
            if (not stat.under) then
                CreateBlock(x, y - dy, 132, 100, 0)

                local info_name = DrawText("[spaceX=-2]" .. Player.name, TPos(43, 60))
                local info_lv = DrawText("LV  " .. Player.lv, TPos(45, 105 - 3))
                info_lv.font = "Crypt Of Tomorrow.ttf"
                info_lv.fontsize = 16
                info_lv:Reparse()
                local info_hp = DrawText("HP  " .. Player.hp .. "/" .. Player.maxhp, TPos(45, 123 - 3))
                info_hp.font = "Crypt Of Tomorrow.ttf"
                info_hp.fontsize = 16
                info_hp:Reparse()
                local info_gold = DrawText("G   " .. Player.gold, TPos(45, 140 - 3))
                info_gold.font = "Crypt Of Tomorrow.ttf"
                info_gold.fontsize = 16
                info_gold:Reparse()

                local items = DrawText("[preset=chd]物品", TPos(110, 190))
                local state = DrawText("[preset=chd]状态", TPos(110, 225))
                local cells = DrawText("[preset=chd]电话", TPos(110, 260))

                if (#stat.items == 0) then items.color = {.5, .5, .5} items:Reparse() end
                if (#stat.cells == 0) then cells.color = {.5, .5, .5} cells:Reparse() end
                if (not stat.getcell) then RemoveBlock(cells) end
            else
                CreateBlock(x, y + dy, 132, 100, 0)
            end
        elseif (stat.page == "IDLE") then
            stat.page = "NONE"
            oworld.CSTATE = "Controlling"
            RemoveBlocks()
        end
    end
    if (keyboard.GetState("confirm") == 1) then
        if (stat.page == "CELL") then
            stat.page = "CELLD"
            stat.cellpage.white:Destroy()
            stat.cellpage.black:Destroy()
            stat.heart.alpha = 0
            for i = #stat.temps, 1, -1
            do
                local temp = stat.temps[i]
                temp:Destroy()
                table.remove(stat.temps, i)
            end

            local x, y = TPos(320, 400)
            CreateBlock(x, y, 575, 140, 0)
            local current_user = require("Scripts.Libraries.Overworld.Phone.Toriel")
            local texts = current_user:GetDialog()
            texts = (type(texts) == "string") and {texts} or texts

            local t = typers.CreateText({
                unpack(texts),
                "[noskip][function:RemoveBlocks][next]"
            }, {TPos(60, 400 - 55)}, 10004, {0, 0}, "manual")
        end
        if (stat.page == "ITEMC") then
            -- use the item.
            local x, y = TPos(320, 400)
            CreateBlock(x, y, 575, 140, 0)
            local item = stat.items[stat.initem]
            stat:UseItem(item, stat.initemc)
            stat.heart.alpha = 0
            stat.itempage.white:Destroy()
            stat.itempage.black:Destroy()
            for i = #stat.temps, 1, -1
            do
                local temp = stat.temps[i]
                temp:Destroy()
                table.remove(stat.temps, i)
            end
            stat.page = "ITEMD"
        end
        if (stat.page == "ITEM") then
            stat.page = "ITEMC"
        end
        if (stat.page == "IDLE") then
            if (stat.inbutton == 1 and #stat.items > 0) then -- item page.
                audio.PlaySound("snd_menu_1.wav", 1)
                stat.page = "ITEM"
                local x, y = TPos(360, 230)
                stat.itempage = CreateBlock(x, y, 335, 350, 0)

                for i = 1, #stat.items
                do
                    stat.temps[i] = DrawText(stat.items[i], x - 130, y - 160 + (i - 1) * 35)
                end
                stat.temps[#stat.temps + 1] = DrawText("[preset=chd][offsetX=20]使用     查看     丢弃", x - 150, y + 130)
            elseif (stat.inbutton == 2) then -- stat page.
                audio.PlaySound("snd_menu_1.wav", 1)
                stat.page = "STAT"
                local x, y = TPos(365, 260)
                stat.heart.alpha = 0
                stat.statpage = CreateBlock(x, y, 335, 410, 0)

                local atkspace, defspace = "   ", "   "
                if (Player.atk > 9) then atkspace = atkspace:sub(1, -2) end
                if (Player.watk > 9) then atkspace = atkspace:sub(1, -2) end
                if (Player.def > 9) then defspace = defspace:sub(1, -2) end
                if (Player.edef > 9) then defspace = defspace:sub(1, -2) end

                stat.temps[#stat.temps + 1] = DrawText("\"" .. Player.name .. "\"", x - 150, y - 180)
                stat.temps[#stat.temps + 1] = DrawText("LV " .. Player.lv, x - 150, y - 120)
                stat.temps[#stat.temps + 1] = DrawText("HP " .. Player.hp .. "/" .. Player.maxhp, x - 150, y - 90)
                stat.temps[#stat.temps + 1] = DrawText("AT " .. Player.atk .. "(" .. Player.watk .. ")" .. atkspace .. "EXP:" .. Player.exp, x - 150, y - 20)
                stat.temps[#stat.temps + 1] = DrawText("DF " .. Player.def ..  "(" .. Player.edef .. ")" .. defspace .. "NEXT:" .. (stat:getNextExp(Player.lv) or 0) - Player.exp, x - 150, y + 10)
                stat.temps[#stat.temps + 1] = DrawText("[preset=chd][offsetX=0]武器： " .. Player.weapon, x - 150, y + 70)
                stat.temps[#stat.temps + 1] = DrawText("[preset=chd][offsetX=0]防具： " .. Player.armor, x - 150, y + 100)
                stat.temps[#stat.temps + 1] = DrawText("[preset=chd][offsetX=0]金钱：", x - 150, y + 150)
                stat.temps[#stat.temps + 1] = DrawText(Player.gold, x - 65, y + 150)
            elseif (stat.inbutton == 3 and #stat.cells > 0) then
                audio.PlaySound("snd_menu_1.wav", 1)
                stat.page = "CELL"

                local x, y = TPos(360, 230)
                stat.cellpage = CreateBlock(x, y, 335, 350, 0)

                for i = 1, #stat.cells
                do
                    stat.temps[i] = DrawText(stat.cells[i], x - 130, y - 160 + (i - 1) * 35)
                end
            else
                audio.PlaySound("snd_phurt.wav")
            end
        end
    end
    if (keyboard.GetState("cancel") == 1) then
        if (stat.page == "IDLE") then
            stat.page = "NONE"
            oworld.CSTATE = "Controlling"
            RemoveBlocks()
        elseif (stat.page == "ITEM" or stat.page == "STAT" or stat.page == "CELL") then
            stat.initem = 1
            audio.PlaySound("snd_menu_0.wav", 1)
            if (stat.page == "STAT") then
                stat.statpage.white:Destroy()
                stat.statpage.black:Destroy()
                for i = #stat.temps, 1, -1
                do
                    local temp = stat.temps[i]
                    temp:Destroy()
                    table.remove(stat.temps, i)
                end
            elseif (stat.page == "ITEM") then
                stat.itempage.white:Destroy()
                stat.itempage.black:Destroy()
                for i = #stat.temps, 1, -1
                do
                    local temp = stat.temps[i]
                    temp:Destroy()
                    table.remove(stat.temps, i)
                end
            elseif (stat.page == "CELL") then
                stat.cellpage.white:Destroy()
                stat.cellpage.black:Destroy()

                for i = #stat.temps, 1, -1
                do
                    local temp = stat.temps[i]
                    temp:Destroy()
                    table.remove(stat.temps, i)
                end
            end
            stat.page = "IDLE"
            stat.heart.alpha = 1
        elseif (stat.page == "ITEMC") then
            audio.PlaySound("snd_menu_0.wav", 1)
            stat.page = "ITEM"
            stat.initemc = 1
        end
    end



    -- 此处为拓展区域。
    if (OPENED_ARC) then
        if (keyboard.GetState("cancel") == 1) then
            OPENED_ARC = false
            stat.page = "NONE"
            oworld.CSTATE = "Controlling"
            RemoveBlocks()
        end
    end

    if (spidermoving) then
        spidertime = spidertime + 1
        if (spidertime == 10) then
            tween.CreateTween(
                function (value)
                    spidertext.x = value
                end,
                "Back", "In", spidertext.x, _CAMERA_.x + 1200, 120
            )
        elseif (spidertime == 121) then
            spidertext:Destroy()
            spidermoving = false
            spidertime = 0
        end
    end

    if (spiderencounter) then
        oworld.CSTATE = "Stopping"
        spidertime = spidertime + 1
        if (spidertime == 60) then
            DATA.savedpos = true
            DATA.position = {
                oworld.char.currentSprite.x,
                oworld.char.currentSprite.y + 20,
            }
            DATA.direction = oworld.char.direction
            if (global:GetVariable("OverworldBGM")) then
                local ins = global:GetVariable("OverworldBGM")
                ins:Destroy()
            end
            scenes.switchTo("Battle/scene_battle_spider")
        end
    end
end

local ItemDB = require("Scripts.Libraries.Overworld.Items.ItemDB")
function stat:UseItem(itemKey, choice)
    local item = ItemDB[itemKey]
    if not item then
        print("Undefined item: ", itemKey)
        return
    end

    local actionFunc
    if choice == 1 then actionFunc = item.use
    elseif choice == 2 then actionFunc = item.inspect
    elseif choice == 3 then actionFunc = item.drop
    end

    if actionFunc then
        actionFunc(DATA.player, self)
    end
end

return stat