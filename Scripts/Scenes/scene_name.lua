local scene = {}

local font = SE.graphics.newFont("Resources/Fonts/determination_mono.ttf", 27, "mono")
local name_str = "AAAAAA"
local alphabets = {}
local positions = {}
local shakers = {}

local selecting = 1
local x, y = 140, 160
for i = 1, 26
do
    table.insert(alphabets, string.char(64 + i))
    table.insert(positions, {x, y})
    table.insert(shakers, {0, 0})

    x = x + 57
    if (i % 7 == 0) then
        x = 140
        y = y + 30
    end
end
x = 140
y = y + 30
for i = 1, 26
do
    table.insert(alphabets, string.char(96 + i))
    table.insert(positions, {x, y})
    table.insert(shakers, {0, 0})

    x = x + 57
    if (i % 7 == 0) then
        x = 140
        y = y + 30
    end
end

Layers.add_external(function ()
    SE.graphics.setFont(font)
    SE.graphics.printf("Name the fallen human", 0, 40, 640, "center")
end, 0)
Layers.add_external(function ()
    SE.graphics.setFont(font)
    SE.graphics.printf(name_str, 0, 100, 640, "center")
end)
Layers.add_external(function ()
    SE.graphics.setFont(font)
    for i = 1, #alphabets
    do
        local letter = alphabets[i]
        local pos    = positions[i]
        local shaker = shakers[i]

        SE.graphics.setColor(1, 1, 1)
        if (selecting == i) then
            SE.graphics.setColor(1, 1, 0)
        end
        SE.graphics.print(letter, pos[1] + shaker[1], pos[2] + shaker[2])
    end
end)

function scene.update(dt)
    -- Shake
    for i = 1, #shakers
    do
        shakers[i] = {
            math.random(-1, 1),
            math.random(-1, 1)
        }
    end

    -- Logic
    local left  = (Controller.GetState("left") == 1)
    local right = (Controller.GetState("right") == 1)
    local up    = (Controller.GetState("up") == 1)
    local down  = (Controller.GetState("down") == 1)
    if (right) then
        selecting = math.min(#alphabets, selecting + 1)
    elseif (left) then
        selecting = math.max(1, selecting - 1)
    elseif (up) then
        if (selecting >= 27 and selecting <= 33) then
            selecting = selecting + 2
        end
        selecting = math.max(1, selecting - 7)
    elseif (down) then
        if (selecting >= 22 and selecting <= 26) then
            selecting = selecting - 2
        end
        selecting = math.min(#alphabets, selecting + 7)
    end
end

function scene.draw()
end

function scene.clear()
    Layers.clear()
end

return scene