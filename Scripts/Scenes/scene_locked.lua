local scene = {}

local font = SE.graphics.newFont("Resources/Fonts/determination_mono.ttf", 13, "mono")
font:setFilter("nearest", "nearest")

local time = 0
function scene.update(dt)
    time = time + dt
end

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

function scene.draw()
    SE.graphics.setFont(font)
    SE.graphics.setColor(1, 1, 1)
    SE.graphics.print("Woops, you shouldn't be here", 40, 40)

    SE.graphics.setColor(1, 0, 0)
    SE.graphics.print("AN ERROR OCCURRED", 40, 72)

    -- Draw detailed error info if present
    drawErrorInfo(scene._load_error or (Scenes and Scenes.last_load_error), scene._failed_scene or (Scenes and Scenes.last_failed_scene))
end

function scene.clear()
    Layers.clear()
end

return scene