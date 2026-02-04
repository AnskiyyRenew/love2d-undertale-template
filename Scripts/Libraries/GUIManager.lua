-- gui.lua
-- Improved LOVE2D GUI library
local gui = {
    buttons = {},
    texts = {},
    text_inputs = {},
    images = {},
    sliders = {},
    checkboxes = {},
    dropdowns = {},
    progress_bars = {},
    panels = {},
    windows = {},
    _focused = nil,           -- currently focused text_input
}

-- -----------------------
-- Helpers
-- -----------------------
local function clamp(v, a, b) return math.max(a, math.min(b, v)) end
local function safe_get_font(font)
    return font or love.graphics.getFont()
end
local function saveColor()
    if love.graphics.getColor then
        return {love.graphics.getColor()}
    else
        return nil
    end
end
local function restoreColor(c)
    if c and love.graphics.setColor then
        love.graphics.setColor(unpack(c))
    end
end

local function is_point_in_rect(px, py, x, y, w, h)
    return px >= x and py >= y and px <= x + w and py <= y + h
end

local function idxOf(tbl, item)
    for i, v in ipairs(tbl) do if v == item then return i end end
    return nil
end

-- -----------------------
-- Core management
-- -----------------------
function gui.clear()
    gui.buttons = {}
    gui.texts = {}
    gui.text_inputs = {}
    gui.images = {}
    gui.sliders = {}
    gui.checkboxes = {}
    gui.dropdowns = {}
    gui.progress_bars = {}
    gui.panels = {}
    gui._focused = nil
end

function gui.remove(element)
    -- remove element from any list it may be in
    local lists = {
        gui.buttons, gui.texts, gui.text_inputs, gui.images, gui.sliders,
        gui.checkboxes, gui.dropdowns, gui.progress_bars, gui.panels
    }
    for _, list in ipairs(lists) do
        local i = idxOf(list, element)
        if i then
            table.remove(list, i)
            if gui._focused == element then gui._focused = nil end
            return true
        end
    end
    return false
end

function gui.bringToFront(element)
    local lists = {
        gui.buttons, gui.texts, gui.text_inputs, gui.images, gui.sliders,
        gui.checkboxes, gui.dropdowns, gui.progress_bars, gui.panels
    }
    for _, list in ipairs(lists) do
        local i = idxOf(list, element)
        if i then
            table.remove(list, i)
            table.insert(list, element)
            return true
        end
    end
    return false
end

-- -----------------------
-- Buttons
-- -----------------------
local function default_button_draw(b)
    local prev = saveColor()
    love.graphics.setColor(unpack(b.color))
    love.graphics.rectangle("fill", b.x, b.y, b.width, b.height, b.radius or 0)
    love.graphics.setColor(unpack(b.colors.font))
    love.graphics.setFont(b.font)
    local textHeight = b.font:getHeight(b.text or "")
    local textY = b.y + (b.height - textHeight) / 2
    love.graphics.printf(b.text or "", b.x, textY, b.width, "center")
    restoreColor(prev)
end

---Creates base button table (used by specific shapes)
function gui._create_button(params)
    local b = {
        x = params.x or 0,
        y = params.y or 0,
        width = params.width or 100,
        height = params.height or 30,
        text = params.text or "",
        callback = params.callback,
        enabled = params.enabled == nil and true or params.enabled,
        colors = params.colors or {
            normal   = {0.30, 0.30, 0.30},
            hover    = {0.40, 0.40, 0.40},
            pressed  = {0.40, 0.45, 0.50},
            disabled = {0.80, 0.80, 0.80},
            font     = {1.00, 1.00, 1.00},
        },
        font = safe_get_font(params.font),
        radius = params.radius,
        image = params.image, -- optional image
        -- state
        is_hovered = false,
        is_pressed = false,
        color = nil,
        _pressed_inside = false, -- track press origin
        draw = params.draw or default_button_draw,
    }
    b.color = b.enabled and b.colors.normal or b.colors.disabled
    table.insert(gui.buttons, b)
    return b
end

function gui.add_button_rect(x, y, width, height, text, callback, opts)
    opts = opts or {}
    return gui._create_button{ x=x, y=y, width=width, height=height, text=text, callback=callback, font=opts.font }
end

function gui.add_button_roundrect(x, y, width, height, radius, text, callback, opts)
    opts = opts or {}
    return gui._create_button{ x=x, y=y, width=width, height=height, text=text, callback=callback, radius=radius, font=opts.font }
end

function gui.add_button_ellipse(x, y, width, height, text, callback, opts)
    -- ellipse uses custom draw
    opts = opts or {}
    local b = gui._create_button{ x=x, y=y, width=width, height=height, text=text, callback=callback, font=opts.font }
    b.draw = function()
        local prev = saveColor()
        love.graphics.setColor(unpack(b.color))
        love.graphics.ellipse("fill", b.x + b.width/2, b.y + b.height/2, b.width/2, b.height/2)
        love.graphics.setColor(unpack(b.colors.font))
        love.graphics.setFont(b.font)
        local textHeight = b.font:getHeight(b.text or "")
        local textY = b.y + (b.height - textHeight) / 2
        love.graphics.printf(b.text or "", b.x, textY, b.width, "center")
        restoreColor(prev)
    end
    return b
end

function gui.add_button_image(x, y, image_path_or_obj, callback, opts)
    opts = opts or {}
    local img = image_path_or_obj
    if type(image_path_or_obj) == "string" then
        local ok, loaded = pcall(love.graphics.newImage, image_path_or_obj)
        if not ok then
            error("gui: failed to load image: " .. tostring(image_path_or_obj))
        end
        img = loaded
    end
    if img.setFilter then pcall(img.setFilter, img, "nearest", "nearest") end
    local b = gui._create_button{ x=x, y=y, width=img:getWidth(), height=img:getHeight(), text="", callback=callback, font=opts.font }
    b.image = img
    b.draw = function()
        local prev = saveColor()
        love.graphics.setColor(unpack(b.color))
        love.graphics.draw(b.image, b.x, b.y)
        restoreColor(prev)
    end
    return b
end

-- -----------------------
-- Texts
-- -----------------------
function gui.add_text(x, y, text, font, color)
    local f = safe_get_font(font)
    local txt = {
        x = x, y = y,
        text = text or "",
        font = f,
        color = color or {1,1,1},
        draw = function(self)
            local prev = saveColor()
            love.graphics.setColor(unpack(self.color))
            love.graphics.setFont(self.font)
            love.graphics.print(self.text, self.x, self.y)
            restoreColor(prev)
        end
    }
    table.insert(gui.texts, txt)
    return txt
end

-- -----------------------
-- Sliders
-- -----------------------
function gui.add_slider(x, y, width, height, min, max, value, callback, step, orientation, opts)
    opts = opts or {}
    if max == min then max = min + 1 end
    local s = {
        x = x, y = y, width = width, height = height,
        min = min, max = max,
        value = clamp(value or min, min, max),
        callback = callback,
        step = step or 0,
        orientation = orientation or "horizontal",
        ticks = opts.ticks or false,
        disabled = opts.disabled or false,
        show_value = opts.show_value or false,
        dragging = false,
        draw = function(self)
            local prev = saveColor()
            -- background
            love.graphics.setColor(0.7,0.7,0.7)
            love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)
            local ratio = (self.value - self.min) / (self.max - self.min)
            if self.orientation == "horizontal" then
                local handleX = self.x + ratio * self.width
                love.graphics.setColor(0.3,0.3,0.3)
                love.graphics.rectangle("fill", handleX - 5, self.y, 10, self.height)
                if self.show_value then
                    love.graphics.setColor(1,1,1)
                    love.graphics.print(tostring(self.value), self.x + self.width + 6, self.y)
                end
            else
                local handleY = self.y + (1 - ratio) * self.height
                love.graphics.setColor(0.3,0.3,0.3)
                love.graphics.rectangle("fill", self.x, handleY - 5, self.width, 10)
                if self.show_value then
                    love.graphics.setColor(1,1,1)
                    love.graphics.print(tostring(self.value), self.x + self.width + 6, self.y)
                end
            end
            restoreColor(prev)
        end
    }
    table.insert(gui.sliders, s)
    return s
end

-- -----------------------
-- Text Inputs
-- -----------------------
function gui.add_text_input(x, y, width, height, placeholder, callback, opts)
    opts = opts or {}
    local ti = {
        x = x, y = y, width = width, height = height,
        placeholder = placeholder or "",
        text = "",
        callback = callback or function() end,
        is_focused = false,
        font = safe_get_font(opts.font),
        draw = function(self)
            local prev = saveColor()
            love.graphics.setColor(1,1,1)
            love.graphics.rectangle("line", self.x, self.y, self.width, self.height)
            love.graphics.setFont(self.font)
            local display_text = (self.text ~= "" and self.text) or self.placeholder
            love.graphics.print(display_text, self.x + 5, self.y + (self.height - self.font:getHeight())/2)
            restoreColor(prev)
        end
    }
    table.insert(gui.text_inputs, ti)
    return ti
end

-- -----------------------
-- Table / Panel (kept, improved)
-- -----------------------
function gui.add_table(x, y, w, h, headers, config)
    config = config or {}
    local tbl = {
        x = x, y = y, width = w, height = h,
        headers = headers or {},
        data = {},
        col_widths = {},
        row_heights = {},
        visible_rows = math.max(1, math.floor((h - 30) / 20)),
        scroll_offset = 0,
        colors = config.colors or {
            border = {0.8,0.8,0.8},
            header_bg = {0.3,0.3,0.5,0.8},
            cell_bg = {0.2,0.2,0.2,0.5}
        },
        font = safe_get_font(config.font),
    }

    local total_header_width = 0
    for i, header in ipairs(tbl.headers) do
        local width = tbl.font:getWidth(header) + 20
        tbl.col_widths[i] = width
        total_header_width = total_header_width + width
    end
    if total_header_width < w and #tbl.headers > 0 then
        local extra = (w - total_header_width) / #tbl.headers
        for i = 1, #tbl.headers do
            tbl.col_widths[i] = tbl.col_widths[i] + extra
        end
    end

    local methods = {}

    function methods:add_row(row_data)
        table.insert(self.data, row_data)
        self:_adjust_row_height(#self.data, row_data)
    end
    function methods:remove_row(index)
        if index >= 1 and index <= #self.data then
            table.remove(self.data, index)
            table.remove(self.row_heights, index)
        end
    end
    function methods:update_cell(row, col, value)
        if self.data[row] then
            self.data[row][col] = value
            self:_adjust_row_height(row, self.data[row])
        end
    end
    function methods:_adjust_row_height(row_index, row_data)
        local max_height = 20
        for col, value in ipairs(row_data) do
            local text = tostring(value)
            local lines = math.ceil((self.font:getWidth(text) + 1) / (self.col_widths[col] or 50))
            max_height = math.max(max_height, lines * self.font:getHeight() + 10)
        end
        self.row_heights[row_index] = max_height
    end
    function methods:_draw_border()
        local prev = saveColor()
        love.graphics.setColor(self.colors.border)
        love.graphics.rectangle("line", self.x, self.y, self.width, self.height)
        restoreColor(prev)
    end
    function methods:_draw_headers()
        local prev = saveColor()
        love.graphics.setColor(self.colors.header_bg)
        love.graphics.rectangle("fill", self.x, self.y, self.width, 30)
        love.graphics.setColor(1,1,1)
        local x_pos = self.x
        for i, header in ipairs(self.headers) do
            love.graphics.print(header, x_pos + 5, self.y + 8)
            x_pos = x_pos + (self.col_widths[i] or 80)
        end
        restoreColor(prev)
    end
    function methods:_draw_rows()
        local y_pos = self.y + 30
        local start_row = math.max(1, self.scroll_offset + 1)
        local end_row = math.min(#self.data, start_row + self.visible_rows - 1)
        for i = start_row, end_row do
            local row_y = y_pos + (i - start_row) * (self.row_heights[i] or 20)
            self:_draw_row(i, self.data[i], row_y)
        end
    end
    function methods:_draw_row(row_index, row_data, y_pos)
        local prev = saveColor()
        love.graphics.setColor(self.colors.cell_bg)
        love.graphics.rectangle("fill", self.x, y_pos, self.width, self.row_heights[row_index] or 20)
        love.graphics.setColor(1,1,1)
        local x_pos = self.x
        for col, value in ipairs(row_data) do
            love.graphics.print(tostring(value), x_pos + 5, y_pos + 5)
            love.graphics.rectangle("line", x_pos, y_pos, self.col_widths[col] or 80, self.row_heights[row_index] or 20)
            x_pos = x_pos + (self.col_widths[col] or 80)
        end
        restoreColor(prev)
    end
    function methods:draw()
        self:_draw_border()
        self:_draw_headers()
        self:_draw_rows()
    end

    for k, v in pairs(methods) do tbl[k] = v end
    table.insert(gui.panels, tbl)
    return tbl
end

function gui.add_window(x, y, w, h, title, opts)
    opts = opts or {}
    local win = {
        x = x or 100, y = y or 100,
        width = w or 300, height = h or 200,
        title = title or "Window",
        draggable = opts.draggable == nil and true or opts.draggable,
        closable  = opts.closable  == nil and true or opts.closable,
        minimizable = opts.minimizable == nil and true or opts.minimizable,
        maximizable = opts.maximizable == nil and true or opts.maximizable,
        visible = true,
        minimized = false,
        maximized = false,
        prev = {x=x, y=y, w=w, h=h},
        title_height = opts.title_height or 24,
        color = opts.color or {0.15,0.15,0.15},
        title_color = opts.title_color or {0.22,0.22,0.22},
        title_text_color = opts.title_text_color or {1,1,1},
        children = {},  -- child controls (relative to client)
        onclose = opts.onclose,
        onminimize = opts.onminimize,
        onmaximize = opts.onmaximize,
        dragging = false,
        drag_offx = 0,
        drag_offy = 0
    }

    function win:add_child(child)
        table.insert(self.children, child)
        return child
    end

    function win:bringToFront()
        -- move this window to end of gui.windows so drawn last (topmost)
        for i=#gui.windows,1,-1 do
            if gui.windows[i] == self then table.remove(gui.windows, i); break end
        end
        table.insert(gui.windows, self)
    end

    function win:contains(px, py)
        return is_point_in_rect(px, py, self.x, self.y, self.width, self.height)
    end

    function win:client_rect()
        return 0, self.title_height, self.width, self.height - self.title_height
    end

    function win:to_local(px, py)
        -- return coords relative to client origin (0, title_height)
        return px - self.x, py - (self.y + self.title_height)
    end

    function win:close()
        self.visible = false
        if self.onclose then pcall(self.onclose, self) end
    end

    function win:minimize()
        self.minimized = not self.minimized
        if self.onminimize then pcall(self.onminimize, self) end
    end

    function win:maximize()
        if not self.maximized then
            self.prev = {x=self.x, y=self.y, w=self.width, h=self.height}
            self.x, self.y, self.width, self.height = 0, 0, love.graphics.getWidth(), love.graphics.getHeight()
            self.maximized = true
        else
            self.x, self.y, self.width, self.height = self.prev.x, self.prev.y, self.prev.w, self.prev.h
            self.maximized = false
        end
        if self.onmaximize then pcall(self.onmaximize, self) end
    end

    function win:mousepressed(mx, my, button)
        if not self.visible then return false end
        -- titlebar area?
        local title_h = self.title_height
        if is_point_in_rect(mx, my, self.x, self.y, self.width, title_h) then
            -- if click on close btn (rightmost small square)
            local btnW = 18
            local close_x = self.x + self.width - (btnW + 4)
            if self.closable and is_point_in_rect(mx, my, close_x, self.y + 3, btnW, title_h - 6) then
                self:close()
                return true
            end
            local max_x = close_x - (btnW + 4)
            if self.maximizable and is_point_in_rect(mx, my, max_x, self.y + 3, btnW, title_h - 6) then
                self:maximize()
                return true
            end
            local min_x = max_x - (btnW + 4)
            if self.minimizable and is_point_in_rect(mx, my, min_x, self.y + 3, btnW, title_h - 6) then
                self:minimize()
                return true
            end

            -- start dragging
            if self.draggable then
                self.dragging = true
                self.drag_offx = mx - self.x
                self.drag_offy = my - self.y
                self:bringToFront()
                return true
            end
        end

        -- if click inside client area, forward to children (converted coords)
        if is_point_in_rect(mx, my, self.x, self.y + self.title_height, self.width, self.height - self.title_height) and not self.minimized then
            local lx, ly = self:to_local(mx, my)
            -- iterate children top-first
            for i = #self.children, 1, -1 do
                local child = self.children[i]
                if child.mousepressed then
                    -- child expects local client coords
                    local handled = child:mousepressed(lx, ly, button)
                    if handled then
                        self:bringToFront()
                        return true
                    end
                end
            end
            -- not handled, but clicking in window should bring to front
            self:bringToFront()
            return true
        end
        return false
    end

    function win:mousereleased(mx, my, button)
        if self.dragging then
            self.dragging = false
            return true
        end
        -- forward release to children
        if is_point_in_rect(mx, my, self.x, self.y + self.title_height, self.width, self.height - self.title_height) and not self.minimized then
            local lx, ly = self:to_local(mx, my)
            for i = #self.children, 1, -1 do
                local child = self.children[i]
                if child.mousereleased then
                    local handled = child:mousereleased(lx, ly, button)
                    if handled then return true end
                end
            end
        end
        return false
    end

    function win:update(dt)
        if self.dragging then
            local mx, my = keyboard.GetMousePosition()
            self.x = mx - self.drag_offx
            self.y = my - self.drag_offy
        end
        for _, c in ipairs(self.children) do
            if c.update then
                -- child update receives client-relative coordinates if needed
                pcall(c.update, c, dt)
            end
        end
    end

    function win:draw()
        if not self.visible then return end
        -- background
        local prev = {love.graphics.getColor()}
        -- window body
        love.graphics.setColor(self.color)
        love.graphics.rectangle("fill", self.x, self.y, self.width, self.height, 4)
        -- title bar
        love.graphics.setColor(self.title_color)
        love.graphics.rectangle("fill", self.x, self.y, self.width, self.title_height, 4,4)
        -- title text
        love.graphics.setColor(self.title_text_color)
        local font = love.graphics.getFont()
        love.graphics.setFont(font)
        love.graphics.print(self.title, self.x + 6, self.y + (self.title_height - font:getHeight())/2)
        -- control buttons
        local btnW = 18
        local gap = 4
        local cx = self.x + self.width - gap - btnW
        if self.closable then
            love.graphics.setColor(0.9,0.4,0.4)
            love.graphics.rectangle("fill", cx, self.y + 3, btnW, self.title_height - 6, 3)
            cx = cx - (btnW + gap)
        end
        if self.maximizable then
            love.graphics.setColor(0.4,0.9,0.4)
            love.graphics.rectangle("fill", cx, self.y + 3, btnW, self.title_height - 6, 3)
            cx = cx - (btnW + gap)
        end
        if self.minimizable then
            love.graphics.setColor(0.4,0.4,0.9)
            love.graphics.rectangle("fill", cx, self.y + 3, btnW, self.title_height - 6, 3)
            cx = cx - (btnW + gap)
        end

        -- draw children in client area (translate)
        if not self.minimized then
            love.graphics.setColor(prev)
            love.graphics.push()
            love.graphics.translate(self.x, self.y + self.title_height)
            -- optional scissor to client area
            local ok, sx, sy = pcall(love.graphics.intersectScissor, self.x, self.y + self.title_height, self.width, self.height - self.title_height)
            -- draw children
            for _, c in ipairs(self.children) do
                if c.draw then pcall(c.draw, c) end
            end
            love.graphics.pop()
        else
            restoreColor(prev)
        end

        love.graphics.setColor(prev)
    end

    table.insert(gui.windows, win)
    return win
end

-- -----------------------
-- Events & Update/Draw
-- -----------------------
-- We provide event handlers to be called from love callbacks or routed by user.

-- mousepressed: record pressed state; set dragging for sliders if clicked on handle
function gui.mousepressed(x, y, button)
    local x, y = keyboard.GetMousePosition()

    -- buttons: check topmost first
    for i = #gui.buttons, 1, -1 do
        local b = gui.buttons[i]
        if b.enabled and is_point_in_rect(x,y,b.x,b.y,b.width,b.height) then
            b.is_pressed = true
            b._pressed_inside = true
            b.color = b.colors.pressed
            -- we don't call callback here, call on release to avoid repeats
            -- bring to front for interaction
            gui.bringToFront(b)
            return
        end
    end

    -- sliders: detect click and start dragging
    for i = #gui.sliders, 1, -1 do
        local s = gui.sliders[i]
        if not s.disabled and is_point_in_rect(x,y,s.x,s.y,s.width,s.height) then
            s.dragging = true
            gui.bringToFront(s)
            -- update value immediately
            if s.orientation == "horizontal" then
                local ratio = (x - s.x) / (s.width)
                local newValue = s.min + ratio * (s.max - s.min)
                if s.step and s.step > 0 then
                    newValue = math.floor(newValue / s.step + 0.5) * s.step
                end
                newValue = clamp(newValue, s.min, s.max)
                if newValue ~= s.value then
                    s.value = newValue
                    if s.callback then s.callback(s.value) end
                end
            else
                local ratio = 1 - (y - s.y) / s.height
                local newValue = s.min + ratio * (s.max - s.min)
                if s.step and s.step > 0 then
                    newValue = math.floor(newValue / s.step + 0.5) * s.step
                end
                newValue = clamp(newValue, s.min, s.max)
                if newValue ~= s.value then
                    s.value = newValue
                    if s.callback then s.callback(s.value) end
                end
            end
            return
        end
    end

    -- text inputs: focus if clicked inside
    for i = #gui.text_inputs, 1, -1 do
        local ti = gui.text_inputs[i]
        if is_point_in_rect(x,y,ti.x,ti.y,ti.width,ti.height) then
            ti.is_focused = true
            gui._focused = ti
            gui.bringToFront(ti)
        else
            ti.is_focused = false
            if gui._focused == ti then gui._focused = nil end
        end
    end
end

function gui.mousereleased(x, y, button)
    local x, y = keyboard.GetMousePosition()

    -- buttons: if released inside and previously pressed -> fire callback
    for i = #gui.buttons, 1, -1 do
        local b = gui.buttons[i]
        if b._pressed_inside then
            b._pressed_inside = false
            b.is_pressed = false
            if b.enabled then
                if is_point_in_rect(x,y,b.x,b.y,b.width,b.height) then
                    -- click confirmed
                    if b.callback then pcall(b.callback, b) end
                end
                b.color = b.colors.normal
            else
                b.color = b.colors.disabled
            end
        end
    end

    -- sliders: stop dragging
    for _, s in ipairs(gui.sliders) do
        if s.dragging then
            s.dragging = false
        end
    end
end

function gui.textinput(text)
    local focused = gui._focused
    if focused and focused.is_focused then
        focused.text = focused.text .. text
        if focused.callback then pcall(focused.callback, focused.text) end
    end
end

function gui.keypressed(key)
    local focused = gui._focused
    if focused and focused.is_focused then
        if key == "backspace" then
            -- remove last unicode character safely
            local byteoffset = utf8.offset(focused.text, -1)
            if byteoffset then
                focused.text = string.sub(focused.text, 1, byteoffset-1)
            else
                focused.text = ""
            end
            if focused.callback then pcall(focused.callback, focused.text) end
        elseif key == "return" or key == "kpenter" then
            if focused.callback then pcall(focused.callback, focused.text, true) end
        end
    end
end

--- gui.update should be called from love.update(dt)
function gui.update(dt)
    local mx, my = keyboard.GetMousePosition()
    -- update hover states for buttons
    for _, b in ipairs(gui.buttons) do
        if not b.enabled then
            b.is_hovered = false
            b.color = b.colors.disabled
        else
            if is_point_in_rect(mx,my,b.x,b.y,b.width,b.height) then
                b.is_hovered = true
                if b._pressed_inside then
                    b.color = b.colors.pressed
                else
                    b.color = b.colors.hover
                end
            else
                b.is_hovered = false
                b.color = b.colors.normal
            end
        end
    end

    -- update dragging sliders
    for _, s in ipairs(gui.sliders) do
        if s.dragging and not s.disabled then
            local x = mx; local y = my
            if s.orientation == "horizontal" then
                local ratio = (x - s.x) / (s.width)
                local newValue = s.min + ratio * (s.max - s.min)
                if s.step and s.step > 0 then
                    newValue = math.floor(newValue / s.step + 0.5) * s.step
                end
                newValue = clamp(newValue, s.min, s.max)
                if newValue ~= s.value then
                    s.value = newValue
                    if s.callback then pcall(s.callback, s.value) end
                end
            else
                local ratio = 1 - (y - s.y) / s.height
                local newValue = s.min + ratio * (s.max - s.min)
                if s.step and s.step > 0 then
                    newValue = math.floor(newValue / s.step + 0.5) * s.step
                end
                newValue = clamp(newValue, s.min, s.max)
                if newValue ~= s.value then
                    s.value = newValue
                    if s.callback then pcall(s.callback, s.value) end
                end
            end
        end
    end
end

-- draw: draw in order: panels, texts, sliders, text_inputs, buttons, images (so buttons appear on top)
function gui.draw()
    -- panels (which include tables and menus)
    for _, panel in ipairs(gui.panels) do
        if panel.draw then pcall(panel.draw, panel) end
    end
    for _, t in ipairs(gui.texts) do pcall(t.draw, t) end
    for _, s in ipairs(gui.sliders) do pcall(s.draw, s) end
    for _, ti in ipairs(gui.text_inputs) do pcall(ti.draw, ti) end
    for _, b in ipairs(gui.buttons) do pcall(b.draw, b) end
end

-- -----------------------
-- Utility: add_menu (improved)
-- -----------------------
function gui.add_menu(x, y, w, h, items, functions)
    local menu = {
        x = x, y = y, width = w, height = h,
        items = items or {},
        active = false,
        itembuttons = {}
    }

    -- create toggle button
    local toggle = gui.add_button_roundrect(x, y, w, h, 4, "", function()
        menu.active = not menu.active
        if menu.active then
            -- create item buttons below toggle
            for i, item in ipairs(menu.items) do
                local btn = gui.add_button_rect(x, y + i * (h + 5), w - 5, h, item,
                    functions and functions[i] or function() end)
                table.insert(menu.itembuttons, btn)
            end
        else
            -- remove item buttons
            for _, btn in ipairs(menu.itembuttons) do gui.remove(btn) end
            menu.itembuttons = {}
        end
    end)
    table.insert(gui.panels, menu)
    return menu
end

-- expose allowed API list for user convenience
gui.api = {
    create_button_rect = gui.add_button_rect,
    create_button_roundrect = gui.add_button_roundrect,
    create_button_ellipse = gui.add_button_ellipse,
    create_button_image = gui.add_button_image,
    add_text = gui.add_text,
    add_slider = gui.add_slider,
    add_text_input = gui.add_text_input,
    add_table = gui.add_table,
    add_menu = gui.add_menu,
    clear = gui.clear,
    remove = gui.remove,
    bringToFront = gui.bringToFront,
    update = gui.update,
    draw = gui.draw,
    mousepressed = gui.mousepressed,
    mousereleased = gui.mousereleased,
    textinput = gui.textinput,
    keypressed = gui.keypressed,
}

return gui