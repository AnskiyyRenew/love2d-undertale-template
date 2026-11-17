-- Soul Engine Configuration File
_VER = "3.0.2-stable"

-- Set to true when building the game for release
_RELEASED = false

_INFO = {
    TITLE = "Soul Engine - v3.0.2",
    VERSION = "0.0.0", -- your game's version (_VER above is the engine's)
    AUTHOR = "end",
    CONTACT = "NaN",
    WEBSITE = "NaN",
}

-- Game screen size. The Border art is authored for 960x540: a 640x480 game
-- screen with a 160/160/30/30 decorative frame around it.
LOGICAL_WIDTH, LOGICAL_HEIGHT = 640, 480
CANVAS_WIDTH, CANVAS_HEIGHT = 640, 480

-- Border art native size; its inner opening is the canvas centred inside it.
BORDER_WIDTH, BORDER_HEIGHT = 960, 540

-- How the game canvas is scaled. It is always dead-centre and the Border frame
-- is locked to it, so the opening can never drift away from the game screen.
--   "integer" -> whole-number scale (pixel-perfect, shrinks for small windows)
--   "auto"    -> fill as much of the window / screen as possible
--   false/nil -> 1:1, no scaling
SCREEN_SCALE = "auto"

-- Legacy switch, only used when SCREEN_SCALE is nil.
FILL_SCREEN = true

-- true: fit the Border art to the window and drop the canvas into its inner
-- opening (same scale, top-left locked). false: fit the canvas alone and draw
-- no frame. Only applies when SCREEN_SCALE is "auto" / true / "integer".
BORDER_MODE = false

-- Custom error screen; set false to see the raw LÖVE error instead.
USE_ERRHANDLER = true

function love.conf(t)
    t.identity = nil
    t.appendidentity = false
    t.version = "12.0"
    t.console = not _RELEASED
    t.accelerometerjoystick = true
    t.externalstorage = false
    t.graphics.gammacorrect = false

    t.audio.mic = false
    t.audio.mixwithsystem = false

    t.window.title = _INFO.TITLE
    t.window.icon = "icon.png"
    -- Border size when BORDER_MODE is on (the frame fits 1:1 at startup),
    -- otherwise the canvas size (game screen with no frame around it).
    t.window.width = BORDER_MODE and BORDER_WIDTH or LOGICAL_WIDTH
    t.window.height = BORDER_MODE and BORDER_HEIGHT or LOGICAL_HEIGHT
    t.window.borderless = false
    t.window.resizable = false
    t.window.minwidth = 1
    t.window.minheight = 1
    t.window.fullscreen = false
    t.window.fullscreentype = "desktop"
    t.window.vsync = 0
    t.window.msaa = 0                   -- keep 0 on mobile: 4x costs too much fill rate
    t.window.depth = nil
    t.window.stencil = nil
    t.window.displayindex = 1
    t.highdpi = false
    t.window.usedpiscale = false
    t.window.dpiscale = 1
    t.window.x = nil
    t.window.y = nil

    t.modules.audio = true
    t.modules.data = true
    t.modules.event = true
    t.modules.font = true
    t.modules.graphics = true
    t.modules.image = true
    t.modules.joystick = true
    t.modules.keyboard = true
    t.modules.math = true
    t.modules.mouse = true
    t.modules.physics = true
    t.modules.sound = true
    t.modules.system = true
    t.modules.thread = true
    t.modules.timer = true              -- disabling it makes the dt in love.update 0
    t.modules.touch = true
    t.modules.video = true
    t.modules.window = true
end

if (not USE_ERRHANDLER) then
    return
end

local dogangle = 0
local tdog = nil
local dogs = {
    "spr_tinypombark_0", "spr_tinypomjump_0", "spr_tinypomsad_0", "spr_tinypomsadbark_0", "spr_tinypomwag_0",
    "spr_tinypomwag_1", "spr_tinypomwalk_0", "spr_tinypomwalk_1"
}
local smallFont, mainFont

function love.errorhandler(msg)

    love.audio.stop()

    msg = tostring(msg)
    local major, minor, revision = love.getVersion()
    local version_num = major * 10000 + minor * 100 + revision
    local debugInfo = {
        LOVEversion = version_num,
        system = love.system.getOS(),
        time = os.date("%Y-%m-%d %H:%M:%S"),
        version = _VER .. " - " .. _INFO.VERSION,
        memory = string.format("%.2f MB", collectgarbage("count") / 1024),
        renderer = love.graphics.getRendererInfo()
    }

    local debugStr = "\n\n\n"
    for k, v in pairs(debugInfo) do
        debugStr = debugStr .. string.format("%s: %s\n", k, tostring(v))
    end

    debugStr = debugStr .. "\n"
    debugStr = debugStr .. _INFO.TITLE .. " Information:\n"
    debugStr = debugStr .. "Version: \t" .. _INFO.VERSION .. "\n"
    debugStr = debugStr .. "Author: \t" .. _INFO.AUTHOR .. "\n"
    debugStr = debugStr .. "Contact: \t" .. _INFO.CONTACT .. "\n"
    debugStr = debugStr .. "Website: \t" .. _INFO.WEBSITE .. "\n"

    local fullError = "Fatal Error\n\n" ..
                      "Error:\n" .. msg ..
                      debugStr

    print(fullError)

    return function()
        local shouldExit = false

        love.event.pump()
        for e, a, b, c in (love.event.poll()) do
            if (e == "quit") then
                shouldExit = true
            end
        end

        if (love.keyboard.isDown("lctrl", "rctrl") and love.keyboard.isDown("c")) then
            love.system.setClipboardText(fullError)
        end

        if (love.graphics and love.graphics.isActive()) then
            dogangle = dogangle + 0.01
            love.graphics.reset()
            love.graphics.setColor(1, 1, 1)
            love.graphics.clear(0.15, 0.1, 0.15)

            -- Loaded lazily: love.graphics is nil while conf.lua runs, so the
            -- sprite can only be created here.
            if (not tdog) then
                local dogFile = "Resources/Sprites/Attacks/Dogs/" .. dogs[math.random(#dogs)] .. ".png"
                local ok, img = pcall(love.graphics.newImage, dogFile)
                if (ok) then
                    tdog = img
                    tdog:setFilter("nearest", "nearest")
                end
            end

            if (not smallFont) then
                smallFont = love.graphics.newFont("Resources/Fonts/determination_mono.ttf", 13, "mono")
                mainFont = love.graphics.newFont("Resources/Fonts/determination_mono.ttf", 20, "mono")
                smallFont:setFilter("nearest", "nearest")
                mainFont:setFilter("nearest", "nearest")
            end

            love.graphics.setColor(1, 1, 1, 1)
            if (tdog) then
                love.graphics.draw(tdog, 200, 40, math.rad(dogangle), 1, 1, 54 / 2, 38 / 2)
            end

            love.graphics.setFont(mainFont)
            love.graphics.setColor(1, 0.3, 0.3)
            love.graphics.print("Fatal Error", 30, 30)

            love.graphics.setColor(0.8, 0.2, 0.2)
            love.graphics.line(30, 70, love.graphics.getWidth() - 30, 70)

            love.graphics.setColor(1, 0.6, 0.6)
            love.graphics.setFont(smallFont)
            love.graphics.printf("Error:\n"..msg, 30, 85, love.graphics.getWidth() - 60)

            love.graphics.setColor(0.6, 0.8, 1)
            love.graphics.printf(debugStr, 30, 220, love.graphics.getWidth() - 60, "right")

            love.graphics.setColor(0.5, 0.8, 0.5)
            love.graphics.printf("Press ALT+F4 quit the game", 30, 45, love.graphics.getWidth() - 60, "right")

            love.graphics.setColor(0.8, 0.8, 0.5)
            love.graphics.printf("Press CTRL+C to copy the message", 30, 25, love.graphics.getWidth() - 60, "right")

            love.graphics.present()
        end

        return shouldExit
    end
end