local scene = {}

local font = Fonts.New("determination_mono.ttf", 13, "mono")
font:setFilter("nearest", "nearest")

local time = 0
--- Accumulates elapsed time for the locked error screen.
---@param dt number Delta time in seconds.
function scene.update(dt)
    time = time + dt
end

--- Prints the name of the failed scene and up to ten lines of the error text.
---@param err any The error object or message raised by the failed load.
---@param failedScene string|nil Identifier of the scene that failed to load.
local function drawErrorInfo(err, failedScene)
    if not err then return end
    local maxLines = 10
    local y = 120
    SE.graphics.setFont(font)
    SE.graphics.setColor(1, 1, 1)
    SE.graphics.print("Error loading scene: " .. tostring(failedScene or "?"), 40, y)
    y = y + 26

    for line in tostring(err):gmatch("([^\r\n]+)") do
        SE.graphics.setColor(1, 0.4, 0.4)
        SE.graphics.print(line, 40, y)
        y = y + 18
        maxLines = maxLines - 1
        if maxLines <= 0 then break end
    end
    SE.graphics.setColor(1, 1, 1)
end

--- Renders the fallback error screen with the details of the failed load.
function scene.draw()
    SE.graphics.setFont(font)
    SE.graphics.setColor(1, 1, 1)
    SE.graphics.print("Woops, you shouldn't be here", 40, 40)

    SE.graphics.setColor(1, 0, 0)
    SE.graphics.print("AN ERROR OCCURRED", 40, 72)

    drawErrorInfo(scene._load_error or (Scenes and Scenes.last_load_error), scene._failed_scene or (Scenes and Scenes.last_failed_scene))
end

--- Removes every layer belonging to this scene.
function scene.clear()
    Layers.clear()
end

return scene