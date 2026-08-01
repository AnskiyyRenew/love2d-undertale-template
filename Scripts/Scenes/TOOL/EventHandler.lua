local scene = {}

-- ============================================
-- 1. STATE
-- ============================================
local main_font
local main_music
local bpm = 180
local beat_current = 0
local beat_total = 0

local player = {
    playing = false,
    current_time = 0,
    total_time = 0,
}

local top_buttons = {}
local grid_events = {}

local bpm_input_active = false
local bpm_input_text = ""
local bpm_input_x, bpm_input_y, bpm_input_w, bpm_input_h = 20, 150, 100, 20

local offset = 0
local offset_input_active = false
local offset_input_text = ""
local offset_input_x, offset_input_y, offset_input_w, offset_input_h = 20, 220, 100, 20

local grid_panel = {
    margin = 20,
    top = 20,
    width = 300,
    padding = 4,
    header_h = 22,
    cols = 4,
    cell_gap = 2,
    row_gap = 2,
    total_rows = 128,
    scroll = 0,
    max_scroll = 0,
    scan_line_ratio = 0.72,
}

local edit_panel = {
    margin = 20,
    bottom = 20,
    width = 300,
    padding = 6,
    title_h = 18,
    info_h = 34,
    button_h = 20,
    button_gap = 4,
    cols = 2,
}

local selected_cell = nil
local placement_tool = {
    kind = "auto",
    name = nil,
}

local next_auto_event_id = 1
local playback_last_step = -1
local playback_adjusted_time = 0
local playback_sixteenth_duration = (60 / bpm) / 4

local fixed_event_names = {
    "Event1",
    "Event2",
    "Event3",
    "Event4",
    "Event5",
}

-- ============================================
-- 2. HELPERS
-- ============================================
local function new_top_button(text, x, y, w, h, func)
    top_buttons[#top_buttons + 1] = {
        t = text,
        x = x,
        y = y,
        w = w,
        h = h,
        func = func,
        color = {0.3, 0.3, 0.3},
    }
end

local function get_grid_rect()
    local win_w, win_h = love.graphics.getDimensions()
    local panel_w = math.min(grid_panel.width, math.max(240, math.floor(win_w * 0.35)))
    local panel_h = math.max(120, win_h - grid_panel.top * 2)
    local panel_x = win_w - grid_panel.margin - panel_w
    local panel_y = grid_panel.top
    return panel_x, panel_y, panel_w, panel_h
end

local function get_grid_layout()
    local panel_x, panel_y, panel_w, panel_h = get_grid_rect()
    local inner_x = panel_x + grid_panel.padding
    local inner_y = panel_y + grid_panel.padding
    local inner_w = panel_w - grid_panel.padding * 2
    local inner_h = panel_h - grid_panel.padding * 2
    local cell_w = math.floor((inner_w - (grid_panel.cols - 1) * grid_panel.cell_gap) / grid_panel.cols)
    cell_w = math.max(24, cell_w)
    local row_stride = cell_w + grid_panel.row_gap
    local grid_top = inner_y + grid_panel.header_h
    local grid_h = inner_h - grid_panel.header_h
    local scan_line_y = grid_top + math.floor(grid_h * grid_panel.scan_line_ratio)

    return {
        panel_x = panel_x,
        panel_y = panel_y,
        panel_w = panel_w,
        panel_h = panel_h,
        inner_x = inner_x,
        inner_y = inner_y,
        inner_w = inner_w,
        inner_h = inner_h,
        cell_w = cell_w,
        row_stride = row_stride,
        grid_top = grid_top,
        grid_h = grid_h,
        scan_line_y = scan_line_y,
    }
end

local function get_edit_panel_rect()
    local win_w, win_h = love.graphics.getDimensions()
    local panel_w = edit_panel.width
    local panel_h = 180
    local panel_x = edit_panel.margin
    local panel_y = win_h - edit_panel.bottom - panel_h
    return panel_x, panel_y, panel_w, panel_h
end

local function get_edit_panel_layout()
    local panel_x, panel_y, panel_w, panel_h = get_edit_panel_rect()
    local inner_x = panel_x + edit_panel.padding
    local inner_y = panel_y + edit_panel.padding
    local inner_w = panel_w - edit_panel.padding * 2
    local button_w = math.floor((inner_w - edit_panel.button_gap) / 2)
    local full_w = inner_w
    local button_h = edit_panel.button_h
    local start_y = inner_y + edit_panel.title_h + edit_panel.info_h

    local buttons = {
        { id = "delete", label = "Delete", x = inner_x, y = start_y, w = full_w, h = button_h },
        { id = "auto", label = "Auto", x = inner_x, y = start_y + (button_h + edit_panel.button_gap) * 1, w = button_w, h = button_h },
        { id = "event1", label = "Event1", x = inner_x + button_w + edit_panel.button_gap, y = start_y + (button_h + edit_panel.button_gap) * 1, w = button_w, h = button_h },
        { id = "event2", label = "Event2", x = inner_x, y = start_y + (button_h + edit_panel.button_gap) * 2, w = button_w, h = button_h },
        { id = "event3", label = "Event3", x = inner_x + button_w + edit_panel.button_gap, y = start_y + (button_h + edit_panel.button_gap) * 2, w = button_w, h = button_h },
        { id = "event4", label = "Event4", x = inner_x, y = start_y + (button_h + edit_panel.button_gap) * 3, w = button_w, h = button_h },
        { id = "event5", label = "Event5", x = inner_x + button_w + edit_panel.button_gap, y = start_y + (button_h + edit_panel.button_gap) * 3, w = button_w, h = button_h },
    }

    return {
        panel_x = panel_x,
        panel_y = panel_y,
        panel_w = panel_w,
        panel_h = panel_h,
        inner_x = inner_x,
        inner_y = inner_y,
        inner_w = inner_w,
        buttons = buttons,
    }
end

local function clamp_grid_scroll()
    local _, _, panel_w, panel_h = get_grid_rect()
    local inner_w = panel_w - grid_panel.padding * 2
    local cell_w = math.floor((inner_w - (grid_panel.cols - 1) * grid_panel.cell_gap) / grid_panel.cols)
    cell_w = math.max(24, cell_w)
    local row_stride = cell_w + grid_panel.row_gap
    local visible_h = panel_h - grid_panel.padding * 2 - grid_panel.header_h
    local total_h = grid_panel.total_rows * row_stride - grid_panel.row_gap
    grid_panel.max_scroll = math.max(0, total_h - visible_h)

    if grid_panel.scroll < 0 then
        grid_panel.scroll = 0
    elseif grid_panel.scroll > grid_panel.max_scroll then
        grid_panel.scroll = grid_panel.max_scroll
    end
end

local function ensure_grid_row(row)
    grid_events[row] = grid_events[row] or {}
    return grid_events[row]
end

local function grid_has_event(row, col)
    return grid_events[row] and grid_events[row][col] ~= nil
end

local function grid_event_count()
    local count = 0
    for row = 1, grid_panel.total_rows do
        local row_data = grid_events[row]
        if row_data then
            for col = 1, grid_panel.cols do
                if row_data[col] then
                    count = count + 1
                end
            end
        end
    end
    return count
end

local function hash_color(name)
    local r, g, b = 0, 0, 0
    local text = tostring(name or "")
    for i = 1, #text do
        local c = text:byte(i)
        r = (r + c * 3) % 255
        g = (g + c * 5) % 255
        b = (b + c * 7) % 255
    end
    return (100 + r) / 255, (100 + g) / 255, (100 + b) / 255
end

local function make_auto_event_name()
    local name = "EventU" .. tostring(next_auto_event_id)
    next_auto_event_id = next_auto_event_id + 1
    return name
end

local function create_event_item(name, kind, row, col)
    return {
        event_name = name,
        kind = kind,
        row = row,
        col = col,
    }
end

local function place_grid_event(row, col, item)
    if row < 1 or row > grid_panel.total_rows then
        return false
    end
    if col < 1 or col > grid_panel.cols then
        return false
    end

    local row_data = ensure_grid_row(row)
    if row_data[col] then
        return false
    end

    row_data[col] = item or create_event_item(make_auto_event_name(), "auto", row, col)
    row_data[col].row = row
    row_data[col].col = col
    return true
end

local function remove_grid_event(row, col)
    if grid_events[row] then
        grid_events[row][col] = nil
    end
end

local function find_first_empty_cell()
    for row = 1, grid_panel.total_rows do
        for col = 1, grid_panel.cols do
            if not grid_has_event(row, col) then
                return row, col
            end
        end
    end
    return nil, nil
end

local function get_effective_grid_scroll(row_stride)
    local playback_scroll = 0
    if player.playing and playback_sixteenth_duration > 0 then
        playback_scroll = (playback_adjusted_time / playback_sixteenth_duration) * row_stride
    end
    return grid_panel.scroll + playback_scroll
end

local function get_hovered_grid_cell(x, y)
    local layout = get_grid_layout()
    if x < layout.inner_x or x > layout.inner_x + layout.inner_w then
        return nil, nil
    end
    if y < layout.grid_top or y > layout.grid_top + layout.grid_h then
        return nil, nil
    end

    local effective_scroll = get_effective_grid_scroll(layout.row_stride)
    local local_y = y - layout.scan_line_y + effective_scroll
    local row = math.floor(local_y / layout.row_stride) + 1
    if row < 1 or row > grid_panel.total_rows then
        return nil, nil
    end

    local local_x = x - layout.inner_x
    local col = math.floor(local_x / (layout.cell_w + grid_panel.cell_gap)) + 1
    if col < 1 or col > grid_panel.cols then
        return nil, nil
    end

    local cell_x = layout.inner_x + (col - 1) * (layout.cell_w + grid_panel.cell_gap)
    local cell_y = layout.scan_line_y + (row - 1) * layout.row_stride - effective_scroll
    if x < cell_x or x > cell_x + layout.cell_w or y < cell_y or y > cell_y + layout.cell_w then
        return nil, nil
    end

    return row, col
end

local function get_tool_label()
    if placement_tool.kind == "auto" then
        return "Auto"
    elseif placement_tool.kind == "fixed" then
        return placement_tool.name or "Fixed"
    elseif placement_tool.kind == "delete" then
        return "Delete"
    end
    return "Auto"
end

local function set_tool_auto()
    placement_tool.kind = "auto"
    placement_tool.name = nil
end

local function set_tool_fixed(name)
    placement_tool.kind = "fixed"
    placement_tool.name = name
end

local function set_tool_delete()
    placement_tool.kind = "delete"
    placement_tool.name = nil
end

local function selected_event_item()
    if not selected_cell then
        return nil
    end
    return grid_events[selected_cell.row] and grid_events[selected_cell.row][selected_cell.col] or nil
end

local function select_cell(row, col)
    if row and col and grid_has_event(row, col) then
        selected_cell = { row = row, col = col }
    else
        selected_cell = nil
    end
end

local function rename_selected_or_current_mode(name, kind)
    if selected_cell then
        local item = selected_event_item()
        if item then
            item.event_name = name
            item.kind = kind
            item.row = selected_cell.row
            item.col = selected_cell.col
        end
    else
        if kind == "auto" then
            set_tool_auto()
        elseif kind == "fixed" then
            set_tool_fixed(name)
        elseif kind == "delete" then
            set_tool_delete()
        end
    end
end

local function apply_tool_button(button_id)
    if button_id == "delete" then
        if selected_cell then
            remove_grid_event(selected_cell.row, selected_cell.col)
            selected_cell = nil
        end
        set_tool_delete()
        return
    end

    if button_id == "auto" then
        if selected_cell then
            local item = selected_event_item()
            if item then
                item.event_name = make_auto_event_name()
                item.kind = "auto"
            end
        end
        set_tool_auto()
        return
    end

    local fixed_map = {
        event1 = "Event1",
        event2 = "Event2",
        event3 = "Event3",
        event4 = "Event4",
        event5 = "Event5",
    }

    local fixed_name = fixed_map[button_id]
    if fixed_name then
        if selected_cell then
            local item = selected_event_item()
            if item then
                item.event_name = fixed_name
                item.kind = "fixed"
            end
        end
        set_tool_fixed(fixed_name)
    end
end

local function play_trigger_sound(event_item)
    -- TODO: plug in the actual trigger sound here.
    -- event_item.event_name is the resolved name to play for.
end

function scene.play_trigger_sound(event_item)
    play_trigger_sound(event_item)
end

local function trigger_step(step_index)
    local row = step_index + 1
    local row_data = grid_events[row]
    if not row_data then
        return
    end

    for col = 1, grid_panel.cols do
        local item = row_data[col]
        if item then
            play_trigger_sound(item)
        end
    end
end

local function advance_playback_clock()
    local sixteenth_duration = (60 / bpm) / 4
    if sixteenth_duration <= 0 then
        return 0, 0, -1
    end

    local adjusted_time = player.current_time + (offset / 1000)
    local current_step = math.floor(adjusted_time / sixteenth_duration)

    if player.playing then
        if current_step > playback_last_step then
            for step = playback_last_step + 1, current_step do
                if step >= 0 then
                    trigger_step(step)
                end
            end
            playback_last_step = current_step
        elseif current_step < playback_last_step then
            playback_last_step = current_step
        end
    end

    return adjusted_time, sixteenth_duration, current_step
end

local function toggle_playback()
    if not main_music then
        print("SE: No music loaded! Please drop an .ogg file first.")
        return
    end

    if player.playing then
        main_music:pause()
        player.playing = false
        print("SE: Music paused")
    else
        main_music:play()
        player.playing = true
        print("SE: Music playing")
    end
end

local function change_bpm()
    bpm_input_active = true
    bpm_input_text = tostring(bpm)
end

local function confirm_bpm()
    local new_bpm = tonumber(bpm_input_text)
    if new_bpm and new_bpm > 0 then
        bpm = new_bpm
        print("SE: BPM changed to " .. bpm)
    else
        print("SE: Invalid BPM value")
    end
    bpm_input_active = false
    bpm_input_text = ""
end

local function cancel_bpm()
    bpm_input_active = false
    bpm_input_text = ""
end

local function change_offset()
    offset_input_active = true
    offset_input_text = tostring(offset)
end

local function confirm_offset()
    local new_offset = tonumber(offset_input_text)
    if new_offset then
        offset = new_offset
        print("SE: Offset changed to " .. offset .. "ms")
    else
        print("SE: Invalid Offset value")
    end
    offset_input_active = false
    offset_input_text = ""
end

local function cancel_offset()
    offset_input_active = false
    offset_input_text = ""
end

local function draw_top_buttons()
    local mx, my = Keyboard.GetMousePosition()
    for i = 1, #top_buttons do
        local b = top_buttons[i]
        local hover = mx >= b.x and mx <= b.x + b.w and my >= b.y and my <= b.y + b.h
        b.color = hover and {0.6, 0.6, 0.6} or {0.3, 0.3, 0.3}
        SE.graphics.setColor(b.color)
        love.graphics.rectangle("fill", b.x, b.y, b.w, b.h)
        SE.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(b.t, b.x, b.y + 1, b.w, "center")
    end
end

local function draw_edit_panel()
    local layout = get_edit_panel_layout()
    local panel_x, panel_y, panel_w, panel_h = layout.panel_x, layout.panel_y, layout.panel_w, layout.panel_h
    local inner_x, inner_y, inner_w = layout.inner_x, layout.inner_y, layout.inner_w
    local buttons = layout.buttons
    local item = selected_event_item()

    SE.graphics.setColor(0.12, 0.12, 0.12, 0.92)
    love.graphics.rectangle("fill", panel_x, panel_y, panel_w, panel_h)
    SE.graphics.setColor(0.55, 0.55, 0.55, 1)
    love.graphics.rectangle("line", panel_x, panel_y, panel_w, panel_h)

    SE.graphics.setColor(0.95, 0.95, 0.95, 1)
    SE.graphics.print("Event Edit", inner_x, inner_y)

    local selected_text = "Selected: None"
    if item then
        selected_text = string.format("Selected: R%d C%d  %s", selected_cell.row, selected_cell.col, tostring(item.event_name or item.label or "Event"))
    end
    SE.graphics.setColor(0.82, 0.82, 0.82, 1)
    SE.graphics.print(selected_text, inner_x, inner_y + 16)
    SE.graphics.print("Tool: " .. get_tool_label(), inner_x, inner_y + 30)

    local mx, my = Keyboard.GetMousePosition()
    for i = 1, #buttons do
        local b = buttons[i]
        local hover = mx >= b.x and mx <= b.x + b.w and my >= b.y and my <= b.y + b.h
        local active = false
        if placement_tool.kind == "auto" and b.id == "auto" then
            active = true
        elseif placement_tool.kind == "fixed" and b.label == placement_tool.name then
            active = true
        elseif placement_tool.kind == "delete" and b.id == "delete" then
            active = true
        end

        local fill = active and {0.45, 0.45, 0.55} or hover and {0.38, 0.38, 0.38} or {0.24, 0.24, 0.24}
        SE.graphics.setColor(fill)
        love.graphics.rectangle("fill", b.x, b.y, b.w, b.h)
        SE.graphics.setColor(0.6, 0.6, 0.6, 1)
        love.graphics.rectangle("line", b.x, b.y, b.w, b.h)
        SE.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(b.label, b.x, b.y + 1, b.w, "center")
    end

    return buttons
end

local function draw_grid()
    local layout = get_grid_layout()
    local panel_x, panel_y, panel_w, panel_h = layout.panel_x, layout.panel_y, layout.panel_w, layout.panel_h
    local inner_x, inner_y, inner_w, inner_h = layout.inner_x, layout.inner_y, layout.inner_w, layout.inner_h
    local cell_w, row_stride = layout.cell_w, layout.row_stride
    local grid_top, grid_h = layout.grid_top, layout.grid_h
    local scan_line_y = layout.scan_line_y

    clamp_grid_scroll()

    local old_sx, old_sy, old_sw, old_sh = love.graphics.getScissor()

    SE.graphics.setColor(0.12, 0.12, 0.12, 0.92)
    love.graphics.rectangle("fill", panel_x, panel_y, panel_w, panel_h)
    SE.graphics.setColor(0.55, 0.55, 0.55, 1)
    love.graphics.rectangle("line", panel_x, panel_y, panel_w, panel_h)

    SE.graphics.setColor(0.95, 0.95, 0.95, 1)
    SE.graphics.print("16th Grid", inner_x + 4, inner_y)
    SE.graphics.setColor(0.65, 0.65, 0.65, 1)
    SE.graphics.print("Wheel: scroll  LMB: place", inner_x + 88, inner_y)

    local effective_scroll = get_effective_grid_scroll(row_stride)

    love.graphics.setScissor(inner_x, grid_top, inner_w, grid_h)

    for row = 1, grid_panel.total_rows do
        local row_y = scan_line_y + (row - 1) * row_stride - effective_scroll
        local row_bottom = row_y + cell_w
        if row_bottom >= grid_top and row_y <= grid_top + grid_h then
            for col = 1, grid_panel.cols do
                local cell_x = inner_x + (col - 1) * (cell_w + grid_panel.cell_gap)
                local cell_y = row_y
                local item = grid_events[row] and grid_events[row][col]
                local selected = selected_cell and selected_cell.row == row and selected_cell.col == col
                local hover = false
                local mx, my = Keyboard.GetMousePosition()
                if mx >= cell_x and mx <= cell_x + cell_w and my >= cell_y and my <= cell_y + cell_w then
                    hover = true
                end

                if item then
                    local r, g, b = hash_color(item.event_name or item.label or "Event")
                    SE.graphics.setColor(r * 0.55, g * 0.55, b * 0.55, 0.95)
                else
                    SE.graphics.setColor(0.16, 0.16, 0.16, 0.96)
                end
                love.graphics.rectangle("fill", cell_x, cell_y, cell_w, cell_w)

                SE.graphics.setColor(0.36, 0.36, 0.36, 1)
                love.graphics.rectangle("line", cell_x, cell_y, cell_w, cell_w)

                if hover then
                    SE.graphics.setColor(1, 1, 1, 0.35)
                    love.graphics.rectangle("line", cell_x + 1, cell_y + 1, cell_w - 2, cell_w - 2)
                end

                if selected then
                    SE.graphics.setColor(1, 0.88, 0.2, 0.95)
                    love.graphics.rectangle("line", cell_x + 2, cell_y + 2, cell_w - 4, cell_w - 4)
                end

                if item then
                    local r, g, b = hash_color(item.event_name or item.label or "Event")
                    SE.graphics.setColor(r, g, b, 1)
                    love.graphics.rectangle("fill", cell_x + 3, cell_y + cell_w - 5, math.max(0, cell_w - 6), 3)
                    SE.graphics.setColor(1, 1, 1, 1)
                    SE.graphics.printf(tostring(item.event_name or item.label or "Event"), cell_x + 1, cell_y + 2, cell_w - 2, "center")
                end
            end
        end
    end

    SE.graphics.setColor(0.96, 0.96, 0.96, 0.9)
    love.graphics.rectangle("fill", inner_x, scan_line_y, inner_w, 2)
    SE.graphics.setColor(0.2, 0.95, 0.95, 1)
    love.graphics.print("SCAN", inner_x + 4, scan_line_y - 12)

    love.graphics.setScissor(old_sx, old_sy, old_sw, old_sh)
    SE.graphics.setColor(0.65, 0.65, 0.65, 1)
    SE.graphics.print(string.format("Placed: %d", grid_event_count()), inner_x + 4, panel_y + panel_h - 16)
end

local function place_event_from_tool(row, col)
    if grid_has_event(row, col) then
        select_cell(row, col)
        if placement_tool.kind == "delete" then
            remove_grid_event(row, col)
            selected_cell = nil
        end
        return
    end

    if placement_tool.kind == "delete" then
        return
    end

    local item_name
    local item_kind
    if placement_tool.kind == "fixed" and placement_tool.name then
        item_name = placement_tool.name
        item_kind = "fixed"
    else
        item_name = make_auto_event_name()
        item_kind = "auto"
    end

    place_grid_event(row, col, create_event_item(item_name, item_kind, row, col))
    select_cell(row, col)
end

local function apply_edit_panel_click(x, y)
    local layout = get_edit_panel_layout()
    for i = 1, #layout.buttons do
        local b = layout.buttons[i]
        if x >= b.x and x <= b.x + b.w and y >= b.y and y <= b.y + b.h then
            apply_tool_button(b.id)
            return true
        end
    end
    return false
end

local function update_playback_state()
    if main_music then
        player.current_time = main_music:tell()
        player.total_time = main_music:getDuration() or player.total_time
    end

    local sec_t = player.total_time or 0
    local sec_c = player.current_time or 0
    local offset_seconds = offset / 1000
    playback_adjusted_time = sec_c + offset_seconds
    playback_sixteenth_duration = (60 / bpm) / 4

    beat_total = (sec_t / 60) * bpm
    beat_current = (playback_adjusted_time / 60) * bpm

    if playback_sixteenth_duration > 0 then
        local current_step = math.floor(playback_adjusted_time / playback_sixteenth_duration)
        if player.playing then
            if current_step > playback_last_step then
                for step = playback_last_step + 1, current_step do
                    if step >= 0 then
                        trigger_step(step)
                    end
                end
                playback_last_step = current_step
            elseif current_step < playback_last_step then
                playback_last_step = current_step
            end
        end
    end
end

-- ============================================
-- 3. LIFECYCLE
-- ============================================
function scene.load()
    main_font = SE.graphics.newFont("Resources/Fonts/determination_mono.ttf", 13, "mono")

    bpm = 180
    beat_current = 0
    beat_total = 0
    playback_last_step = -1
    playback_adjusted_time = 0
    playback_sixteenth_duration = (60 / bpm) / 4
    selected_cell = nil
    top_buttons = {}
    grid_events = {}
    placement_tool.kind = "auto"
    placement_tool.name = nil
    grid_panel.scroll = 0

    new_top_button("Play/Pause", 20, 50, 100, 20, toggle_playback)
    new_top_button("Change BPM", bpm_input_x, bpm_input_y, bpm_input_w, bpm_input_h, change_bpm)
    new_top_button("Change Offset", offset_input_x, offset_input_y, offset_input_w, offset_input_h, change_offset)
end

function scene.update(dt)
    update_playback_state()
end

function scene.draw()
    SE.graphics.setFont(main_font)
    SE.graphics.setColor(1, 1, 1, 1)

    SE.graphics.print("events handler v1.0.0", 0, 0)
    SE.graphics.printf("drop .ogg file here", 0, 0, 640, "right")
    SE.graphics.print(string.format("Current Time: %.3f / %.3f", player.current_time, player.total_time), 20, 80)
    SE.graphics.print(string.format("Beat: %.3f / %.3f", beat_current, beat_total), 20, 100)
    SE.graphics.print("Current BPM: " .. bpm, 20, 130)
    SE.graphics.print("Current Offset: " .. offset .. "ms", 20, 200)

    if bpm_input_active then
        SE.graphics.setColor(0.2, 0.2, 0.2, 0.8)
        love.graphics.rectangle("fill", bpm_input_x, bpm_input_y + 25, bpm_input_w, bpm_input_h)
        SE.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("line", bpm_input_x, bpm_input_y + 25, bpm_input_w, bpm_input_h)
        SE.graphics.print(bpm_input_text, bpm_input_x + 2, bpm_input_y + 25)
        SE.graphics.setColor(0.6, 0.6, 0.6, 1)
        SE.graphics.print("Enter = confirm\nESC = cancel", 130, bpm_input_y + 2)
    end

    if offset_input_active then
        SE.graphics.setColor(0.2, 0.2, 0.2, 0.8)
        love.graphics.rectangle("fill", offset_input_x, offset_input_y + 25, offset_input_w, offset_input_h)
        SE.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("line", offset_input_x, offset_input_y + 25, offset_input_w, offset_input_h)
        SE.graphics.print(offset_input_text, offset_input_x + 2, offset_input_y + 25)
        SE.graphics.setColor(0.6, 0.6, 0.6, 1)
        SE.graphics.print("Enter = confirm\nESC = cancel", offset_input_x + offset_input_w + 10, offset_input_y + 2)
    end

    draw_grid()
    draw_edit_panel()
    draw_top_buttons()
end

function scene.clear()
    Layers.clear()
end

function scene.quit()
    print("SE.quit: Game is quitting... Goodbye!")
end

-- ============================================
-- 4. INPUT
-- ============================================
function scene.keypressed(key, scancode, isrepeat)
    if bpm_input_active then
        if key == "escape" then
            cancel_bpm()
            return
        elseif key == "return" or key == "kpenter" then
            confirm_bpm()
            return
        elseif key == "backspace" then
            bpm_input_text = bpm_input_text:sub(1, -2)
        elseif key:match("^[%d%.]$") then
            if key ~= "." or not bpm_input_text:find("%.") then
                bpm_input_text = bpm_input_text .. key
            end
        end
        return
    end

    if offset_input_active then
        if key == "escape" then
            cancel_offset()
            return
        elseif key == "return" or key == "kpenter" then
            confirm_offset()
            return
        elseif key == "backspace" then
            offset_input_text = offset_input_text:sub(1, -2)
        elseif key == "-" then
            if #offset_input_text == 0 then
                offset_input_text = "-"
            end
        elseif key:match("^[%d]$") then
            offset_input_text = offset_input_text .. key
        end
        return
    end
end

function scene.mousepressed(x, y, button, istouch, presses)
    if bpm_input_active then
        if not (x >= bpm_input_x and x <= bpm_input_x + bpm_input_w and y >= bpm_input_y and y <= bpm_input_y + bpm_input_h) then
            cancel_bpm()
            return
        end
    end

    if offset_input_active then
        if not (x >= offset_input_x and x <= offset_input_x + offset_input_w and y >= offset_input_y and y <= offset_input_y + offset_input_h) then
            cancel_offset()
            return
        end
    end

    if button ~= 1 then
        return
    end

    for i = 1, #top_buttons do
        local b = top_buttons[i]
        if x >= b.x and x <= b.x + b.w and y >= b.y and y <= b.y + b.h then
            if b.func then
                b.func()
            end
            return
        end
    end

    if apply_edit_panel_click(x, y) then
        return
    end

    local row, col = get_hovered_grid_cell(x, y)
    if row and col then
        place_event_from_tool(row, col)
    end
end

function scene.mousereleased(x, y, button, istouch, presses)
end

function scene.mousemoved(x, y, dx, dy, istouch)
end

function scene.wheelmoved(x, y)
    if bpm_input_active or offset_input_active then
        return
    end

    local mx, my = Keyboard.GetMousePosition()
    local panel_x, panel_y, panel_w, panel_h = get_grid_rect()
    if mx >= panel_x and mx <= panel_x + panel_w and my >= panel_y and my <= panel_y + panel_h then
        local layout = get_grid_layout()
        local rows_per_wheel_step = 4
        grid_panel.scroll = grid_panel.scroll - (y * layout.row_stride * rows_per_wheel_step)
        clamp_grid_scroll()
    end
end

-- ============================================
-- 5. PUBLIC API
-- ============================================
function scene.set_events(list)
    grid_events = {}
    next_auto_event_id = 1

    if type(list) == "table" then
        for _, item in ipairs(list) do
            if type(item) == "table" then
                local row = tonumber(item.row or item.beat_row or item.y)
                local col = tonumber(item.col or item.column or item.x)
                if row and col then
                    local name = item.event_name or item.name or item.label
                    local kind = item.kind or (name and name:match("^EventU") and "auto") or "fixed"
                    if kind == "auto" and name and name:match("^EventU(%d+)$") then
                        local n = tonumber(name:match("^EventU(%d+)$"))
                        if n and n >= next_auto_event_id then
                            next_auto_event_id = n + 1
                        end
                    end
                    place_grid_event(math.floor(row), math.floor(col), create_event_item(name or make_auto_event_name(), kind, math.floor(row), math.floor(col)))
                end
            end
        end
    end

    clamp_grid_scroll()
end

function scene.add_event(item)
    if type(item) == "table" then
        local row = tonumber(item.row or item.beat_row or item.y)
        local col = tonumber(item.col or item.column or item.x)
        if row and col then
            local name = item.event_name or item.name or item.label or make_auto_event_name()
            local kind = item.kind or (name:match("^EventU") and "auto") or "fixed"
            place_grid_event(math.floor(row), math.floor(col), create_event_item(name, kind, math.floor(row), math.floor(col)))
            clamp_grid_scroll()
            return
        end
    end

    local row, col = find_first_empty_cell()
    if row and col then
        place_grid_event(row, col, create_event_item(make_auto_event_name(), "auto", row, col))
    end
    clamp_grid_scroll()
end

-- ============================================
-- 6. FILE DROP
-- ============================================
function scene.filedropped(file)
    if file:getExtension() ~= "ogg" then
        return
    end

    local success = pcall(function()
        file:open("r")
        main_music = SE.audio.newSource(file, "stream")
        player.total_time = main_music:getDuration() or 0
        player.current_time = 0
        player.playing = false
        playback_last_step = -1
    end)

    if not success then
        print("[ERROR] Loading .ogg file failed!")
    end
end

function scene.directorydropped(dir)
end

return scene
