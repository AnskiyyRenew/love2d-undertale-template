local buttons = {
    button_selecting = 1,
    logic_buttons = {
        {1, 2, "right"},
        {2, 3, "right"},
        {3, 4, "right"},
        {4, 1, "right"},

        {2, 1, "left"},
        {3, 2, "left"},
        {4, 3, "left"},
        {1, 4, "left"},
    },
    buttons = {},
    sprites = {
        {
            "UI/Battle Screen/spr_fightbt_0.png",
            "UI/Battle Screen/spr_fightbt_1.png"
        },
        {
            "UI/Battle Screen/spr_actbt_center_0.png",
            "UI/Battle Screen/spr_actbt_center_1.png"
        },
        {
            "UI/Battle Screen/spr_itembt_0.png",
            "UI/Battle Screen/spr_itembt_1.png"
        },
        {
            "UI/Battle Screen/spr_sparebt_0.png",
            "UI/Battle Screen/spr_sparebt_1.png"
        }
    },
    rel_position = {
        {-39, -1},
        {-37, -1},
        {-39, -1},
        {-39, -1}
    },
    animations = {}
}

local fight = Sprites.CreateSprite(buttons.sprites[1][2], "UI")
fight:MoveTo(87, 453)
local act = Sprites.CreateSprite(buttons.sprites[2][1], "UI")
act:MoveTo(240, 453)
local item = Sprites.CreateSprite(buttons.sprites[3][1], "UI")
item:MoveTo(400, 453)
local mercy = Sprites.CreateSprite(buttons.sprites[4][1], "UI")
mercy:MoveTo(555, 453)
table.insert(buttons.buttons, fight)
table.insert(buttons.buttons, act)
table.insert(buttons.buttons, item)
table.insert(buttons.buttons, mercy)

local last_applied_index = nil

local function applyButtonVisualState(selected_index)
    local button_list = buttons.buttons
    local sprite_list = buttons.sprites
    local animation_table = buttons.animations

    for i = 1, #button_list do
        local button = button_list[i]
        local sprite_data = sprite_list[i]
        local is_selected = (i == selected_index)

        if is_selected then
            local selected_anim = animation_table.selecting and animation_table.selecting[i]
            if selected_anim then
                button:SetAnimation(selected_anim[1], selected_anim[2])
            else
                local selected_sprite = sprite_data and sprite_data[2] or sprite_data and sprite_data[1]
                if selected_sprite then
                    button:Set(selected_sprite)
                end
            end
        else
            local idle_anim = animation_table.idle and animation_table.idle[i]
            if idle_anim then
                button:SetAnimation(idle_anim[1], idle_anim[2])
            else
                local idle_sprite = sprite_data and sprite_data[1]
                if idle_sprite then
                    button:Set(idle_sprite)
                end
            end
        end
    end
end

function buttons.GetButtons()
    return buttons.buttons
end

function buttons.ResetButtons()
    last_applied_index = nil

    local button_list = buttons.buttons
    local sprite_list = buttons.sprites
    local animation_table = buttons.animations

    for i = 1, #button_list do
        local button = button_list[i]
        local sprite_data = sprite_list[i]

        local idle_anim = animation_table.idle and animation_table.idle[i]
        if idle_anim then
            button:SetAnimation(idle_anim[1], idle_anim[2])
        else
            local idle_sprite = sprite_data and sprite_data[1]
            if idle_sprite then
                button:Set(idle_sprite)
            end
        end
    end
end

function buttons.ResetAllState()
    buttons.button_selecting = 1
    buttons.ResetButtons()
end

function buttons.RemoveButton(id)
    -- Phase 1: Rebuild logic_buttons — redirect rules that point to the deleted button,
    --          and remove rules that start from the deleted button
    local new_logic = {}
    for i = 1, #buttons.logic_buttons do
        local rule = buttons.logic_buttons[i]
        local source, target, trigger = rule[1], rule[2], rule[3]

        if source == id then
            -- Rule starts from the deleted button → remove it entirely
        elseif target == id then
            -- Rule points to the deleted button → redirect to skip it
            local new_target
            if type(trigger) == "string" and (trigger == "left" or trigger == "prev") then
                new_target = id - 1     -- "left"/reverse direction → go to previous index
            else
                new_target = id + 1     -- "right"/forward direction → go to next index
            end
            table.insert(new_logic, {source, new_target, trigger})
        else
            -- Rule is unrelated to the deleted button, keep as-is
            table.insert(new_logic, rule)
        end
    end

    -- Phase 2: Decrement all source/target values that reference buttons after the deleted one
    for i = 1, #new_logic do
        local rule = new_logic[i]
        if rule[1] > id then
            rule[1] = rule[1] - 1
        end
        if rule[2] > id then
            rule[2] = rule[2] - 1
        end
    end

    -- Phase 2b: Remove any rules referencing out-of-bounds indices
    -- (can happen when all remaining buttons are removed one by one)
    local new_count = #buttons.buttons - 1
    for i = #new_logic, 1, -1 do
        local rule = new_logic[i]
        if rule[1] < 1 or rule[1] > new_count or rule[2] < 1 or rule[2] > new_count then
            table.remove(new_logic, i)
        end
    end

    buttons.logic_buttons = new_logic

    -- Phase 3: Remove button data from all indexed tables
    table.remove(buttons.buttons, id)
    table.remove(buttons.sprites, id)
    table.remove(buttons.rel_position, id)

    if buttons.animations.idle then
        table.remove(buttons.animations.idle, id)
    end
    if buttons.animations.selecting then
        table.remove(buttons.animations.selecting, id)
    end

    -- Clamp button_selecting if the currently selected button was removed
    if buttons.button_selecting > #buttons.buttons then
        buttons.button_selecting = #buttons.buttons
    elseif buttons.button_selecting == id then
        buttons.button_selecting = math.min(id, #buttons.buttons)
    end
end

function buttons.SetLogic(logic)
    buttons.logic_buttons = (logic or {
        {1, 2, "right"},
        {2, 3, "right"},
        {3, 4, "right"},
        {4, 1, "right"},

        {2, 1, "left"},
        {3, 2, "left"},
        {4, 3, "left"},
        {1, 4, "left"},
    })
end

function buttons.SetSprites(sprs)
    for i, tab in ipairs(sprs)
    do
        if (#tab ~= 2) then
            print("[UI WARNING] Invalid sprite table.")
            return
        end
    end

    buttons.sprites = sprs
end

function buttons.SetAnimations(anims)
    buttons.animations = (anims or {
        idle = {
            {{
                "poseur.png",
                "bullet.png"
            }, 0.1}
        },
        selecting = {
            {{
                "heart.png",
                "Overworld/spr_exc.png"
            }, 0.1}
        }
    })
end

function buttons.Update()
    if (Battle.state ~= "ACTIONSELECT") then return end

    local button_list = buttons.buttons
    local sprite_list = buttons.sprites
    local animation_table = buttons.animations
    local rel_position_list = buttons.rel_position
    local logic_list = buttons.logic_buttons

    local current = buttons.button_selecting
    for i = 1, #logic_list do
        local rule = logic_list[i]
        local current_value, target_value, trigger = rule[1], rule[2], rule[3]
        local should_trigger = false

        if (type(trigger) == "function") then
            should_trigger = trigger()
        elseif (type(trigger) == "string") then
            should_trigger = (Keyboard.GetState(trigger) == 1)
        end

        if (current_value == current and should_trigger) then
            Audio.PlaySound("snd_menu_0.wav")
            buttons.button_selecting = target_value
            break
        end
    end

    local selected_index = buttons.button_selecting

    if (last_applied_index ~= selected_index) then
        applyButtonVisualState(selected_index)
        last_applied_index = selected_index
    end

    local selected_button = button_list[selected_index]

    local pos = rel_position_list[selected_index]
    if (selected_button and pos) then
        Player.sprite:MoveTo(
            selected_button.x + pos[1] * math.cos(math.rad(selected_button.rotation)),
            selected_button.y + pos[2] * math.sin(math.rad(selected_button.rotation))
        )
    end
end

return buttons
