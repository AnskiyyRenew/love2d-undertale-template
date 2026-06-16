local SCENE = {}

local CANVAS_W, CANVAS_H = 640, 480
local INITIAL_COUNT = 200
local SPAWN_PER_CLICK = 5

local fps_text
local count_text
local sprites_data = {}
local total_time = 0
local layer_counter = 0
local mouse_held = false
local mouse_wx, mouse_wy = 0, 0

local function create_sprite_data(x, y)
    layer_counter = layer_counter + 1
    local spr = sprites.CreateSprite("bullet.png", layer_counter)
    spr.x = x or math.random() * CANVAS_W
    spr.y = y or math.random() * CANVAS_H
    spr.color = {
        math.random() * 0.7 + 0.3,
        math.random() * 0.7 + 0.3,
        math.random() * 0.7 + 0.3,
    }
    spr.xscale = math.random() * 4 + 1
    spr.yscale = spr.xscale

    return {
        sprite = spr,
        rot_speed = (math.random() * 240 - 120) * math.pi / 180,
        move_angle = math.random() * math.pi * 2,
        move_speed = math.random() * 60 + 20,
        base_scale = spr.xscale,
        scale_amp = math.random() * 2,
        scale_freq = math.random() * 1.5 + 0.5,
        phase = math.random() * math.pi * 2,
    }
end

function SCENE.load()
    sprites_data = {}
    total_time = 0

    for _ = 1, INITIAL_COUNT do
        sprites_data[#sprites_data + 1] = create_sprite_data()
    end

    fps_text = typers.DrawText("FPS: --", { 4, 4 }, 999999)
    count_text = typers.DrawText("Sprites: 0", { 4, 20 }, 999999)
end

function SCENE.update(dt)
    total_time = total_time + dt

    for _, data in ipairs(sprites_data) do
        local s = data.sprite

        s.rotation = s.rotation + data.rot_speed * dt

        local move_x = math.cos(data.move_angle) * data.move_speed * dt
        local move_y = math.sin(data.move_angle) * data.move_speed * dt
        s.x = (s.x + move_x) % CANVAS_W
        s.y = (s.y + move_y) % CANVAS_H

        local sval = math.sin(total_time * data.scale_freq + data.phase)
        local scale = data.base_scale + data.scale_amp * sval
        s.xscale = scale
        s.yscale = scale
    end

    if mouse_held then
        for _ = 1, SPAWN_PER_CLICK do
            sprites_data[#sprites_data + 1] = create_sprite_data(
                mouse_wx + (math.random() - 0.5) * 60,
                mouse_wy + (math.random() - 0.5) * 60
            )
        end
    end

    fps_text:SetText(string.format("FPS: %d", love.timer.getFPS()))
    count_text:SetText(string.format("Sprites: %d", #sprites_data))
end

function SCENE.draw()
end

function SCENE.mousepressed(x, y, button)
    if button ~= 1 then return end
    mouse_held = true
    mouse_wx = (x - draw_x) / scale + _CAMERA_.x
    mouse_wy = (y - draw_y) / scale + _CAMERA_.y
end

function SCENE.mousereleased(x, y, button)
    if button ~= 1 then return end
    mouse_held = false
end

function SCENE.clear()
    layers.clear()
end

return SCENE
