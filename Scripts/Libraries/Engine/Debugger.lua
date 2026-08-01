local debugger = {
    interacting = false,
    current_object = nil,
    current_property = nil,
    show = false,

    drag_pending = false,
    dragging = false,
    press_x = 0,
    press_y = 0,
    drag_prev_x = 0,
    drag_prev_y = 0,
    drag_threshold = 5,

    context_menu = {
        show = false,
        x = 0,
        y = 0,
        width = 150,
        item_height = 30,
        object = nil,
    },

    -- Properties panel (right side of screen, 640x480 logical res)
    panel = {
        show = false,
        x = 435,
        y = 60,
        width = 200,
        padding = 5,
        line_height = 24,
        editing = false,      -- true while typing into a field
        edit_field = nil,     -- string key of the field being edited
        edit_buffer = "",     -- current text in the edit field
    },

    -- Four-point handle dragging
    handle_drag_index = 0,   -- 0=none, 1-4=corner being dragged
    handle_radius = 6,

    -- Color swatches for the quick-color picker
    swatches = {
        {1,1,1}, {0.9,0.9,0.9}, {0.7,0.7,0.7}, {0.5,0.5,0.5}, {0.3,0.3,0.3},
        {1,0.8,0.8}, {1,0.5,0.5}, {1,0,0}, {0.8,0.2,0}, {0.5,0,0},
        {1,0.9,0.6}, {1,0.8,0}, {1,0.5,0}, {0.8,0.4,0}, {0.5,0.2,0},
        {0.9,1,0.6}, {0.5,1,0}, {0,0.9,0}, {0,0.5,0}, {0,0.3,0},
        {0.6,0.9,1}, {0,1,1}, {0,0.6,1}, {0,0,1}, {0,0,0.5},
        {0.8,0.6,1}, {0.5,0,1}, {0.5,0,0.5}, {1,0,1}, {1,0,0.5},
    },
    swatches_per_row = 5,
    swatch_size = 18,
    swatch_gap = 2,
}

local main_font = SE.graphics.newFont("Resources/Fonts/determination_mono.ttf", 13, "mono")

-- ============================================================
-- CONTEXT MENU ITEMS (with new entries at the bottom)
-- ============================================================
local context_menu_items = {
    {
        label = "Clone",
        action = function(obj)
            Sprites.CreateSprite(obj.path, obj.layer)
            print("Clone object:", obj)
        end,
    },
    {
        label = "Export",
        action = function(obj)
            local f = io.open("Debug/exported_object.lua", "w")

            local str = ""
            str = str .. "-- Exported by Debugger\n"
            str = str .. "local spr = Sprites.CreateSprite(\"" .. obj.path .. "\", " .. obj.layer .. ")\n"
            str = str .. "spr:MoveTo(" .. obj.x .. ", " .. obj.y .. ")\n"
            str = str .. "spr:Scale(" .. obj.xscale .. ", " .. obj.yscale .. ")\n"
            str = str .. "spr.rotation = " .. obj.rotation .. "\n"
            str = str .. "spr.alpha = " .. (obj.alpha or 1) .. "\n"

            -- Color
            if (obj.color) then
                str = str .. "spr.color = {" .. (obj.color[1] or 1) .. ", " .. (obj.color[2] or 1) .. ", " .. (obj.color[3] or 1) .. "}\n"
            end

            -- Visibility
            if (obj.visible ~= nil) then
                str = str .. "spr.visible = " .. tostring(obj.visible) .. "\n"
            end

            -- Pixel smooth
            if (obj.pixel_smooth) then
                str = str .. "spr.pixel_smooth = true\n"
            end

            -- Four-point mesh deformation
            if (obj._four_point) then
                local fp = obj._four_point
                str = str .. "spr:SetFourPointMode(" .. tostring(fp.enabled) .. ")\n"
                if (fp.p1 and fp.p2 and fp.p3 and fp.p4) then
                    str = str .. "spr:SetFourPoint(\n"
                    str = str .. "    " .. fp.p1[1] .. ", " .. fp.p1[2] .. ",  -- top-left\n"
                    str = str .. "    " .. fp.p2[1] .. ", " .. fp.p2[2] .. ",  -- top-right\n"
                    str = str .. "    " .. fp.p3[1] .. ", " .. fp.p3[2] .. ",  -- bottom-left\n"
                    str = str .. "    " .. fp.p4[1] .. ", " .. fp.p4[2] .. "   -- bottom-right\n"
                    str = str .. ")\n"
                end
            end

            if (f) then
                f:write(str)
                f:close()
            end
            print("Export object:", obj)
            print("Saved to Debug/exported_object.lua")
        end,
    },
    {
        label = "Delete",
        action = function(obj)
            obj:Destroy()
            print("Delete object:", obj)
        end,
    },
    {
        label = "flip X",
        action = function(obj)
            obj.xscale = -obj.xscale
            print("flip X:", obj)
        end,
    },
    {
        label = "flip Y",
        action = function(obj)
            obj.yscale = -obj.yscale
            print("flip Y:", obj)
        end,
    },
    {
        label = "Rotate 90\u{00B0}",
        action = function(obj)
            obj.rotation = obj.rotation + 90
            print("Rotate 90\u{00B0}:", obj)
        end,
    },
    {
        label = "Rotate -90\u{00B0}",
        action = function(obj)
            obj.rotation = obj.rotation - 90
            print("Rotate -90\u{00B0}:", obj)
        end,
    },
    -- New debugger entries
    {
        label = "---",
        action = nil,
    },
    {
        label = "Properties",
        action = function(obj)
            debugger.current_object = obj
            debugger.panel.show = not debugger.panel.show
            debugger.panel.editing = false
            debugger.panel.edit_field = nil
            print("Toggle properties panel")
        end,
    },
    {
        label = "Toggle Four-Point",
        action = function(obj)
            if obj._four_point then
                obj._four_point.enabled = not obj._four_point.enabled
                print("Four-point mode:", obj._four_point.enabled)
            end
        end,
    },
    {
        label = "Reset Corners",
        action = function(obj)
            if obj._four_point then
                local w, h = obj.width or 64, obj.height or 64
                local cx, cy = obj.x or 320, obj.y or 240
                obj._four_point.p1 = {cx - w/2, cy - h/2}
                obj._four_point.p2 = {cx + w/2, cy - h/2}
                obj._four_point.p3 = {cx - w/2, cy + h/2}
                obj._four_point.p4 = {cx + w/2, cy + h/2}
                print("Reset four-point corners")
            end
        end,
    },
}

-- ============================================================
-- HELPERS
-- ============================================================
local function point_in_menu(px, py, menu)
    local menu_height = #context_menu_items * menu.item_height
    return px >= menu.x and px <= menu.x + menu.width and py >= menu.y and py <= menu.y + menu_height
end

local function point_in_rect(px, py, rx, ry, rw, rh)
    return px >= rx and px <= rx + rw and py >= ry and py <= ry + rh
end

local function dist(ax, ay, bx, by)
    local dx = bx - ax
    local dy = by - ay
    return math.sqrt(dx * dx + dy * dy)
end

local function clamp(val, min, max)
    return math.max(min, math.min(max, val))
end

-- Fields shown in the properties panel: {key, label, format_string}
local panel_fields = {
    {key = "x",       label = "X",       fmt = "%.2f"},
    {key = "y",       label = "Y",       fmt = "%.2f"},
    {key = "xscale",  label = "ScaleX",  fmt = "%.2f"},
    {key = "yscale",  label = "ScaleY",  fmt = "%.2f"},
    {key = "rotation",label = "Rot",     fmt = "%.1f"},
    {key = "alpha",   label = "Alpha",   fmt = "%.2f"},
}

-- ============================================================
-- UPDATE
-- ============================================================
function debugger.Update()
    -- Toggle debugger with Ctrl+D
    if (Keyboard.GetState("ctrl") > 1 and Keyboard.GetState("d") == 1) then
        debugger.interacting = not debugger.interacting
        if (not debugger.interacting) then
            debugger.panel.show = false
            debugger.panel.editing = false
            debugger.panel.edit_field = nil
            debugger.context_menu.show = false
            debugger.handle_drag_index = 0
        end
    end

    if (debugger.interacting) then
        local mouse_x, mouse_y = Keyboard.GetMousePosition()
        local mouse1_state = Keyboard.GetState("mouse1")
        local mouse2_state = Keyboard.GetState("mouse2")
        local menu = debugger.context_menu
        local panel = debugger.panel

        -- --------------------------------------------------------
        -- 1) Handle field editing (keyboard input)
        -- --------------------------------------------------------
        if (panel.editing and panel.edit_field) then
            local obj = debugger.current_object
            if (not obj) then
                panel.editing = false
                panel.edit_field = nil
            else
                -- Check for key-down events (state == 1)
                -- Digits 0-9
                for i = 0, 9 do
                    local ks = tostring(i)
                    if (Keyboard.GetState(ks) == 1) then
                        panel.edit_buffer = panel.edit_buffer .. ks
                    end
                end
                -- Keypad digits
                for i = 0, 9 do
                    local ks = "kp" .. tostring(i)
                    if (Keyboard.GetState(ks) == 1) then
                        panel.edit_buffer = panel.edit_buffer .. tostring(i)
                    end
                end
                -- Period (decimal point)
                if (Keyboard.GetState(".") == 1) then
                    -- Only add period if not already present
                    if not panel.edit_buffer:find("%.") then
                        panel.edit_buffer = panel.edit_buffer .. "."
                    end
                end
                -- Keypad period
                if (Keyboard.GetState("kp.") == 1) then
                    if not panel.edit_buffer:find("%.") then
                        panel.edit_buffer = panel.edit_buffer .. "."
                    end
                end
                -- Minus sign (toggle negative)
                if (Keyboard.GetState("-") == 1) then
                    if panel.edit_buffer:sub(1, 1) == "-" then
                        panel.edit_buffer = panel.edit_buffer:sub(2)
                    else
                        panel.edit_buffer = "-" .. panel.edit_buffer
                    end
                end
                -- Keypad minus
                if (Keyboard.GetState("kp-") == 1) then
                    if panel.edit_buffer:sub(1, 1) == "-" then
                        panel.edit_buffer = panel.edit_buffer:sub(2)
                    else
                        panel.edit_buffer = "-" .. panel.edit_buffer
                    end
                end
                -- Backspace
                if (Keyboard.GetState("backspace") == 1) then
                    if (#panel.edit_buffer > 0) then
                        panel.edit_buffer = panel.edit_buffer:sub(1, -2)
                    end
                end
                -- Return/Enter: apply the value
                if (Keyboard.GetState("return") == 1) then
                    local val = tonumber(panel.edit_buffer)
                    if (val ~= nil) then
                        obj[panel.edit_field] = val
                        print("Set", panel.edit_field, "=", val)
                    end
                    panel.editing = false
                    panel.edit_field = nil
                end
                -- Escape: cancel editing
                if (Keyboard.GetState("escape") == 1) then
                    panel.editing = false
                    panel.edit_field = nil
                end
                -- Don't process mouse input while editing
                return
            end
        end

        -- --------------------------------------------------------
        -- 2) Context menu handling
        -- --------------------------------------------------------
        if (menu.show) then
            if (mouse1_state == 1) then
                if (point_in_menu(mouse_x, mouse_y, menu)) then
                    local index = math.floor((mouse_y - menu.y) / menu.item_height) + 1
                    local item = context_menu_items[index]
                    if (item and item.action) then
                        item.action(menu.object)
                    end
                end
                menu.show = false
                menu.object = nil
            elseif (mouse2_state == 1) then
                menu.show = false
                menu.object = nil
            end
            return
        end

        -- --------------------------------------------------------
        -- 3) Properties panel click handling
        -- --------------------------------------------------------
        if (panel.show and debugger.current_object) then
            local obj = debugger.current_object
            local field_area_top = panel.y + 25  -- after title

            if (mouse1_state == 1) then
                -- Check if click is within panel bounds
                if (point_in_rect(mouse_x, mouse_y, panel.x, panel.y, panel.width, 480)) then
                    -- Check field clicks
                    for idx, finfo in ipairs(panel_fields) do
                        local fy = field_area_top + (idx - 1) * panel.line_height
                        if (point_in_rect(mouse_x, mouse_y, panel.x + panel.padding, fy, panel.width - panel.padding * 2, panel.line_height)) then
                            -- Start editing this field
                            panel.edit_field = finfo.key
                            panel.edit_buffer = tostring(obj[finfo.key] or 0)
                            panel.editing = true
                            return
                        end
                    end

                    -- Compute y-offsets for buttons and swatches
                    local btn_y = field_area_top + #panel_fields * panel.line_height + 5
                    local swatch_start_y = btn_y  -- will be adjusted below

                    -- Check "Four-Point" toggle button
                    if (obj._four_point and point_in_rect(mouse_x, mouse_y, panel.x + panel.padding, btn_y, panel.width - panel.padding * 2, panel.line_height)) then
                        obj._four_point.enabled = not obj._four_point.enabled
                        print("Four-point mode:", obj._four_point.enabled)
                        return
                    end

                    -- Check "Reset Corners" button
                    local reset_y = btn_y
                    if (obj._four_point) then
                        reset_y = btn_y + panel.line_height + 2
                        if (point_in_rect(mouse_x, mouse_y, panel.x + panel.padding, reset_y, panel.width - panel.padding * 2, panel.line_height)) then
                            if (obj._four_point) then
                                local w, h = obj.width or 64, obj.height or 64
                                local cx, cy = obj.x or 320, obj.y or 240
                                obj._four_point.p1 = {cx - w/2, cy - h/2}
                                obj._four_point.p2 = {cx + w/2, cy - h/2}
                                obj._four_point.p3 = {cx - w/2, cy + h/2}
                                obj._four_point.p4 = {cx + w/2, cy + h/2}
                                print("Reset four-point corners")
                            end
                            return
                        end
                        swatch_start_y = reset_y + panel.line_height + 5
                    end

                    -- Check color swatch clicks (available for any object with color)
                    if (obj.color) then
                        local num_swatches = #debugger.swatches
                        local rows = math.ceil(num_swatches / debugger.swatches_per_row)
                        local swatch_total = debugger.swatch_size + debugger.swatch_gap
                        -- Match Draw's layout: "Color:" label + 15px offset before the grid
                        local grid_y = swatch_start_y + 15

                        for si, color in ipairs(debugger.swatches) do
                            local col = (si - 1) % debugger.swatches_per_row
                            local row = math.floor((si - 1) / debugger.swatches_per_row)
                            local sx = panel.x + panel.padding + col * swatch_total
                            local sy = grid_y + row * swatch_total
                            if (point_in_rect(mouse_x, mouse_y, sx, sy, debugger.swatch_size, debugger.swatch_size)) then
                                obj.color = {color[1], color[2], color[3]}
                                print("Set color:", color[1], color[2], color[3])
                                return
                            end
                        end
                    end
                end
            end

            -- Handle click OUTSIDE panel to dismiss
            -- (We only care about mouse1_state == 1 here for toggling edit mode off when clicking outside)
            -- Actually we handle this implicitly - clicking outside does nothing to panel state
        end

        -- --------------------------------------------------------
        -- 4) Four-point handle drag detection
        -- --------------------------------------------------------
        local obj = debugger.current_object
        if (obj and obj._four_point and obj._four_point.enabled) then
            local fp = obj._four_point
            local points = {fp.p1, fp.p2, fp.p3, fp.p4}

            if (mouse1_state == 1) then
                -- Check if mouse is near a handle
                for i = 1, 4 do
                    if (points[i] and dist(mouse_x, mouse_y, points[i][1], points[i][2]) <= debugger.handle_radius + 4) then
                        debugger.handle_drag_index = i
                        debugger.drag_pending = false
                        debugger.dragging = false
                        return
                    end
                end
            end

            if (mouse1_state >= 1 and debugger.handle_drag_index > 0) then
                -- Update the corner position
                local idx = debugger.handle_drag_index
                obj:SetFourPointP(idx, mouse_x, mouse_y)
                return
            else
                debugger.handle_drag_index = 0
            end
        else
            debugger.handle_drag_index = 0
        end

        -- --------------------------------------------------------
        -- 5) Object selection (only when not dragging a handle)
        -- --------------------------------------------------------
        if (debugger.handle_drag_index == 0 and not debugger.drag_pending and not debugger.dragging) then
            debugger.current_object = nil
            debugger.current_property = nil

            for i, layer in ipairs(Layers.layers) do
                for j, object in ipairs(layer.objects) do
                    if (object.type == "object" and object.visible) then
                        local obj_x, obj_y = object.x, object.y
                        local obj_width, obj_height = math.abs(object.width * (object.xscale or 1)), math.abs(object.height * (object.yscale or 1))

                        if (mouse_x >= obj_x - obj_width * 0.5 and mouse_x <= obj_x + obj_width * 0.5 and mouse_y >= obj_y - obj_height * 0.5 and mouse_y <= obj_y + obj_height * 0.5) then
                            debugger.current_object = object
                            break
                        end
                    end
                end

                if (debugger.current_object) then break end
            end

            for i, object in ipairs(Layers.objects) do
                if (object.type == "object" and object.visible) then
                    local obj_x, obj_y = object.x, object.y
                    local obj_width, obj_height = math.abs(object.width * (object.xscale or 1)), math.abs(object.height * (object.yscale or 1))

                    if (mouse_x >= obj_x - obj_width * 0.5 and mouse_x <= obj_x + obj_width * 0.5 and mouse_y >= obj_y - obj_height * 0.5 and mouse_y <= obj_y + obj_height * 0.5) then
                        debugger.current_object = object
                        break
                    end
                end
            end
        end

        -- --------------------------------------------------------
        -- 6) Right-click context menu trigger
        -- --------------------------------------------------------
        if (mouse2_state == 1 and debugger.current_object) then
            menu.show = true
            menu.x = mouse_x
            menu.y = mouse_y
            menu.object = debugger.current_object
            debugger.drag_pending = false
            debugger.dragging = false
            debugger.handle_drag_index = 0
            return
        end

        -- --------------------------------------------------------
        -- 7) Object drag (only when not in four-point handle drag)
        -- --------------------------------------------------------
        if (debugger.handle_drag_index == 0) then
            if (mouse1_state == 1) then
                debugger.press_x, debugger.press_y = mouse_x, mouse_y
                debugger.drag_prev_x, debugger.drag_prev_y = mouse_x, mouse_y
                debugger.drag_pending = true
                debugger.dragging = false
            end

            if (mouse1_state >= 1) then
                if (debugger.drag_pending and not debugger.dragging and debugger.current_object) then
                    local dx = mouse_x - debugger.press_x
                    local dy = mouse_y - debugger.press_y
                    if (math.sqrt(dx * dx + dy * dy) > debugger.drag_threshold) then
                        debugger.dragging = true
                        -- Save current mouse position as reference for delta tracking
                        debugger.drag_prev_x, debugger.drag_prev_y = mouse_x, mouse_y
                    end
                end

                if (debugger.dragging and debugger.current_object) then
                    local cur = debugger.current_object
                    local dx = mouse_x - debugger.drag_prev_x
                    local dy = mouse_y - debugger.drag_prev_y

                    -- If four-point mode is on, move all 4 corners as a group
                    if (cur._four_point and cur._four_point.enabled) then
                        if (cur._four_point.p1) then
                            cur._four_point.p1[1] = cur._four_point.p1[1] + dx
                            cur._four_point.p1[2] = cur._four_point.p1[2] + dy
                            cur._four_point.p2[1] = cur._four_point.p2[1] + dx
                            cur._four_point.p2[2] = cur._four_point.p2[2] + dy
                            cur._four_point.p3[1] = cur._four_point.p3[1] + dx
                            cur._four_point.p3[2] = cur._four_point.p3[2] + dy
                            cur._four_point.p4[1] = cur._four_point.p4[1] + dx
                            cur._four_point.p4[2] = cur._four_point.p4[2] + dy
                        end
                    end
                    cur.x = cur.x + dx
                    cur.y = cur.y + dy

                    debugger.drag_prev_x, debugger.drag_prev_y = mouse_x, mouse_y
                end
            else
                debugger.drag_pending = false
                debugger.dragging = false
            end
        end
    end
end

-- ============================================================
-- DRAW
-- ============================================================
function debugger.Draw()
    if (debugger.interacting) then
        SE.graphics.setColor(1, 1, 1, 1)
        SE.graphics.setFont(main_font)
        SE.graphics.print("Click on an object to inspect it", 5, 5)
        SE.graphics.print("Current Object: " .. tostring(debugger.current_object), 5, 20)

        if (debugger.current_object) then
            local obj = debugger.current_object
            local info_x = 5
            local info_y = 35

            for key, value in pairs(obj) do
                if (type(value) ~= "function") then
                    SE.graphics.print(key .. ": " .. tostring(value), info_x, info_y)
                    info_y = info_y + 15
                    if (info_y > 30 * 15) then
                        info_x = info_x + 300
                        info_y = 45
                    end
                end
            end

            -- Draw selection box
            SE.graphics.setColor(1, 0, 0, 1)
            local obj_x, obj_y = obj.x, obj.y
            local obj_width, obj_height = obj.width * (obj.xscale or 1), obj.height * (obj.yscale or 1)
            SE.graphics.rectangle("line", obj_x - obj_width * 0.5, obj_y - obj_height * 0.5, obj_width, obj_height)

            -- ----------------------------------------------------
            -- Draw four-point handles (if four-point mode enabled)
            -- ----------------------------------------------------
            if (obj._four_point and obj._four_point.enabled) then
                local fp = obj._four_point
                local points = {fp.p1, fp.p2, fp.p3, fp.p4}
                local labels = {"TL", "TR", "BL", "BR"}
                local colors = {
                    {1, 0.3, 0.3},  -- TL: red
                    {0.3, 1, 0.3},  -- TR: green
                    {0.3, 0.3, 1},  -- BL: blue
                    {1, 1, 0.3},    -- BR: yellow
                }
                local hr = debugger.handle_radius

                for i = 1, 4 do
                    if (points[i]) then
                        local px, py = points[i][1], points[i][2]

                        -- Draw connecting lines
                        local next_i = (i % 4) + 1
                        if (points[next_i]) then
                            SE.graphics.setColor(0.5, 0.5, 1, 0.6)
                            SE.graphics.line(px, py, points[next_i][1], points[next_i][2])
                        end

                        -- Draw handle fill
                        local is_dragging = (debugger.handle_drag_index == i)
                        SE.graphics.setColor(colors[i][1], colors[i][2], colors[i][3], is_dragging and 1 or 0.8)
                        SE.graphics.circle("fill", px, py, hr)

                        -- Draw handle outline
                        SE.graphics.setColor(1, 1, 1, 1)
                        SE.graphics.setLineWidth(1.5)
                        SE.graphics.circle("line", px, py, hr)
                        SE.graphics.setLineWidth(1)

                        -- Draw label
                        SE.graphics.setColor(1, 1, 1, 1)
                        SE.graphics.print(labels[i], px + hr + 3, py - 5)
                    end
                end
            end

            -- ----------------------------------------------------
            -- Draw Properties Panel (right side)
            -- ----------------------------------------------------
            local panel = debugger.panel
            if (panel.show) then
                local px = panel.x
                local py = panel.y
                local pw = panel.width
                local pp = panel.padding
                local lh = panel.line_height

                -- Calculate dynamic panel height based on what the object supports
                local title_h = 25
                local field_h = #panel_fields * lh
                local extra_h = 0
                if (obj._four_point) then
                    extra_h = extra_h + lh * 2 + 4  -- two buttons + gap
                end
                if (obj.color) then
                    local num_swatches = #debugger.swatches
                    local rows = math.ceil(num_swatches / debugger.swatches_per_row)
                    local swatch_total = debugger.swatch_size + debugger.swatch_gap
                    extra_h = extra_h + rows * swatch_total + 5 + 15  -- "Color:" label + grid
                end
                local total_h = title_h + field_h + extra_h + pp * 4

                -- Background
                SE.graphics.setColor(0.1, 0.1, 0.15, 0.92)
                SE.graphics.rectangle("fill", px, py, pw, total_h)
                SE.graphics.setColor(0.4, 0.4, 0.6, 1)
                SE.graphics.rectangle("line", px, py, pw, total_h)

                -- Title
                SE.graphics.setColor(0.8, 0.8, 1, 1)
                SE.graphics.print("Properties", px + pp, py + pp)

                -- Separator
                local sep_y = py + title_h
                SE.graphics.setColor(0.3, 0.3, 0.4, 1)
                SE.graphics.line(px, sep_y, px + pw, sep_y)

                -- Field values
                local field_top = sep_y + 2
                for idx, finfo in ipairs(panel_fields) do
                    local fy = field_top + (idx - 1) * lh
                    local val = obj[finfo.key] or 0
                    local is_editing = (panel.editing and panel.edit_field == finfo.key)

                    -- Label
                    SE.graphics.setColor(0.7, 0.7, 0.9, 1)
                    SE.graphics.print(finfo.label .. ":", px + pp, fy + 3)

                    -- Value field background
                    local field_x = px + pp + 55
                    local field_w = pw - pp * 2 - 55
                    SE.graphics.setColor(0.2, 0.2, 0.25, 1)
                    SE.graphics.rectangle("fill", field_x, fy, field_w, lh - 2)

                    -- If editing, show buffer with cursor; otherwise show value
                    SE.graphics.setColor(1, 1, 1, 1)
                    if (is_editing) then
                        local display = panel.edit_buffer .. (math.floor(os.clock() * 2) % 2 == 0 and "|" or " ")
                        SE.graphics.print(display, field_x + 3, fy + 3)
                    else
                        local text = string.format(finfo.fmt, val)
                        SE.graphics.print(text, field_x + 3, fy + 3)
                    end

                    -- Highlight if this field is being edited
                    if (is_editing) then
                        SE.graphics.setColor(1, 1, 0.3, 0.3)
                        SE.graphics.rectangle("fill", field_x, fy, field_w, lh - 2)
                        SE.graphics.setColor(1, 1, 0.3, 0.8)
                        SE.graphics.rectangle("line", field_x, fy, field_w, lh - 2)
                    end
                end

                local btn_y = field_top + #panel_fields * lh + 5
                local swatch_start_y = btn_y  -- will be adjusted below

                -- Toggle Four-Point button (only for objects with _four_point)
                if (obj._four_point) then
                    local btn_text = obj._four_point.enabled and "[X] Four-Point" or "[  ] Four-Point"
                    SE.graphics.setColor(0.25, 0.25, 0.35, 1)
                    SE.graphics.rectangle("fill", px + pp, btn_y, pw - pp * 2, lh - 2)
                    SE.graphics.setColor(obj._four_point.enabled and 0.3 or 0.5, obj._four_point.enabled and 0.8 or 0.5, obj._four_point.enabled and 0.3 or 0.5, 1)
                    SE.graphics.rectangle("line", px + pp, btn_y, pw - pp * 2, lh - 2)
                    SE.graphics.setColor(1, 1, 1, 1)
                    SE.graphics.print(btn_text, px + pp + 4, btn_y + 3)
                    swatch_start_y = btn_y + lh + 5
                end

                -- Reset Corners button (only for objects with _four_point)
                if (obj._four_point) then
                    local reset_y = btn_y + lh + 2
                    SE.graphics.setColor(0.3, 0.25, 0.25, 1)
                    SE.graphics.rectangle("fill", px + pp, reset_y, pw - pp * 2, lh - 2)
                    SE.graphics.setColor(0.8, 0.5, 0.5, 1)
                    SE.graphics.rectangle("line", px + pp, reset_y, pw - pp * 2, lh - 2)
                    SE.graphics.setColor(1, 1, 1, 1)
                    SE.graphics.print("[Reset Corners]", px + pp + 4, reset_y + 3)
                    swatch_start_y = reset_y + lh + 5
                end

                -- Color swatches (available for any object with a color property)
                if (obj.color) then
                    local swatch_y = swatch_start_y
                    SE.graphics.setColor(0.7, 0.7, 0.9, 1)
                    SE.graphics.print("Color:", px + pp, swatch_y)
                    swatch_y = swatch_y + 15

                    local sw_total = debugger.swatch_size + debugger.swatch_gap
                    for si, color in ipairs(debugger.swatches) do
                        local col = (si - 1) % debugger.swatches_per_row
                        local row = math.floor((si - 1) / debugger.swatches_per_row)
                        local sx = px + pp + col * sw_total
                        local sy = swatch_y + row * sw_total

                        -- Draw swatch
                        SE.graphics.setColor(color[1], color[2], color[3], 1)
                        SE.graphics.rectangle("fill", sx, sy, debugger.swatch_size, debugger.swatch_size)

                        -- Border
                        SE.graphics.setColor(0.5, 0.5, 0.5, 1)
                        SE.graphics.rectangle("line", sx, sy, debugger.swatch_size, debugger.swatch_size)

                        -- Highlight if current color matches (approximate)
                        local cur = obj.color
                        if (cur and math.abs(cur[1] - color[1]) < 0.01 and math.abs(cur[2] - color[2]) < 0.01 and math.abs(cur[3] - color[3]) < 0.01) then
                            SE.graphics.setColor(1, 1, 0.3, 0.8)
                            SE.graphics.rectangle("line", sx - 1, sy - 1, debugger.swatch_size + 2, debugger.swatch_size + 2)
                        end
                    end
                end
            end
        end

        -- ----------------------------------------------------
        -- Draw context menu
        -- ----------------------------------------------------
        local menu = debugger.context_menu
        if (menu.show) then
            local menu_height = #context_menu_items * menu.item_height

            SE.graphics.setColor(0.1, 0.1, 0.1, 0.95)
            SE.graphics.rectangle("fill", menu.x, menu.y, menu.width, menu_height)

            SE.graphics.setColor(1, 1, 1, 1)
            SE.graphics.rectangle("line", menu.x, menu.y, menu.width, menu_height)

            for i, item in ipairs(context_menu_items) do
                local item_y = menu.y + (i - 1) * menu.item_height

                -- Separator line (draw as a thin line without text)
                if (item.label == "---") then
                    SE.graphics.setColor(0.4, 0.4, 0.4, 1)
                    SE.graphics.line(menu.x + 5, item_y + menu.item_height * 0.5, menu.x + menu.width - 5, item_y + menu.item_height * 0.5)
                else
                    SE.graphics.setColor(1, 1, 1, 1)
                    SE.graphics.print(item.label, menu.x + 5, item_y + 6)
                end

                if (i > 1 and item.label ~= "---") then
                    SE.graphics.setColor(0.4, 0.4, 0.4, 1)
                    SE.graphics.line(menu.x, item_y, menu.x + menu.width, item_y)
                end
            end
        end
    end
end

return debugger
