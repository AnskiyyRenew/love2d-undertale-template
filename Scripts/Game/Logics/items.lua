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

db._actions = {
    {
        id = "Spider",
        use = {"* You ate the Spider...", "* I CAN'T UNDERSTAND."},
        info = {"* A spider."},
        drop = {"* You dropped the Spider...\n* But nothing happened."}
    }
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

function db.GetActionByID(id, action)
    for _, v in ipairs(db._actions)
    do
        if (type(v) == "table") then
            if (v.id == id) then
                return v[action]
            end
        end
    end
end

return db