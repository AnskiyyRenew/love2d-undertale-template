local scene = {}

local progress = 0
local main_font = Fonts.New("determination_mono.ttf", 13, "mono")
local small_font = Fonts.New("determination_mono.ttf", 9, "mono")
local top_buttons = {}
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

-- Bezier curve editor state
local bezier_points = {
    {x = 0.0, y = 0.0},
    {x = 0.33, y = 0.67},
    {x = 0.67, y = 0.33},
    {x = 1.0, y = 1.0},
}
local selected_idx = nil
local is_playing = false
local anim_t = 0
local anim_duration = 120
local drag_idx = nil

-- Canvas area (right side of the screen)
local CANVAS_X = 220
local CANVAS_Y = 40
local CANVAS_W = 360
local CANVAS_H = 400

-- Hit radius for control points, px
local PT_RADIUS = 6

local function screen_to_curve(sx, sy)
    local cx = (sx - CANVAS_X) / CANVAS_W
    local cy = (CANVAS_Y + CANVAS_H - sy) / CANVAS_H
    return cx, cy
end

local function curve_to_screen(cx, cy)
    local sx = CANVAS_X + cx * CANVAS_W
    local sy = CANVAS_Y + CANVAS_H - cy * CANVAS_H
    return sx, sy
end

-- De Casteljau at parameter t (0~1). Returns y first, then x.
local function bezier_eval(points, t)
    local n = #points
    if n == 0 then return 0, 0 end
    if n == 1 then return points[1].y, points[1].x end

    local px = {}
    local py = {}
    for i = 1, n do
        px[i] = points[i].x
        py[i] = points[i].y
    end

    for level = n, 2, -1 do
        for i = 1, level - 1 do
            px[i] = px[i] * (1 - t) + px[i + 1] * t
            py[i] = py[i] * (1 - t) + py[i + 1] * t
        end
    end
    return py[1], px[1]
end

local function clamp01(v)
    return math.max(0, math.min(1, v))
end

local function find_closest_point(sx, sy)
    local best_idx = nil
    local best_dist = PT_RADIUS + 2
    for i, pt in ipairs(bezier_points) do
        local psx, psy = curve_to_screen(pt.x, pt.y)
        local dx = sx - psx
        local dy = sy - psy
        local dist = math.sqrt(dx * dx + dy * dy)
        if dist < best_dist then
            best_dist = dist
            best_idx = i
        end
    end
    return best_idx
end

local function point_add()
    if #bezier_points < 2 then
        table.insert(bezier_points, {x = 0.5, y = 0.5})
        selected_idx = #bezier_points
        return
    end

    if selected_idx and selected_idx < #bezier_points then
        local p = bezier_points[selected_idx]
        local np = bezier_points[selected_idx + 1]
        local new_pt = {
            x = clamp01((p.x + np.x) / 2),
            y = clamp01((p.y + np.y) / 2),
        }
        table.insert(bezier_points, selected_idx + 1, new_pt)
        selected_idx = selected_idx + 1
    elseif selected_idx == #bezier_points then
        local p = bezier_points[selected_idx - 1]
        local np = bezier_points[selected_idx]
        local new_pt = {
            x = clamp01((p.x + np.x) / 2),
            y = clamp01((p.y + np.y) / 2),
        }
        table.insert(bezier_points, selected_idx, new_pt)
    else
        local y, x = bezier_eval(bezier_points, 0.5)
        -- Offset slightly so the new point is draggable, not exactly on the curve.
        local new_pt = {x = clamp01(x + 0.02), y = clamp01(y + 0.02)}
        local insert_at = math.max(2, math.floor(#bezier_points / 2))
        table.insert(bezier_points, insert_at, new_pt)
        selected_idx = insert_at
    end
end

local function point_delete()
    if selected_idx and #bezier_points > 2 then
        -- First and last points are the start / end anchors.
        if selected_idx == 1 or selected_idx == #bezier_points then
            print("Cannot delete start or end anchor point")
            return
        end
        table.remove(bezier_points, selected_idx)
        if selected_idx > #bezier_points then
            selected_idx = #bezier_points
        end
    else
        print("Select a point to delete first")
    end
end

local function export_code()
    local lines = {}
    table.insert(lines, "--[[")
    table.insert(lines, "  Exported Bezier Easing Curve")
    table.insert(lines, "  Paste this code into your project, then use:")
    table.insert(lines, '  tween.CreateTween(setter, "myBezier", "", beginVal, endVal, duration)')
    table.insert(lines, "--]]")
    table.insert(lines, "")
    table.insert(lines, 'Tween.CreateCustomTween("myBezier", function(t)')
    table.insert(lines, "    local pts = {")
    for _, pt in ipairs(bezier_points) do
        table.insert(lines, string.format("        {x = %.4f, y = %.4f},", pt.x, pt.y))
    end
    table.insert(lines, "    }")
    table.insert(lines, "    local n = #pts")
    table.insert(lines, "    local px, py = {}, {}")
    table.insert(lines, "    for i = 1, n do")
    table.insert(lines, "        px[i], py[i] = pts[i].x, pts[i].y")
    table.insert(lines, "    end")
    table.insert(lines, "    for level = n, 2, -1 do")
    table.insert(lines, "        for i = 1, level - 1 do")
    table.insert(lines, "            px[i] = px[i] * (1 - t) + px[i + 1] * t")
    table.insert(lines, "            py[i] = py[i] * (1 - t) + py[i + 1] * t")
    table.insert(lines, "        end")
    table.insert(lines, "    end")
    table.insert(lines, "    return py[1]")
    table.insert(lines, "end)")

    local code = table.concat(lines, "\n")
    print("=== Exported Bezier Easing ===")
    print(code)
    print("=== End Export ===")

    local f, err = io.open("Debug/exported_bezier.lua", "w")
    if f then
        f:write(code)
        f:close()
        print("Saved to exported_bezier.lua")
    else
        print("Failed to write file: " .. tostring(err))
    end
end

local function play_anim()
    anim_t = 0
    is_playing = true
    print("Playing animation from start")
end

local function draw_canvas()
    SE.graphics.setColor(0.15, 0.15, 0.15, 1)
    SE.graphics.rectangle("fill", CANVAS_X, CANVAS_Y, CANVAS_W, CANVAS_H)

    SE.graphics.setColor(0.25, 0.25, 0.25, 1)
    for i = 0, 4 do
        local frac = i / 4
        local sx, sy = curve_to_screen(frac, 0)
        SE.graphics.line(sx, CANVAS_Y, sx, CANVAS_Y + CANVAS_H)
        local sx2, sy2 = curve_to_screen(0, frac)
        SE.graphics.line(CANVAS_X, sy2, CANVAS_X + CANVAS_W, sy2)
    end

    SE.graphics.setColor(0.5, 0.5, 0.5, 1)
    SE.graphics.setFont(small_font)
    SE.graphics.printf("0", CANVAS_X - 14, CANVAS_Y + CANVAS_H - 6, 12, "right")
    SE.graphics.printf("1", CANVAS_X - 14, CANVAS_Y - 4, 12, "right")
    SE.graphics.printf("0", CANVAS_X - 2, CANVAS_Y + CANVAS_H + 2, 20, "center")
    SE.graphics.printf("1", CANVAS_X + CANVAS_W - 10, CANVAS_Y + CANVAS_H + 2, 20, "center")

    -- Diagonal reference line (linear = y=x)
    SE.graphics.setColor(0.3, 0.3, 0.3, 1)
    local lx0, ly0 = curve_to_screen(0, 0)
    local lx1, ly1 = curve_to_screen(1, 1)
    SE.graphics.line(lx0, ly0, lx1, ly1)

    local samples = {}
    for i = 0, 100 do
        local t = i / 100
        local y = bezier_eval(bezier_points, t)
        local sx, sy = curve_to_screen(t, y)
        table.insert(samples, {sx, sy})
    end

    SE.graphics.setColor(0.2, 0.8, 1.0, 1)
    SE.graphics.setLineWidth(2)
    for i = 1, #samples - 1 do
        SE.graphics.line(samples[i][1], samples[i][2], samples[i + 1][1], samples[i + 1][2])
    end
    SE.graphics.setLineWidth(1)

    SE.graphics.setColor(0.5, 0.5, 0.5, 0.5)
    for i = 1, #bezier_points - 1 do
        local x1, y1 = curve_to_screen(bezier_points[i].x, bezier_points[i].y)
        local x2, y2 = curve_to_screen(bezier_points[i + 1].x, bezier_points[i + 1].y)
        SE.graphics.line(x1, y1, x2, y2)
    end

    for i, pt in ipairs(bezier_points) do
        local sx, sy = curve_to_screen(pt.x, pt.y)

        -- Selected point halo
        if i == selected_idx then
            SE.graphics.setColor(1, 1, 0, 1)
            SE.graphics.circle("fill", sx, sy, PT_RADIUS + 3)
            SE.graphics.setColor(1, 0.5, 0, 1)
            SE.graphics.circle("fill", sx, sy, PT_RADIUS + 1)
        end

        -- Start / end anchors are squares, inner points are circles.
        if i == 1 or i == #bezier_points then
            SE.graphics.setColor(0.3, 1.0, 0.3, 1)
            SE.graphics.rectangle("fill", sx - PT_RADIUS, sy - PT_RADIUS, PT_RADIUS * 2, PT_RADIUS * 2)
        else
            SE.graphics.setColor(1.0, 0.7, 0.2, 1)
            SE.graphics.circle("fill", sx, sy, PT_RADIUS)
        end

        if i == selected_idx then
            SE.graphics.setColor(1, 1, 1, 1)
        else
            SE.graphics.setColor(0.8, 0.8, 0.8, 1)
        end
        if i == 1 or i == #bezier_points then
            SE.graphics.rectangle("line", sx - PT_RADIUS, sy - PT_RADIUS, PT_RADIUS * 2, PT_RADIUS * 2)
        else
            SE.graphics.circle("line", sx, sy, PT_RADIUS)
        end

        SE.graphics.setColor(1, 1, 1, 0.7)
        SE.graphics.setFont(small_font)
        SE.graphics.printf(tostring(i - 1), sx - 10, sy - PT_RADIUS - 12, 20, "center")
    end

    if is_playing then
        local y = bezier_eval(bezier_points, anim_t)
        local px, py = curve_to_screen(anim_t, y)
        local sq = 12

        SE.graphics.setColor(1, 0.3, 0.3, 0.3)
        SE.graphics.line(px, CANVAS_Y, px, CANVAS_Y + CANVAS_H)

        SE.graphics.setColor(1, 0.3, 0.3, 1)
        SE.graphics.rectangle("fill", px - sq / 2, py - sq / 2, sq, sq)
        SE.graphics.setColor(1, 1, 1, 1)
        SE.graphics.rectangle("line", px - sq / 2, py - sq / 2, sq, sq)

        SE.graphics.setFont(small_font)
        SE.graphics.setColor(1, 1, 1, 0.8)
        SE.graphics.printf(string.format("t=%.2f  y=%.2f", anim_t, y), CANVAS_X, CANVAS_Y + CANVAS_H + 14, CANVAS_W, "center")
    else
        SE.graphics.setFont(small_font)
        SE.graphics.setColor(0.5, 0.5, 0.5, 1)
        SE.graphics.printf("Click \"Play Animation\" to preview", CANVAS_X, CANVAS_Y + CANVAS_H + 14, CANVAS_W, "center")
    end

    SE.graphics.setFont(small_font)
    SE.graphics.setColor(0.6, 0.6, 0.6, 1)
    SE.graphics.printf("Points: " .. #bezier_points .. "  |  Drag to edit", CANVAS_X, CANVAS_Y - 14, CANVAS_W, "center")
end

function scene.load()
    new_top_button("Add Point", 20, 60, 160, 30, point_add)
    new_top_button("Delete Point", 20, 100, 160, 30, point_delete)
    new_top_button("Play Animation", 20, 140, 160, 30, play_anim)
    new_top_button("Export Animation", 20, 200, 160, 30, export_code)

    Layers.add_external(function()
        SE.graphics.setColor(0.1, 0.1, 0.1, 1)
        SE.graphics.rectangle("fill", 0, 0, 200, 480)

        SE.graphics.setColor(1, 1, 1)
        SE.graphics.setFont(main_font)
        SE.graphics.printf("Animation Editor", 0, 20, 200, "center")
    end, 0)

    Layers.add_external(draw_canvas, 0)

    for i = 1, #top_buttons do
        local b = top_buttons[i]
        Layers.add_external(function()
            SE.graphics.setColor(b.color)
            SE.graphics.rectangle("fill", b.x, b.y, b.w, b.h)

            SE.graphics.setColor(1, 1, 1)
            SE.graphics.setFont(main_font)
            SE.graphics.printf(b.t, b.x, b.y + 6, b.w, "center")
        end, 1)
    end
end

function scene.update(dt)
    local mx, my = Keyboard.GetMousePosition()

    for i = 1, #top_buttons do
        local b = top_buttons[i]
        local hover = mx >= b.x and mx <= b.x + b.w and my >= b.y and my <= b.y + b.h
        b.color = hover and {0.6, 0.6, 0.6} or {0.3, 0.3, 0.3}
    end

    if is_playing then
        anim_t = anim_t + 1 / anim_duration
        if anim_t >= 1 then
            anim_t = 1
            is_playing = false
        end
    end

    if drag_idx then
        local pt = bezier_points[drag_idx]
        if pt then
            local cx, cy = screen_to_curve(mx, my)
            pt.x = clamp01(cx)
            pt.y = clamp01(cy)
        end
    end
end

function scene.draw()
end

function scene.clear()
    Layers.clear()
end

function scene.quit()
    print("SE.quit: Game is quitting... Goodbye!")
end

function scene.keypressed(key, scancode, isrepeat)
    if key == "escape" then
        SE.event.quit()
    end
    if key == "delete" or key == "backspace" then
        point_delete()
    end
end

function scene.keyreleased(key, scancode, isrepeat)
end

function scene.textinput(text)
end

function scene.mousepressed(x, y, button, istouch, presses)
    for i = 1, #top_buttons do
        local b = top_buttons[i]
        if x >= b.x and x <= b.x + b.w and y >= b.y and y <= b.y + b.h then
            if b.func then
                b.func()
            end
            return
        end
    end

    if x >= CANVAS_X and x <= CANVAS_X + CANVAS_W and
       y >= CANVAS_Y and y <= CANVAS_Y + CANVAS_H then
        local idx = find_closest_point(x, y)
        if idx then
            selected_idx = idx
            drag_idx = idx
        else
            selected_idx = nil
            drag_idx = nil
        end
    end
end

function scene.mousereleased(x, y, button, istouch, presses)
    drag_idx = nil
end

function scene.mousemoved(x, y, dx, dy, istouch)
end

function scene.wheelmoved(x, y)
end

function scene.focus(f)
end

function scene.resize(w, h)
end

function scene.visible(v)
end

function scene.filedropped(file)
end

function scene.directorydropped(dir)
end

return scene
