--- Overworld shop library: buy, sell, talk topics and the exit flow.
local shop = {
    data = (DATA and DATA.player) or {gold = 0, items = {}},
    background = Sprites.CreateSprite("px.png", -100),
    player = Sprites.CreateSprite("Soul Library Sprites/spr_default_heart.png", 2),
    main_text = {},
    end_text = nil,

    sellable = true,
    no_sell_text = nil,

    cannot_sell_text = nil,

    talk_opinion = nil,

    max_items = 8,

    main_width = 560,
    opinion_width = 170,
    intro_width = 182,
    auto_wrap = true,

    new_color = {1, 1, 0},

    _leavekey = false,
}

--- Localize with an explicit fallback; extra arguments go to string.format for
--- both the localized value and the fallback.
---@param key string
---@param ... any
---@param fallback string
local function L(key, fallback, ...)
    local count = select("#", ...)
    local args = nil
    if (count > 0) then args = {...} end

    local text = Localize.localizeText(key, args)
    if (text ~= nil) then return text end

    if (count > 0) then
        local ok, result = pcall(string.format, fallback, unpack(args))
        if (ok) then return result end
    end
    return fallback
end

shop.main_text = {L("Overworld.Shop.Text.Greeting", "* ...")}
shop.end_text  = L("Overworld.Shop.Text.Leave", "* See you later.")
shop.no_sell_text = L("Overworld.Shop.Text.NoSelling", "* Sorry, I'm not buying\n  anything right now.")
shop.main = Typers.EText.New(shop.main_text, {40, 260}, 5, {shop.main_width, 0}, "none")
shop.main.auto_wrap = shop.auto_wrap

local main_alive = true
local function ensureMain()
    if (shop.main and main_alive) then return shop.main end
    shop.main = Typers.EText.New("", {40, 260}, 5, {shop.main_width, 0}, "none")
    shop.main.auto_wrap = shop.auto_wrap
    main_alive = true
    return shop.main
end

local blacktop = Sprites.CreateSprite("px.png", 100)
blacktop:Scale(1000, 1000)
blacktop.color = {0, 0, 0}
blacktop:MoveTo(Camera.x, Camera.y)
blacktop._decay = true
blacktop.Step = function (self)
    self:MoveTo(Camera.x, Camera.y)
    if (self._decay) then
        self.alpha = self.alpha - 0.05
        if (shop._leaving) then
            self._decay = false
        end
        if (self.alpha <= 0) then
            self._decay = false
        end
    else
        if (self.alpha >= 1) then
            self._decay = true
        end
    end

    if (shop._leaving) then
        self.alpha = self.alpha + 0.05

        if (self.alpha >= 1) then
            Scenes.switchTo(DATA.room)
        end
    end
end
Audio.Clear()

local white = Sprites.CreateSprite("px.png", 0)
white.ypivot = 1
white.y = 480
white:Scale(640, 240)
local black = Sprites.CreateSprite("px.png", 0)
black.y = white.y - white.yscale / 2
black:Scale(630, 230)
black.color = {0, 0, 0}
local line = Sprites.CreateSprite("px.png", 0)
line:Scale(5, 230)
line.y = black.y
line.x = 430
shop.player.color = {1, 0, 0}

local gwhite = Sprites.CreateSprite("px.png", -2)
gwhite.y = 340
gwhite:Scale(212, 170)
gwhite.x = 640 - gwhite.xscale / 2
local gblack = Sprites.CreateSprite("px.png", -2)
gblack.x = gwhite.x
gblack.y = gwhite.y
gblack:Scale(202, 160)
gblack.color = {0, 0, 0}

local t_intro = Typers.InstText.New("", {
    gwhite.x - gwhite.xscale / 2 + 20,
    280
}, -1, {shop.intro_width, 0})
t_intro.auto_wrap = shop.auto_wrap

local actions = {
    "Buy",
    "Sell",
    "Talk",
    "Exit"
}
local buttons = {}
for i = 1, 4
do
    local t = Typers.InstText.New(Localize.localizeText("Overworld.Shop.Action." .. actions[i]), {485, 260 + (i - 1) * 40}, 1)
    table.insert(buttons, t)
end
local t_gold = Typers.InstText.New("0G", {465, 420}, 1)
local t_inv = Typers.InstText.New("0/" .. shop.max_items, {600, 420}, 1)
t_inv:SetAlign("right")

local goods_per_page = 5
local goods_buttons = {}
for i = 1, goods_per_page
do
    local t = Typers.InstText.New("", {75, 260 + (i - 1) * 40}, 1)
    table.insert(goods_buttons, t)
end
local row_color = goods_buttons[1].color or {1, 1, 1}
local goods_default_color = {row_color[1], row_color[2], row_color[3]}

local opinion_text = Typers.EText.New("", {460, 260}, 2, {shop.opinion_width, 0}, "none")
opinion_text.auto_wrap = shop.auto_wrap

--- Push the width / wrapping config into the three text panels and re-lay out
--- what they show. EText only needs its `size` field; InstText pre-renders, so
--- the intro panel needs Rebuild().
local function applyTextWidths()
    if (shop.main) then
        shop.main.size = {shop.main_width, 0}
        shop.main.auto_wrap = shop.auto_wrap
    end

    opinion_text.size = {shop.opinion_width, 0}
    opinion_text.auto_wrap = shop.auto_wrap
    if (opinion_text.texts) then opinion_text:SetText(opinion_text.texts) end

    t_intro.size = {shop.intro_width, 0}
    t_intro.auto_wrap = shop.auto_wrap
    t_intro:Rebuild()
end

local goods = {}
local amounts = {}
local prices = {buy = {}, sell = {}}
local opinions = {buy = {}, sell = {}, talk = {}}
local introductions = {}
local refusals = {}
local talks = {}
local queues = {}

local states = {"BUY", "SELL", "TALK"}
local choosing_page = "IDLE"
local choosing_b = 1
local choosing_a = 1
local goods_startpos = 0
local list = {}
local message_return = "IDLE"
local input_lock = false

local text_pointer = Typers.InstText.New("1 / 1", {10, 460}, 2)
text_pointer.font = "Crypt Of Tomorrow.ttf"
text_pointer.fontsize = 16
text_pointer.alpha = 0

local function updateTextPointer()
    local current = math.min(goods_startpos + choosing_a, #list)
    if (#list <= 0) then current = 0 end
    text_pointer:SetText(current .. " / " .. #list)
end

local function findItem(id)
    local db = ITEMS
    if (db and db.FindItemByID) then
        return db.FindItemByID(id)
    end
end

local function defaultOpinion()
    return L("Overworld.Shop.Opinion.Default", "* ...")
end

--- Aside shown next to the topic list when nothing was configured for it.
local function defaultTalkOpinion()
    return L("Overworld.Shop.TalkOpinion.Default", "What do you\nwant to talk about?")
end

--- Fill an item / topic name into author copy ("I don't need any %s."). A
--- stray "%" must not crash the shop; a list returns a list.
---@param text table
---@param name string
local function fillName(text, name)
    if (type(text) == "table") then
        local out = {}
        for i = 1, #text
        do
            out[i] = fillName(text[i], name)
        end
        return out
    end

    if (type(text) ~= "string") then return text end
    if (not text:find("%%")) then return text end

    local ok, result = pcall(string.format, text, name or "")
    if (ok) then return result end
    return text
end

--- The line played when the shop will not take `id`: per-item override, then
--- shop-wide default, then localization.
---@param id string
---@param name string
local function cannotSellText(id, name)
    local text = refusals[id]
    if (text == nil) then text = shop.cannot_sell_text end
    if (text == nil) then
        text = L("Overworld.Shop.Text.CannotSell", "* I'm not buying that one.")
    end
    return fillName(text, name)
end

--- The aside shown next to the topic list for `topic`: per-topic override, then
--- shop-wide default, then localization.
local function talkOpinionText(topic)
    local text = (topic ~= nil) and opinions.talk[topic] or nil
    if (text == nil) then text = shop.talk_opinion end
    if (text == nil) then text = defaultTalkOpinion() end
    return fillName(text, topic)
end

local function refreshStatus()
    local d = shop.data or {}
    t_gold:SetText((d.gold or 0) .. "G")
    t_inv:SetText(#(d.items or {}) .. "/" .. shop.max_items)
end

--- A topic body may be a string or a list of lines; always normalized to a list,
--- because EText walks a list one entry per confirm press.
---@param text table
local function normalizeTexts(text)
    if (type(text) == "table") then
        local out = {}
        for i = 1, #text
        do
            out[i] = tostring(text[i] or "")
        end
        if (#out <= 0) then out[1] = "" end
        return out
    end
    return {tostring(text or "")}
end

--- Never read yet. Drives which member a queue is on.
---@param entry table
---@return boolean
local function isUnread(entry)
    return (entry ~= nil and (entry.seen or 0) <= 0)
end

--- Carries the "(New)" tag, which a topic only earns when a queue reveals it.
---@param entry table
---@return boolean
local function isFlaggedNew(entry)
    return (entry ~= nil and entry.fresh == true)
end

--- Turn a queue reference (topic name or 1-based index) into its entry.
--- Resolved lazily, so SetQueue may run before or after AddTalk.
local function resolveTalkRef(ref)
    if (type(ref) == "table") then return ref end
    if (type(ref) == "number") then return talks[ref] end

    local name = tostring(ref or "")
    for i = 1, #talks
    do
        if (talks[i].topic == name) then return talks[i] end
    end
end

--- The entries a queue currently covers, in declaration order.
---@param q table
local function queueTopics(q)
    local out = {}
    for i = 1, #q.refs
    do
        local entry = resolveTalkRef(q.refs[i])
        if (entry) then out[#out + 1] = entry end
    end
    return out
end

--- The one entry a queue is showing: first unread wins, otherwise the cursor
--- rotates.
---@param q table
local function queueCurrent(q)
    local topics = queueTopics(q)
    local n = #topics
    if (n <= 0) then return nil end

    for i = 1, n
    do
        if (isUnread(topics[i])) then return topics[i] end
    end

    q.cursor = ((q.cursor - 1) % n) + 1
    return topics[q.cursor]
end

--- True when a topic belongs to a queue and is not the member it is on: exactly
--- one member of a queue is ever listed.
---@return boolean
local function isTalkHidden(entry)
    if (not entry) then return false end

    for i = 1, #queues
    do
        local topics = queueTopics(queues[i])
        for j = 1, #topics
        do
            if (topics[j] == entry) then
                return (queueCurrent(queues[i]) ~= entry)
            end
        end
    end
    return false
end

--- Record that a topic has been read and move its queue past it; whatever it
--- reveals next gets the "(New)" tag, but only on its first reveal.
---@param entry table
local function markTalkRead(entry)
    if (not entry) then return end
    entry.seen = (entry.seen or 0) + 1
    entry.fresh = false

    for i = 1, #queues
    do
        local topics = queueTopics(queues[i])
        for j = 1, #topics
        do
            if (topics[j] == entry) then
                local q = queues[i]
                q.cursor = (j % #topics) + 1

                local revealed = queueCurrent(q)
                if (isUnread(revealed)) then
                    revealed.fresh = true
                end
                return
            end
        end
    end
end

--- Build the rows shown by the given state.
---@param state string "BUY" | "SELL" | "TALK"
---@return table rows {id, name, price, sold_out, text}
local function buildList(state)
    local result = {}

    if (state == "BUY") then
        for i = 1, #goods
        do
            local id = goods[i].id
            result[i] = {
                id = id,
                name = goods[i].name,
                price = shop.GetBuyPrice(id),
                sold_out = shop.IsSoldOut(id)
            }
        end
    elseif (state == "SELL") then
        local items = (shop.data and shop.data.items) or {}
        for i = 1, #items
        do
            local item = findItem(items[i])
            result[i] = {
                id = items[i],
                name = (item and item.name) or tostring(items[i]),
                price = shop.GetSellPrice(items[i]),
                sold_out = false
            }
        end
    elseif (state == "TALK") then
        for i = 1, #talks
        do
            local entry = talks[i]
            if (not isTalkHidden(entry)) then
                result[#result + 1] = {
                    id = entry.topic,
                    name = entry.topic,
                    price = nil,
                    sold_out = false,
                    texts = entry.texts,
                    seen = entry.seen or 0,
                    is_new = isFlaggedNew(entry),
                    entry = entry
                }
            end
        end
    end

    return result
end

local function rowText(row, state)
    if (state == "TALK") then
        if (row.is_new) then
            return "* " .. row.name .. " " .. L("Overworld.Shop.Text.New", "(New)")
        end
        return "* " .. row.name
    end

    local text = "* " .. row.name
    if (state == "BUY" and row.sold_out) then
        return text .. " " .. L("Overworld.Shop.Text.SoldOut", "Sold Out")
    end
    if (row.price ~= nil) then
        text = text .. "  " .. row.price .. "G"
    end
    return text
end

--- Keep the cursor inside the current list (used after a sale shrinks it).
local function clampCursor()
    local total = #list

    if (total <= 0) then
        goods_startpos = 0
        choosing_a = 1
        return
    end

    goods_startpos = math.max(0, math.min(goods_startpos, math.max(0, total - goods_per_page)))
    if (goods_startpos + choosing_a > total) then
        choosing_a = total - goods_startpos
    end
    choosing_a = math.max(1, math.min(choosing_a, math.min(goods_per_page, total)))
end

local function updateButtons()
    for i = 1, goods_per_page
    do
        local t = goods_buttons[i]
        local row = list[i + goods_startpos]
        if (row) then
            local c = goods_default_color
            if (choosing_page == "TALK" and row.is_new) then
                c = shop.new_color or {1, 1, 0}
            end
            t:SetColor(c[1], c[2], c[3])
            t:SetText(rowText(row, choosing_page))
            t.alpha = 1
        else
            t:SetText("")
            t.alpha = 0
        end
    end
    updateTextPointer()
end

--- Right-hand text: the keeper's opinion of the highlighted item, or their aside
--- about the topic on the TALK page, plus the intro panel.
local function updateSelectionText()
    if (choosing_page == "TALK") then
        local row = list[goods_startpos + choosing_a]
        opinion_text:SetText(talkOpinionText(row and row.id or nil))
        t_intro:SetText("")
        return
    end

    if (choosing_page ~= "BUY" and choosing_page ~= "SELL") then
        opinion_text:SetText("")
        t_intro:SetText("")
        return
    end

    local row = list[goods_startpos + choosing_a]
    if (not row) then
        opinion_text:SetText("")
        t_intro:SetText("")
        return
    end

    opinion_text:SetText(shop.GetOpinion(row.id))
    t_intro:SetText(shop.GetIntroduction(row.id))
end

--- Slide the intro panel in (up) or out of view (down); "down" hides it behind
--- the main board.
local function moveIntroPanel(up)
    local board_y = (up and 160 or 340)
    local text_y = (up and 100 or 280)

    Tween.Clear()
    Tween.CreateTween(function (v)
        gwhite.y = v
        gblack.y = v
    end, "Quad", "Out", gwhite.y, board_y, 20)
    Tween.CreateTween(function (v)
        t_intro.y = v
    end, "Quad", "Out", t_intro.y, text_y, 20)
end

local function createElements(state)
    if (state == "IDLE") then
        for i = 1, #buttons
        do
            buttons[i].alpha = 1
        end
        line.alpha = 1
        shop.player.alpha = 1
        t_gold.alpha = 1
        t_inv.alpha = 1
        text_pointer.alpha = 0

        list = {}
        for i = 1, goods_per_page
        do
            goods_buttons[i]:SetText("")
            goods_buttons[i].alpha = 0
        end
        updateTextPointer()

        opinion_text:SetText("")
        t_intro:SetText("")
        ensureMain():SetText(shop.main_text)
        moveIntroPanel(false)
    else
        for i = 1, #buttons
        do
            buttons[i].alpha = 0
        end
        line.alpha = 1
        shop.player.alpha = 1
        t_gold.alpha = 1
        t_inv.alpha = 1
        text_pointer.alpha = 1

        list = buildList(state)
        clampCursor()
        updateButtons()
        refreshStatus()
        updateSelectionText()
        moveIntroPanel(state ~= "TALK")
    end
end

local function hideElements()
    for i = 1, #buttons
    do
        buttons[i].alpha = 0
    end
    line.alpha = 0
    shop.player.alpha = 0
    t_gold.alpha = 0
    t_inv.alpha = 0
    text_pointer.alpha = 0

    for i = 1, goods_per_page
    do
        goods_buttons[i]:SetText("")
        goods_buttons[i].alpha = 0
    end

    opinion_text:SetText("")
    t_intro:SetText("")
    moveIntroPanel(false)
end

--- Hand the screen to the main typer for one line, then go back to
--- `return_state`.
---@param text string
---@param return_state string
local function showMessage(text, return_state)
    message_return = return_state or "IDLE"
    choosing_page = "MESSAGE"
    hideElements()

    local main = ensureMain()
    main._onComplete = nil
    main:SetText(text)
    main.mode = "manual"
    main._onComplete = function ()
        main._onComplete = nil
        main_alive = false
        input_lock = true
        ensureMain()
        choosing_page = message_return
        createElements(message_return)
    end
end

local function leaveShop()
    choosing_page = "EXITING"
    hideElements()

    local main = ensureMain()
    main._onComplete = nil
    main:SetText(shop.end_text)
    main.mode = "manual"
    main._onComplete = function ()
        main._onComplete = nil
        main_alive = false
        shop._leaving = true
    end
end

local function tryBuy()
    local row = list[goods_startpos + choosing_a]
    if (not row) then return end

    if (row.sold_out) then
        Audio.PlaySound("snd_menu_0.wav")
        return
    end

    local d = shop.data or {}
    d.items = d.items or {}
    d.gold = d.gold or 0

    if (#d.items >= shop.max_items) then
        showMessage(L("Overworld.Shop.Text.InvFull", "* Your inventory is full."), "BUY")
        return
    end

    local price = shop.GetBuyPrice(row.id)
    if (d.gold < price) then
        showMessage(L("Overworld.Shop.Text.NoGold", "* You don't have enough gold."), "BUY")
        return
    end

    d.gold = d.gold - price
    table.insert(d.items, row.id)
    if (amounts[row.id]) then
        amounts[row.id] = math.max(0, amounts[row.id] - 1)
    end

    Audio.PlaySound("snd_buyitem.wav")
    refreshStatus()

    list = buildList("BUY")
    clampCursor()
    updateButtons()
    opinion_text:SetText(L("Overworld.Shop.Text.Bought", "* You bought %s for %sG.", row.name, price))
end

local function trySell()
    local index = goods_startpos + choosing_a
    local row = list[index]
    if (not row) then return end

    local price = shop.GetSellPrice(row.id)
    if (price <= 0) then
        Audio.PlaySound("snd_menu_0.wav")
        showMessage(cannotSellText(row.id, row.name), "SELL")
        return
    end

    local d = shop.data or {}
    d.items = d.items or {}
    d.gold = d.gold or 0

    d.gold = d.gold + price
    table.remove(d.items, index)

    Audio.PlaySound("snd_buyitem.wav")
    refreshStatus()

    list = buildList("SELL")
    clampCursor()
    updateButtons()
    updateSelectionText()
    opinion_text:SetText(L("Overworld.Shop.Text.Sold", "* You sold %s for %sG.", row.name, price))
end

function shop.GetPlayer()
    return shop.player
end

function shop.GetBackground()
    return shop.background
end

--- Text shown behind the menu while idle.
---@param text string|table
function shop.SetMainText(text)
    shop.main_text = (type(text) == "table") and text or {text}
    ensureMain():SetText(shop.main_text)
end

function shop.GetMainText()
    return shop.main_text
end

--- Line said when the player picks "Exit".
---@param text string|table
function shop.SetEndText(text)
    shop.end_text = text
end

function shop.GetEndText()
    return shop.end_text
end

--- Replace the whole stock list. Every id is resolved through ITEMS.
---@param g table array of item ids
function shop.SetGoods(g)
    goods = {}

    if (type(g) ~= "table") then return end
    for i = 1, #g
    do
        shop.AddGoods(g[i])
    end
end

function shop.AddGoods(g)
    local item = findItem(g)
    if (item) then
        goods[#goods + 1] = {id = item.id, name = item.name}
    else
        print("[Shop] Unknown item id: " .. tostring(g))
    end
end

function shop.RemoveGoods(index)
    table.remove(goods, index)
end

function shop.GetGoods()
    return goods
end

--- Remaining stock of an item. `nil` (or never calling SetAmount) means the
--- shop never runs out of it; 0 marks it as sold out.
---@param id string
---@param amount number|nil
function shop.SetAmount(id, amount)
    if (amount == nil) then
        amounts[id] = nil
    else
        amounts[id] = math.max(0, amount)
    end
end

---@return number remaining stock; math.huge when unlimited.
---@param id string
function shop.GetAmount(id)
    local amount = amounts[id]
    if (amount == nil) then return math.huge end
    return amount
end

function shop.IsSoldOut(id)
    local amount = amounts[id]
    return (amount ~= nil and amount <= 0)
end

function shop.SetBuyPrice(id, price)
    prices.buy[id] = price
end

function shop.GetBuyPrice(id)
    return (prices.buy[id] or 0)
end

--- The shopkeeper's remark about an item, typed into the right-hand column.
--- Panel copy, not dialogue: it must NOT carry the "* " prefix (that also
--- triggers EText's hanging indent and pushes the text off the column).
---@param id string
---@param opinion string
function shop.SetBuyOpinion(id, opinion)
    opinions.buy[id] = opinion
end

function shop.GetBuyOpinion(id)
    return (opinions.buy[id] or defaultOpinion())
end

function shop.SetSellPrice(id, price)
    prices.sell[id] = price
end

--- Sell price, defaulting to half of the buy price (rounded down) when the
--- scene never set one explicitly.
---@param id number
---@return number
function shop.GetSellPrice(id)
    local price = prices.sell[id]
    if (price ~= nil) then return price end
    return math.floor((shop.GetBuyPrice(id) or 0) / 2)
end

function shop.SetSellOpinion(id, opinion)
    opinions.sell[id] = opinion
end

function shop.GetSellOpinion(id)
    return (opinions.sell[id] or defaultOpinion())
end

--- Aside typed into the right-hand column while the topic list is open. Panel
--- copy, so it must NOT carry the "* " prefix. Two forms: one argument sets the
--- shop-wide default; (topic, opinion) sets a per-topic override.
function shop.SetTalkOpinion(topic, opinion)
    if (opinion == nil) then
        shop.talk_opinion = topic
        return
    end
    opinions.talk[tostring(topic)] = opinion
end

--- The aside that would be shown for `topic`, after falling back through the
--- shop-wide default to the localization. "%s" is filled in with the topic.
---@param topic string|nil
---@return string|nil
function shop.GetTalkOpinion(topic)
    return talkOpinionText((topic == nil) and nil or tostring(topic))
end

--- Bulk version: SetTalkOpinions({weather = "Talking about the weather again?", time = "..."}).
---@param map table
function shop.SetTalkOpinions(map)
    if (type(map) ~= "table") then return end
    for k, v in pairs(map)
    do
        opinions.talk[tostring(k)] = v
    end
end

function shop.GetTalkOpinions()
    return opinions.talk
end

--- Drop every per-topic aside. The shop-wide default (if any) stays.
function shop.ClearTalkOpinions()
    opinions.talk = {}
end

--- Opinion for whichever list is open right now.
---@param id string
function shop.GetOpinion(id)
    if (choosing_page == "SELL") then
        return shop.GetSellOpinion(id)
    end
    if (choosing_page == "TALK") then
        return shop.GetTalkOpinion(id)
    end
    return shop.GetBuyOpinion(id)
end

--- Short blurb shown in the sliding panel while an item is highlighted.
---@param id string
---@param text string
function shop.SetIntroduction(id, text)
    introductions[id] = text
end

function shop.GetIntroduction(id)
    return introductions[id] or ""
end

--- Bulk version: SetIntroductions({CrabApple = "+20 HP", HotCat = "+12 HP"}).
---@param map table
function shop.SetIntroductions(map)
    if (type(map) ~= "table") then return end
    for k, v in pairs(map)
    do
        introductions[k] = v
    end
end

--- Whether this shop buys from the player. When false, "Sell" reads
--- `no_sell_text` instead of opening the inventory list.
function shop.SetSellable(value)
    shop.sellable = (value and true or false)
end

function shop.IsSellable()
    return shop.sellable
end

function shop.SetNoSellText(text)
    shop.no_sell_text = text
end

--- What the keeper says when asked to buy an item they will not take (sell
--- price 0). One argument sets the shop-wide default; (id, text) overrides one
--- item. "%s" is filled with the item name; a list plays one line per confirm.
---@param id string
---@param text string
function shop.SetCannotSellText(id, text)
    if (text == nil) then
        shop.cannot_sell_text = (type(id) == "table") and id or tostring(id or "")
        return
    end
    refusals[tostring(id)] = text
end

--- The line for `id` after falling back to the shop-wide default and the
--- localization; "%s" is filled with the item name.
---@param id string
function shop.GetCannotSellText(id)
    local item = findItem(id)
    local name = (item and item.name) or tostring(id or "")
    return cannotSellText(id, name)
end

--- Bulk version: SetCannotSellTexts({Stick = "...", Bandage = {"...", "..."}}).
---@param map table
function shop.SetCannotSellTexts(map)
    if (type(map) ~= "table") then return end
    for k, v in pairs(map)
    do
        refusals[tostring(k)] = v
    end
end

function shop.GetCannotSellTexts()
    return refusals
end

--- Drop every per-item line. The shop-wide default (if any) stays.
function shop.ClearCannotSellTexts()
    refusals = {}
end

--- Add a talk topic. The body may be one line or a list, played one line per
--- confirm press.
---@return integer the new topic count
---@param topic table
---@param text string
function shop.AddTalk(topic, text)
    local entry
    if (type(topic) == "table") then
        entry = {
            topic = tostring(topic.topic or topic[1] or ""),
            texts = normalizeTexts(topic.texts or topic.text or topic[2])
        }
    else
        entry = {
            topic = tostring(topic or ""),
            texts = normalizeTexts(text)
        }
    end
    entry.seen = 0
    entry.fresh = false
    table.insert(talks, entry)
    return #talks
end

--- Replace every topic. Accepts an array of entries or a topic -> body map;
--- a body may be a string or a list of lines.
---@param list_ table
function shop.SetTalks(list_)
    talks = {}
    if (type(list_) ~= "table") then return end

    if (#list_ > 0) then
        for i = 1, #list_
        do
            shop.AddTalk(list_[i])
        end
    else
        for k, v in pairs(list_)
        do
            shop.AddTalk(k, v)
        end
    end
end

function shop.RemoveTalk(index)
    table.remove(talks, index)
end

function shop.ClearTalks()
    talks = {}
end

function shop.GetTalks()
    return talks
end

--- Tie topics into a queue: only ONE member is ever listed, the one the
--- conversation has reached. Reading it reveals the next; after the last one,
--- the queue starts over. Members are topic names or 1-based indexes, resolved
--- lazily, and each call adds one independent queue.
---@return integer the new queue count
---@param ... any
function shop.SetQueue(...)
    local refs = {...}
    if (#refs == 1 and type(refs[1]) == "table") then
        local inner = refs[1]
        refs = {}
        for i = 1, #inner
        do
            refs[i] = inner[i]
        end
    end

    queues[#queues + 1] = {refs = refs, cursor = 1}
    return #queues
end

--- Replace every queue at once: SetQueues({{"weather", "time"}, {"exit", "secret"}}).
---@param list_ table
function shop.SetQueues(list_)
    queues = {}
    if (type(list_) ~= "table") then return end
    for i = 1, #list_
    do
        shop.SetQueue(list_[i])
    end
end

function shop.ClearQueues()
    queues = {}
end

function shop.GetQueues()
    return queues
end

--- The talk rows as they are listed right now, queues already collapsed.
---@return table {{topic = ..., texts = {...}, seen = n, is_new = bool}}
function shop.GetVisibleTalks()
    local rows = buildList("TALK")
    local out = {}
    for i = 1, #rows
    do
        out[i] = {
            topic = rows[i].name,
            texts = rows[i].texts,
            seen = rows[i].seen or 0,
            is_new = rows[i].is_new and true or false
        }
    end
    return out
end

--- True while the topic carries the "(New)" tag, i.e. a queue has just
--- revealed it and it has not been read since.
---@param index number
function shop.IsTalkNew(index)
    return isFlaggedNew(resolveTalkRef(index))
end

--- Force the "(New)" tag on a topic on or off. Handy for topics that sit
--- outside any queue, since those never get tagged on their own.
---@param index number
---@param value any
function shop.SetTalkNew(index, value)
    local entry = resolveTalkRef(index)
    if (not entry) then return end
    entry.fresh = (value and true or false)
    if (choosing_page == "TALK") then updateButtons() end
end

--- True while the topic has never been read at all.
---@param index number
function shop.IsTalkUnread(index)
    return isUnread(resolveTalkRef(index))
end

--- Mark a topic read (true) / unread (false) and drop its "(New)" tag. Unread
--- members jump to the front of their queue, which is how a save restores
--- conversation progress.
---@param index number
---@param seen boolean
function shop.SetTalkSeen(index, seen)
    local entry = resolveTalkRef(index)
    if (not entry) then return end
    entry.seen = (seen and 1) or 0
    entry.fresh = false
end

--- Forget every topic's read state; each queue starts over from its first one.
function shop.ResetTalkProgress()
    for i = 1, #talks
    do
        talks[i].seen = 0
        talks[i].fresh = false
    end
    for i = 1, #queues
    do
        queues[i].cursor = 1
    end
end

--- Colour a "(New)" topic is listed in. Defaults to UNDERTALE yellow.
function shop.SetNewColor(r, g, b)
    shop.new_color = {tonumber(r) or 1, tonumber(g) or 1, tonumber(b) or 0}
    if (choosing_page == "TALK") then updateButtons() end
end

function shop.SetMaxItems(count)
    shop.max_items = (tonumber(count) and math.max(1, math.floor(count))) or shop.max_items
end

function shop.GetMaxItems()
    return shop.max_items
end

--- Width of the main text box (greeting, refusals, talk bodies). Default 560
--- (board is x=40..600).
---@param width number
function shop.SetMainTextWidth(width)
    shop.main_width = math.max(0, tonumber(width) or shop.main_width)
    applyTextWidths()
    if (choosing_page == "IDLE") then
        ensureMain():SetText(shop.main_text)
    end
end

--- Width of the right-hand column the shopkeeper's opinion is typed into.
--- Default 170 (x=460..630).
---@param width number
function shop.SetOpinionWidth(width)
    shop.opinion_width = math.max(0, tonumber(width) or shop.opinion_width)
    applyTextWidths()
end

--- Width of the sliding goods-introduction panel. Default 182 (x=448..630).
---@param width number
function shop.SetIntroWidth(width)
    shop.intro_width = math.max(0, tonumber(width) or shop.intro_width)
    applyTextWidths()
end

--- All three at once: SetTextWidths(main, opinion, intro). `nil` keeps the
--- current value.
---@param main_width number
---@param opinion_width number
---@param intro_width number
function shop.SetTextWidths(main_width, opinion_width, intro_width)
    if (main_width) then shop.main_width = math.max(0, tonumber(main_width) or shop.main_width) end
    if (opinion_width) then shop.opinion_width = math.max(0, tonumber(opinion_width) or shop.opinion_width) end
    if (intro_width) then shop.intro_width = math.max(0, tonumber(intro_width) or shop.intro_width) end
    applyTextWidths()
    if (choosing_page == "IDLE") then
        ensureMain():SetText(shop.main_text)
    end
end

--- Master switch for automatic line breaking (on by default).
---@param enabled boolean
function shop.SetAutoWrap(enabled)
    shop.auto_wrap = (enabled and true or false)
    applyTextWidths()
    if (choosing_page == "IDLE") then
        ensureMain():SetText(shop.main_text)
    end
end

function shop.IsAutoWrap()
    return shop.auto_wrap
end

function shop.GetGold()
    return ((shop.data and shop.data.gold) or 0)
end

function shop.SetGold(value)
    if (shop.data) then
        shop.data.gold = value
        refreshStatus()
    end
end

--- Redraw the gold / inventory readouts and, when a list is open, its rows.
function shop.Refresh()
    refreshStatus()
    if (choosing_page == "BUY" or choosing_page == "SELL" or choosing_page == "TALK") then
        list = buildList(choosing_page)
        clampCursor()
        updateButtons()
        updateSelectionText()
    end
end

function shop.Update(dt)
    if (shop._leaving) then return end

    if (input_lock) then
        input_lock = false
        return
    end

    if (choosing_page == "MESSAGE" or choosing_page == "EXITING") then
        return
    end

    if (Controller.GetState("confirm") == 1) then
        Audio.PlaySound("snd_menu_1.wav")
        ensureMain():SetText("")

        if (choosing_page == "IDLE") then
            if (choosing_b == 1) then
                choosing_page = "BUY"
            elseif (choosing_b == 2) then
                if (not shop.sellable) then
                    showMessage(shop.no_sell_text, "IDLE")
                    return
                end
                if (#((shop.data and shop.data.items) or {}) <= 0) then
                    showMessage(L("Overworld.Shop.Text.NoItems", "* You have nothing to sell."), "IDLE")
                    return
                end
                choosing_page = "SELL"
            elseif (choosing_b == 3) then
                if (#talks <= 0) then
                    showMessage(L("Overworld.Shop.Text.NoTalk", "* Nothing to talk about."), "IDLE")
                    return
                end
                choosing_page = "TALK"
            else
                leaveShop()
                return
            end

            if (states[choosing_b]) then
                choosing_a = 1
                goods_startpos = 0
            end
            createElements(choosing_page)
        elseif (choosing_page == "BUY") then
            tryBuy()
        elseif (choosing_page == "SELL") then
            trySell()
        elseif (choosing_page == "TALK") then
            local row = list[goods_startpos + choosing_a]
            if (row) then
                markTalkRead(row.entry)
                showMessage(row.texts, "TALK")
            end
        end
    elseif (Controller.GetState("cancel") == 1) then
        if (choosing_page == "BUY" or choosing_page == "SELL" or choosing_page == "TALK") then
            Audio.PlaySound("snd_menu_0.wav")
            choosing_page = "IDLE"
            createElements("IDLE")
        end
    end

    if (choosing_page == "IDLE") then
        if (Controller.GetState("down") == 1) then
            Audio.PlaySound("snd_menu_0.wav")
            choosing_b = math.min(choosing_b + 1, 4)
        elseif (Controller.GetState("up") == 1) then
            Audio.PlaySound("snd_menu_0.wav")
            choosing_b = math.max(choosing_b - 1, 1)
        end
        shop.player:MoveTo(465, 278 + (choosing_b - 1) * 40)
    elseif (choosing_page == "BUY" or choosing_page == "SELL" or choosing_page == "TALK") then
        if (Controller.GetState("down") == 1) then
            Audio.PlaySound("snd_menu_0.wav")
            if (choosing_a < goods_per_page and goods_startpos + choosing_a < #list) then
                choosing_a = choosing_a + 1
            elseif (choosing_a == goods_per_page and goods_startpos + goods_per_page < #list) then
                goods_startpos = goods_startpos + 1
            end
            updateButtons()
            updateSelectionText()
        elseif (Controller.GetState("up") == 1) then
            Audio.PlaySound("snd_menu_0.wav")
            if (choosing_a > 1) then
                choosing_a = choosing_a - 1
            elseif (goods_startpos > 0) then
                goods_startpos = goods_startpos - 1
                choosing_a = 1
            end
            updateButtons()
            updateSelectionText()
        end
        shop.player:MoveTo(55, 278 + (choosing_a - 1) * 40)
    end
end

function shop.Clear()
    if (shop.main) then shop.main._onComplete = nil end
    if (opinion_text) then opinion_text._onComplete = nil end

    ClearModuleTree("Scripts.Libraries.Overworld.shop")
end

refreshStatus()

return shop
