-- 旋转像素画测试：先放大到 Canvas，再缩小显示以减少锯齿
local pixelArt = nil
local superCanvas = nil
local angle = 0

function love.load()
    love.window.setMode(640, 480, {resizable = true})
    love.graphics.setDefaultFilter("nearest", "nearest")

    local imageData = love.image.newImageData(16, 16)
    for y = 0, 15 do
        for x = 0, 15 do
            if ((x + y) % 2 == 0) then
                imageData:setPixel(x, y, 1, 0.5, 0, 1)
            else
                imageData:setPixel(x, y, 0, 0.8, 1, 1)
            end
        end
    end

    pixelArt = love.graphics.newImage(imageData)
    pixelArt:setFilter("nearest", "nearest")

    superCanvas = love.graphics.newCanvas(64, 64)
    superCanvas:setFilter("linear", "linear")
end

function love.update(dt)
    angle = angle + dt * 0.8
end

function love.draw()
    love.graphics.clear(0.08, 0.08, 0.1)

    -- 先把像素画放大到 Canvas
    love.graphics.setCanvas(superCanvas)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.draw(pixelArt, 0, 0, 0, 4, 4)
    love.graphics.setCanvas()

    -- 用 linear 缩小并旋转显示
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(superCanvas, 360, 240, angle, 2, 2, 32, 32)

    -- 对比：直接用 pixelArt 旋转（可见锯齿）
    love.graphics.draw(pixelArt, 140, 240, angle, 8, 8, 8, 8)

    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Canvas -> linear filter for rotated pixel art", 10, 10)
    love.graphics.print("Direct pixelArt rotation (nearest filter)", 10, 30)
    love.graphics.print("SuperCanvas rotation + shrink (linear filter)", 10, 50)
end
