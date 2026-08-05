local skip_attack_updater = false
local skip_mercy_updater = false

local state = {
    _state = "ACTIONSELECT",

    block_transition = false,

    logic_list = {
        -- confirm/cancel rules (original)
        {"confirm", "ACTIONSELECT", "FIGHTMENU", 1},
        {"confirm", "ACTIONSELECT", "ACTMENU", 2},
        {"confirm", "ACTIONSELECT", "ITEMMENU", 3},
        {"confirm", "ACTIONSELECT", "MERCYMENU", 4},

        {"confirm", "ACTIONMENU", "DIALOGUERESULT"},
        {"confirm", "ITEMMENU", "DIALOGUERESULT"},

        {"cancel", "FIGHTMENU", "ACTIONSELECT"},
        {"cancel", "ACTMENU", "ACTIONSELECT"},
        {"cancel", "ITEMMENU", "ACTIONSELECT"},
        {"cancel", "MERCYMENU", "ACTIONSELECT"},
        {"cancel", "ACTIONMENU", "ACTMENU"},

        {"confirm", "FIGHTMENU", "ATTACKING"},
        {"confirm", "ACTMENU", "ACTIONMENU"},
    },

    typers = {},
    sprites = {}
}

local choosing_enemy = 1
local choosing_action = 1
local choosing = 1
local dialog_result_texts = {}

local function destroy_elements()
    for i = #state.typers, 1, -1 do
        state.typers[i]:Destroy()
    end
    state.typers = {}

    for i = #state.sprites, 1, -1 do
        state.sprites[i]:Destroy()
    end
    state.sprites = {}
end

local function state_behaviours_drawer()
    destroy_elements()
    Battle.narration_text:SetText("")
    Player.sprite:MoveTo(99999, 99999)
    local s = Battle.state
    local game = (Battle.game)

    if (not game or not game.enemies) then
        return
    end
    choosing = 1

    local enemies = game.enemies
    if (s == "ACTIONSELECT") then
        choosing_enemy = 1
        Battle.narration_text:SetText(game.narration)
    elseif (s == "FIGHTMENU") then
        for i = 1, #enemies
        do
            local e = enemies[i]
            local t = Typers.InstText.New("* " .. e.name, {90, 270 + 33 * (i - 1)}, "UponArena")
            if (e._color) then
                t.color = e._color
            end
            if (e.canspare) then
                t.color = {1, 1, 0}
            end
            table.insert(state.typers, t)

            if (e.show_hpbar) then
                local maxhp = Sprites.CreateSprite("px.png", "UponArena")
                maxhp:Scale(100, 15)
                maxhp.xpivot = 0
                maxhp.color = {1, 0, 0}
                maxhp:MoveTo(400, 270 + 33 * (i - 1) + 18)

                local hp = Sprites.CreateSprite("px.png", "UponArena")
                hp:Scale(e.hp / e.maxhp * 100, 15)
                hp.xpivot = 0
                hp.color = {0, 1, 0}
                hp:MoveTo(maxhp:GetPosition())

                table.insert(state.sprites, maxhp)
                table.insert(state.sprites, hp)
            end
        end
    elseif (s == "ATTACKING") then
        UI.buttons.ResetButtons()
        Battle.attack.Restart(enemies[choosing_enemy])
    elseif (s == "ACTMENU") then
        choosing_action = 1
        for i = 1, #enemies
        do
            local e = enemies[i]
            local t = Typers.InstText.New("* " .. e.name, {90, 270 + 33 * (i - 1)}, "UponArena")
            if (e._color) then
                t.color = e._color
            end
            if (e.canspare) then
                t.color = {1, 1, 0}
            end
            table.insert(state.typers, t)
        end
    elseif (s == "ACTIONMENU") then
        local e = enemies[choosing_enemy]

        local x, y = 90, 270
        for i = 1, #e.actions
        do
            if (i % 2 == 0) then
                x = 340
            else
                x = 90
            end
            local t = Typers.InstText.New("* " .. e.actions[i].name, {x, y}, "UponArena")
            table.insert(state.typers, t)

            if (i % 2 == 0) then
                y = y + 33
            end
        end
    elseif (s == "ITEMMENU") then
        local x, y = 90, 270
        for i = 1, #game.items
        do
            local item_ = game.items[i]
            if (i % 2 == 0) then
                x = 340
            else
                x = 90
            end
            local t = Typers.InstText.New("* " .. item_.name, {x, y}, "UponArena")
            if (item_._color) then
                t.color = item_._color
            end
            table.insert(state.typers, t)

            if (i % 2 == 0) then
                y = y + 33
            end
        end
    elseif (s == "MERCYMENU") then
        local canflee = game.can_flee

        local t = Typers.InstText.New("* " .. Localize.localizeText("Battle.Spare"), {90, 270}, "UponArena")
        for _, e in ipairs(enemies)
        do
            if (e.canspare) then
                t.color = {1, 1, 0}
                break
            end
        end
        table.insert(state.typers, t)

        if (canflee) then
            local t = Typers.InstText.New("* " .. Localize.localizeText("Battle.Flee"), {90, 305}, "UponArena")
            table.insert(state.typers, t)
        end
    elseif (s == "TRYINGFLEE") then
        Battle.HandleFlee()
    elseif (s == "DIALOGUERESULT") then
        choosing_enemy = 1
        choosing_action = 1
        UI.buttons.ResetButtons()
        local texts = Battle.dialog_texts or dialog_result_texts
        Battle.dialog_texts = nil
        local t = Typers.EText.New(texts, {60, 270}, "UponArena", {0, 0}, "manual")
        t._onComplete = function ()
            Battle.ChangeState("ACTIONSELECT")
            Battle.narration_text:SetText(game.narration)
            state.block_transition = true
        end
    end
end

local function state_behaviours_updater(dt)
    local s = Battle.state
    local game = Battle.game

    if (not game or not game.enemies) then
        return
    end
    local enemies = game.enemies

    if (s == "FIGHTMENU" or s == "ACTMENU") then
        if (Keyboard.GetState("down") == 1) then
            choosing_enemy = math.min(choosing_enemy + 1, #enemies)
            Audio.PlaySound("snd_menu_0.wav")
        elseif (Keyboard.GetState("up") == 1) then
            choosing_enemy = math.max(choosing_enemy - 1, 1)
            Audio.PlaySound("snd_menu_0.wav")
        end

        Player.sprite:MoveTo(70, state.typers[choosing_enemy].y + 18)
    elseif (s == "ATTACKING") then
        if (not skip_attack_updater) then
            Battle.attack.Update(dt)

            if (Battle.attack._end) then
                for i = #enemies, 1, -1
                do
                    local e = enemies[i]

                    if (e.killable) then
                        if (e.hp <= 0) then
                            local anim = e.animation
                            if (anim and anim.Destroy) then
                                anim:Destroy()
                            end
                            Battle.EXP = Battle.EXP + e.exp
                            Battle.GOLD = Battle.GOLD + e.gold
                            table.remove(enemies, i)
                        end
                    end
                end
                if (#enemies > 0) then
                    Battle.ChangeState("DEFENDING")
                else
                    Battle.Win()
                    Battle.state = "WIN"
                end
            end
        end
        skip_attack_updater = false
    elseif (s == "DEFENDING") then
        if (Battle._wave) then
            Battle._wave.Update(dt)

            if (Battle._wave._end) then
                choosing = 1
                choosing_action = 1
                choosing_enemy = 1
                Battle.ChangeState("ACTIONSELECT")
            end
        end
    elseif (s == "ACTIONMENU") then
        local actions = enemies[choosing_enemy].actions

        if (Keyboard.GetState("right") == 1) then
            if (actions[choosing_action + 1]) then
                choosing_action = math.min(#actions, choosing_action + 1)
                Audio.PlaySound("snd_menu_0.wav")
            end
        elseif (Keyboard.GetState("left") == 1) then
            if (actions[choosing_action - 1]) then
                choosing_action = math.max(1, choosing_action - 1)
                Audio.PlaySound("snd_menu_0.wav")
            end
        elseif (Keyboard.GetState("up") == 1) then
            if (actions[choosing_action - 2]) then
                choosing_action = math.max(1, choosing_action - 2)
                Audio.PlaySound("snd_menu_0.wav")
            end
        elseif (Keyboard.GetState("down") == 1) then
            if (actions[choosing_action + 2]) then
                choosing_action = math.min(#actions, choosing_action + 2)
                Audio.PlaySound("snd_menu_0.wav")
            end
        end

        Player.sprite:MoveTo(
            state.typers[choosing_action].x - 20,
            state.typers[choosing_action].y + 18
        )
    elseif (s == "ITEMMENU") then
        local items = game.items

        if (Keyboard.GetState("right") == 1) then
            if (items[choosing + 1]) then
                choosing = math.min(#items, choosing + 1)
                Audio.PlaySound("snd_menu_0.wav")
            end
        elseif (Keyboard.GetState("left") == 1) then
            if (items[choosing - 1]) then
                choosing = math.max(1, choosing - 1)
                Audio.PlaySound("snd_menu_0.wav")
            end
        elseif (Keyboard.GetState("up") == 1) then
            if (items[choosing - 2]) then
                choosing = math.max(1, choosing - 2)
                Audio.PlaySound("snd_menu_0.wav")
            elseif (items[choosing - 1]) then
                choosing = math.max(1, choosing - 1)
                Audio.PlaySound("snd_menu_0.wav")
            end
        elseif (Keyboard.GetState("down") == 1) then
            if (items[choosing + 2]) then
                choosing = math.min(#items, choosing + 2)
                Audio.PlaySound("snd_menu_0.wav")
            elseif (items[choosing + 1]) then
                choosing = math.min(#items, choosing + 1)
                Audio.PlaySound("snd_menu_0.wav")
            end
        end

        Player.sprite:MoveTo(
            state.typers[choosing].x - 20,
            state.typers[choosing].y + 18
        )
    elseif (s == "MERCYMENU") then
        if (Keyboard.GetState("down") == 1) then
            choosing = math.min(choosing + 1, #state.typers)
            Audio.PlaySound("snd_menu_0.wav")
        elseif (Keyboard.GetState("up") == 1) then
            choosing = math.max(choosing - 1, 1)
            Audio.PlaySound("snd_menu_0.wav")
        end

        Player.sprite:MoveTo(
            state.typers[choosing].x - 20,
            state.typers[choosing].y + 18
        )

        if (not skip_mercy_updater and Keyboard.GetState("confirm") == 1) then
            destroy_elements()
            if (choosing == 1) then
                for i = #enemies, 1, -1
                do
                    local e = enemies[i]

                    if (e.killable and e.canspare) then
                        local anim = e.animation
                        if (anim and anim.Spare) then
                            anim:Spare()
                        end
                        Battle.GOLD = Battle.GOLD + e.gold
                        table.remove(enemies, i)
                    end
                end

                if (#enemies > 0) then
                    Battle.ChangeState("DEFENDING")
                else
                    Battle.Win()
                end
            elseif (choosing == 2) then
                if (math.random() <= Battle.game.flee_percent) then
                    Battle.HandleFlee()
                    Battle.ChangeState("FLEEING")
                else
                    Battle.ChangeState("DEFENDING")
                end
            end
        end
        skip_mercy_updater = false
    elseif (s == "FLEEING") then
        Battle.FleeUpdate(dt)
    end
end

local function get_items_table()
    if (not Battle.game or not Battle.game.items) then
        return {}
    end
    return Battle.game.items
end

function state.Update(dt)
    local current_state = Battle.state
    local current_button = UI.button_selecting

    -- While the arena is restoring after a wave ends, defer the narration
    -- text until the arena reaches full size, and block menu transitions
    -- so confirm/cancel can't open a menu mid-animation.
    if (Battle.restoring_arena) then
        Battle.UpdateRestore(dt)
    elseif state.block_transition then
        state.block_transition = false
    else
        for i = 1, #state.logic_list do
            local rule = state.logic_list[i]
            local key_action = rule[1]
            local source_state = rule[2]
            local target_state = rule[3]
            local inbutton = rule[4]  -- nil if not provided

            -- Check if key is pressed
            local key_pressed = (Keyboard.GetState(key_action) == 1)

            -- Check if current state matches source state
            local state_matches = (current_state == source_state)

            -- Check inbutton condition (if specified)
            local inbutton_matches = true
            if (inbutton ~= nil) then
                inbutton_matches = (current_button == inbutton)
            end

            if (key_pressed and state_matches and inbutton_matches) then
                local items = get_items_table()

                -- Block ITEMMENU transition if there are no items in the inventory
                if (target_state == "ITEMMENU" and #items == 0) then
                    Audio.PlaySound("snd_phurt.wav")
                    break
                end

                Battle.selected_enemy_index = choosing_enemy
                Battle.selected_action_index = choosing_action
                Battle.selected_index = choosing
                Battle.ChangeState(target_state)

                -- When entering ATTACKING, skip the first updater frame
                -- so the confirm press that triggered the transition
                -- doesn't immediately fire the attack
                if (target_state == "ATTACKING") then
                    skip_attack_updater = true
                end

                -- Same for MERCYMENU: skip the first updater frame so the
                -- confirm press that opened the menu doesn't immediately
                -- trigger the spare action
                if (target_state == "MERCYMENU") then
                    skip_mercy_updater = true
                end

                state_behaviours_drawer()

                if (key_action == "confirm") then
                    Audio.PlaySound("snd_menu_1.wav")
                end
                break
            end
        end
    end

    state_behaviours_updater(dt)
end

return state
