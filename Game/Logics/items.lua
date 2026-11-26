local db = {
    {id = "Test", name = " "},
    {id = "Spider", name = "Spider", _color = {0.5, 1, 0}},
    {id = "MonsterCandy", name = "Monster Candy"},
    {id = "CroquetRoll", name = "Croquet Roll"},
    {id = "Stick", name = "Stick"},
    {id = "Bandage", name = "Bandage"},
    {id = "RockCandy", name = "Rock Candy"},
    {id = "PumpkinRings", name = "Pumpkin Rings"},
    {id = "SpiderDonut", name = "Spider Donut"},
    {id = "StoicOnion", name = "Stoic Onion"},
    {id = "GhostFruit", name = "Ghost Fruit"},
    {id = "SpiderCider", name = "Spider Cider"},
    {id = "ButterscotchPie", name = "Pie"},
    {id = "FadedRibbon", name = "Faded Ribbon"},
    {id = "ToyKnife", name = "Toy Knife"},
    {id = "ToughGlove", name = "Tough Glove"},
    {id = "ManlyBandanna", name = "Manly Bandanna"},
    {id = "SnowmanPiece", name = "Snowman Piece"},
    {id = "NiceCream", name = "Nice Cream"},
    {id = "PuppydoughIcecream", name = "Puppydough Icecream"},
    {id = "Bisicle", name = "Bisicle"},
    {id = "Unisicle", name = "Unisicle"},
    {id = "CinnamonBun", name = "Cinnamon Bun"},
    {id = "TemmieFlakes", name = "Temmie Flakes"},
    {id = "AbandonedQuiche", name = "Abandoned Quiche"},
    {id = "OldTutu", name = "Old Tutu"},
    {id = "BalletShoes", name = "Ballet Shoes"},
    {id = "PunchCard", name = "Punch Card"},
    {id = "AnnoyingDog", name = "Annoying Dog"},
    {id = "DogSalad", name = "Dog Salad"},
    {id = "DogResidue1", name = "Dog Residue"},
    {id = "DogResidue2", name = "Dog Residue"},
    {id = "DogResidue3", name = "Dog Residue"},
    {id = "DogResidue4", name = "Dog Residue"},
    {id = "DogResidue5", name = "Dog Residue"},
    {id = "DogResidue6", name = "Dog Residue"},
    {id = "AstronautFood", name = "Astronaut Food"},
    {id = "InstantNoodles", name = "Instant Noodles"},
    {id = "CrabApple", name = "Crab Apple"},
    {id = "HotDog...?", name = "Hot Dog...?"},
    {id = "HotCat", name = "Hot Cat"},
    {id = "Glamburger", name = "Glamburger"},
    {id = "SeaTea", name = "Sea Tea"},
    {id = "Starfait", name = "Starfait"},
    {id = "LegendaryHero", name = "Legendary Hero"},
    {id = "CloudyGlasses", name = "Cloudy Glasses"},
    {id = "TornNotebook", name = "Torn Notebook"},
    {id = "StainedApron", name = "Stained Apron"},
    {id = "BurntPan", name = "Burnt Pan"},
    {id = "CowboyHat", name = "Cowboy Hat"},
    {id = "EmptyGun", name = "Empty Gun"},
    {id = "HeartLocket", name = "Heart Locket"},
    {id = "WornDagger", name = "Worn Dagger"},
    {id = "RealKnife", name = "Real Knife"},
    {id = "TheLocket", name = "The Locket"},
    {id = "BadMemory", name = "Bad Memory"},
    {id = "Dream", name = "Dream"},
    {id = "UndynesLetter", name = "Undyne's Letter"},
    {id = "UndyneLetterEX", name = "Undyne Letter EX"},
    {id = "PopatoChisps", name = "Popato Chisps"},
    {id = "JunkFood", name = "Junk Food"},
    {id = "MysteryKey", name = "Mystery Key"},
    {id = "FaceSteak", name = "Face Steak"},
    {id = "HushPuppy", name = "Hush Puppy"},
    {id = "SnailPie", name = "Snail Pie"},
    {id = "temyarmor", name = "temy armor"},
}

local function drop_item(id)
    for i = #DATA.player.items, 1, -1 do
        if (DATA.player.items[i] == id) then
            table.remove(DATA.player.items, i)
            return
        end
    end
end

--- Full-screen sprite: takes control, and [X] destroys it and gives control back
--- (listens via the sprite's own Step callback).
---@param path string
local function show_sprite(path)
    Char.controlling = false
    local spr = Sprites.CreateSprite(path, "GUI")
    spr.Step = function(self)
        if (Controller.GetState("cancel") == 1) then
            self:Destroy()
            Char.controlling = true
        end
    end
    return spr
end

db._actions = {
    Spider = {
        use  = function(id) Overworld.dialogNew({"* You ate the Spider...", "* I CAN'T UNDERSTAND."}) end,
        info = function(id) Overworld.dialogNew("* A spider.") end,
        drop = function(id)
            drop_item(id)
            Overworld.dialogNew("* You dropped the Spider...\n* But nothing happened.")
        end,
    },
}

db._cell_actions = {
}

function db.FindItemByID(id)
    for _, v in ipairs(db)
    do
        if (type(v) == "table") then
            if (v.id == id) then
                return v
            end
        end
    end
end

--- Legacy accessor: db._actions[id][action].
---@param id string
---@param action string
---@return boolean
function db.GetActionByID(id, action)
    local entry = db._actions[id]
    return entry and entry[action]
end

--- Third-level menu router: action ∈ {"use", "info", "drop"}, default dialog.
---@param id string
---@param action string
function db.DoItemAction(id, action)
    if (not id) then return end
    local entry = db._actions[id]
    local fn = entry and entry[action]
    if (fn) then
        fn(id)
        return
    end
    local name = (db.FindItemByID(id) or {}).name or id
    if (action == "use") then
        Overworld.dialogNew("* You used the " .. name .. ".")
    elseif (action == "info") then
        Overworld.dialogNew("* " .. name .. ".")
    elseif (action == "drop") then
        drop_item(id)
        Overworld.dialogNew("* You dropped the " .. name .. ".")
    end
end

function db.DoCellAction(id)
    if (not id) then return end
    local fn = db._cell_actions[id]
    if (fn) then
        fn(id)
        return
    end
    local name = db.FindCellNameByID(id) or id
    Overworld.dialogNew("* You called " .. name .. ".\n* But nobody answered.")
end

--- Cell names live only in DATA.player.cells, not in the item table.
---@param id string
---@return string
function db.FindCellNameByID(id)
    for _, c in ipairs(DATA.player.cells) do
        if (c.id == id) then
            return c.name
        end
    end
    return id
end

return db
