local scene = {}

function scene.load()
end

---@param dt number|nil Delta time since last update.
function scene.update(dt)
end

function scene.draw()
end

function scene.clear()
end

function scene.quit()
    print("SE.quit: Game is quitting... Goodbye!")
end

---@param key string The key name (e.g., "escape", "a").
---@param scancode string The scancode of the key.
---@param isrepeat boolean True if this is a repeated key event.
function scene.keypressed(key, scancode, isrepeat)
    if key == "escape" then
        SE.event.quit()
    end
    print("SE.keypressed: Key '" .. key .. "' pressed")
end

---@param key string The key name.
---@param scancode string The scancode of the key.
function scene.keyreleased(key, scancode)
    print("SE.keyreleased: Key '" .. key .. "' released")
end

---@param text string The input text.
function scene.textinput(text)
    print("SE.textinput: Text input received: " .. text)
end

---@param x number X coordinate of the mouse.
---@param y number Y coordinate of the mouse.
---@param button number The button number (1 = left, 2 = right, etc.).
---@param istouch boolean True if the event came from a touchscreen.
---@param presses number Number of presses in a row (for double-click detection).
function scene.mousepressed(x, y, button, istouch, presses)
    print(string.format("SE.mousepressed: Button %d pressed at (%d, %d)", button, x, y))
end

---@param x number X coordinate of the mouse.
---@param y number Y coordinate of the mouse.
---@param button number The button number.
---@param istouch boolean True if the event came from a touchscreen.
---@param presses number Number of presses in a row.
function scene.mousereleased(x, y, button, istouch, presses)
    print(string.format("SE.mousereleased: Button %d released at (%d, %d)", button, x, y))
end

---@param x number Current X coordinate.
---@param y number Current Y coordinate.
---@param dx number Change in X since last frame.
---@param dy number Change in Y since last frame.
---@param istouch boolean True if the event came from a touchscreen.
function scene.mousemoved(x, y, dx, dy, istouch)
end

---@param x number Horizontal scroll amount.
---@param y number Vertical scroll amount.
function scene.wheelmoved(x, y)
    print(string.format("SE.wheelmoved: Scrolled dx=%.1f, dy=%.1f", x, y))
end

---@param f boolean True if the window gained focus, false if it lost focus.
function scene.focus(f)
    if f then
        print("SE.focus: Window gained focus")
    else
        print("SE.focus: Window lost focus")
    end
end

---@param w number New window width.
---@param h number New window height.
function scene.resize(w, h)
    print(string.format("SE.resize: Window resized to %dx%d", w, h))
end

---@param v boolean True if the window is visible.
function scene.visible(v)
    if v then
        print("SE.visible: Window is now visible")
    else
        print("SE.visible: Window is now hidden")
    end
end

---@param file SE.File The dropped file object.
function scene.filedropped(file)
end

---@param dir SE.File The dropped directory object (also a SE.File).
function scene.directorydropped(dir)
end

return scene
