-- Soul Engine Configuration File
_VER = "3.0.0-stable"

-- Set to true when building the game for release
_RELEASED = false

-- The game's information
_INFO = {
    TITLE = "Soul Engine - v3.0.0",
    VERSION = "0.0.0", -- THIS IS YOUR GAME'S VERSION, the "_VER" upon means the engine's version.
    AUTHOR = "end",
    CONTACT = "NaN",
    WEBSITE = "NaN",
}

-- This is your window size. Change these values to set your desired resolution.
-- The Border art is authored for a 960x540 window: a 640x480 game screen with a
-- 160/160/30/30 decorative frame around it (see Resources/Sprites/Border).
LOGICAL_WIDTH, LOGICAL_HEIGHT = 640, 480
CANVAS_WIDTH, CANVAS_HEIGHT = 640, 480

-- How much the GAME SCREEN (the CANVAS_WIDTH x CANVAS_HEIGHT canvas) is scaled.
-- It is ALWAYS kept dead-centre, and the Border frame is locked to it, so the
-- frame's opening can never drift away from the game screen:
--     "integer" → whole-number scaling (pixel-perfect; the frame fits exactly
--                 when the window is canvas + margins, e.g. 960x540 → 1x or
--                 1920x1080 → 2x). Shrinks proportionally for smaller windows.
--     "auto"    → fill as much of the window / screen as possible (fractional)
--     false/nil → 1:1, no scaling
SCREEN_SCALE = "integer"

-- Legacy switch, only used when SCREEN_SCALE is nil: true = "auto" while
-- fullscreen and 1:1 otherwise. Prefer SCREEN_SCALE.
FILL_SCREEN = true

-- Enable error handler to show custom error screen
-- If you don't know which error crashed the game. Then you need to set it to false.
USE_ERRHANDLER = true

function love.conf(t)
    t.identity = nil                    -- The name of the save directory (string)
    t.appendidentity = false            -- Search for files in the source directory before the save directory (boolean)
    t.version = "12.0"                  -- The LÖVE version this game was made for (string)
    t.console = not _RELEASED           -- Attach a console (boolean, Windows only)
    t.accelerometerjoystick = true      -- Expose the accelerometer as a Joystick to enable it on iOS and Android (boolean)
    t.externalstorage = false           -- Save files to (and read them from) external storage on Android (boolean)
    t.graphics.gammacorrect = false              -- Enable gamma-correct rendering when the system supports it (boolean)

    t.audio.mic = false                 -- Request and use the microphone on Android (boolean)
    t.audio.mixwithsystem = false       -- Keep background music playing while LÖVE is open (boolean, iOS and Android only)

    t.window.title = _INFO.TITLE        -- The window title (string)
    t.window.icon = "icon.png"          -- File path to the image used as the window icon (string)
    t.window.width = LOGICAL_WIDTH      -- The window width (number)
    t.window.height = LOGICAL_HEIGHT    -- The window height (number)
    t.window.borderless = false         -- Remove the window border (boolean)
    t.window.resizable = false          -- Let the user resize the window (boolean)
    t.window.minwidth = 1               -- Minimum window width, if the window is resizable (number)
    t.window.minheight = 1              -- Minimum window height, if the window is resizable (number)
    t.window.fullscreen = false         -- Enable fullscreen (boolean)
    t.window.fullscreentype = "desktop" -- Choose "desktop" or "exclusive" fullscreen mode (string)
    t.window.vsync = 0                  -- Vertical sync mode (number)
    t.window.msaa = 0                   -- Number of samples to use for multisample anti-aliasing (number)
    t.window.depth = nil                -- Number of bits per sample in the depth buffer
    t.window.stencil = nil              -- Number of bits per sample in the stencil buffer
    t.window.displayindex = 1                -- Index of the monitor the window is displayed on (number)
    t.highdpi = false            -- Enable high DPI mode on Retina displays (boolean)
    t.window.usedpiscale = false         -- Enable automatic DPI scaling when highdpi is set to true (boolean)
    t.window.dpiscale = 1
    t.window.x = nil                    -- The x-coordinate position of the window in the given display (number)
    t.window.y = nil                    -- The y-coordinate position of the window in the given display (number)

    t.modules.audio = true              -- Enable the audio module (boolean)
    t.modules.data = true               -- Enable the data module (boolean)
    t.modules.event = true              -- Enable the event module (boolean)
    t.modules.font = true               -- Enable the font module (boolean)
    t.modules.graphics = true           -- Enable the graphics module (boolean)
    t.modules.image = true              -- Enable the image module (boolean)
    t.modules.joystick = true           -- Enable the joystick module (boolean)
    t.modules.keyboard = true           -- Enable the keyboard module (boolean)
    t.modules.math = true               -- Enable the math module (boolean)
    t.modules.mouse = true              -- Enable the mouse module (boolean)
    t.modules.physics = true            -- Enable the physics module (boolean)
    t.modules.sound = true              -- Enable the sound module (boolean)
    t.modules.system = true             -- Enable the system module (boolean)
    t.modules.thread = true             -- Enable the thread module (boolean)
    t.modules.timer = true              -- Enable the timer module (boolean); disabling it makes the delta time in love.update 0
    t.modules.touch = true              -- Enable the touch module (boolean)
    t.modules.video = true              -- Enable the video module (boolean)
    t.modules.window = true             -- Enable the window module (boolean)
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

            -- The dog sprite is loaded lazily here, NOT during conf.lua load time:
            -- love.graphics is nil while conf.lua runs (modules load afterwards),
            -- so loading it there used to crash conf.lua before love.errorhandler
            -- could even be defined.
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