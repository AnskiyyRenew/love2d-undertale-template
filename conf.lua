-- Soul Engine configuration file.
-- These globals are read by main.lua and by the engine at startup.
-- Engine version string.
-- Printed on startup and shown on the error screen.
_VER = "3.0.2-stable"

-- Release switch: false keeps the console, the debug libraries and the F5/F6/F8
-- hotkeys; set it to true before exporting a public build.
_RELEASED = false

-- Game metadata: TITLE is the window title, VERSION is the game's own version
-- (_VER above is the engine's); AUTHOR, CONTACT and WEBSITE show on the error screen.
_INFO = {
    TITLE = "Soul Engine - v3.0.2",
    VERSION = "0.0.0",
    AUTHOR = "end",
    CONTACT = "NaN",
    WEBSITE = "NaN",
}

-- Nominal game resolution; also the window size when BORDER_MODE is off.
-- Gameplay code should assume this size regardless of how the window is scaled.
LOGICAL_WIDTH, LOGICAL_HEIGHT = 640, 480

-- Size of the canvas the whole game renders into.
-- Keep 640x480 unless the game is redesigned around another resolution.
CANVAS_WIDTH, CANVAS_HEIGHT = 640, 480

-- Window size when BORDER_MODE is on: the 16:9 frame around the canvas.
-- The border art is scaled to this size and the canvas sits in its opening.
BORDER_WIDTH, BORDER_HEIGHT = 960, 540

-- How the canvas is scaled into the window: "integer" for pixel-perfect steps,
-- "auto" to fill, a number for a fixed multiple, false for 1:1.
SCREEN_SCALE = "auto"

-- Legacy switch, read only when SCREEN_SCALE is nil.
-- true behaves like "auto", false like a fixed 1:1 scale.
FILL_SCREEN = true

-- Draw the bordered frame (outer window plus the opening the game is seen through).
-- false draws the canvas straight into the window with a thin outline instead.
BORDER_MODE = true

-- Use the custom error screen at the bottom of this file instead of LOVE's own.
-- false returns early, so the errorhandler below is never defined.
USE_ERRHANDLER = true

function love.conf(t)
    t.identity = nil                     -- nil: keep LOVE's default save folder, existing saves stay put
    t.appendidentity = false             -- false: identity is the folder name as-is, not appended
    t.version = "12.0"                   -- LOVE version the game is written against
    t.console = not _RELEASED            -- dev console on Windows; off in release builds
    t.accelerometerjoystick = true       -- phone tilt reports as a joystick axis
    t.externalstorage = false            -- Android: keep saves in internal storage, not the SD card
    t.graphics.gammacorrect = false      -- linear-gamma rendering off, keeps pixel colours exact

    t.audio.mic = false                  -- never request microphone permission
    t.audio.mixwithsystem = false        -- Android: do not share the audio device with other apps

    t.window.title = _INFO.TITLE         -- caption taken from the metadata at the top of this file
    t.window.icon = "icon.png"           -- taskbar / dock icon
    -- Initial window size: the border frame when BORDER_MODE is on, the bare canvas when off.
    -- main.lua re-derives the scale and offset from whatever size the window actually gets.
    t.window.width = BORDER_MODE and BORDER_WIDTH or LOGICAL_WIDTH
    t.window.height = BORDER_MODE and BORDER_HEIGHT or LOGICAL_HEIGHT
    t.window.borderless = false          -- keep the OS title bar and frame
    t.window.resizable = false           -- fixed size; scaling is the canvas's job
    -- Minimum size the window manager accepts; unused while resizable is false.
    t.window.minwidth = 1
    t.window.minheight = 1
    t.window.fullscreen = false          -- start windowed; F4 toggles fullscreen at runtime
    t.window.fullscreentype = "desktop"  -- borderless desktop fullscreen, not exclusive
    t.window.vsync = 0                   -- off; main.lua's frame limiter owns the pacing
    t.window.msaa = 0                    -- no multisampling; the canvas is upscaled with nearest filtering
    -- Depth and stencil stay at LOVE's default: the game's canvases request a stencil
    -- buffer themselves in main.lua, and the window backbuffer needs neither.
    t.window.depth = nil
    t.window.stencil = nil
    t.window.displayindex = 1            -- always open on the primary monitor
    t.highdpi = false                    -- treat every display as 1x
    t.window.usedpiscale = false         -- no automatic DPI scaling (LOVE 12)
    t.window.dpiscale = 1                -- explicit 1x scale, same reason
    t.window.x = nil                     -- nil: let the window manager place the window
    t.window.y = nil                     -- same, vertical axis

    -- Every module the engine relies on is enabled. Setting one to false removes
    -- its whole API, so only do that for a build known not to need it.
    t.modules.audio = true               -- love.audio: sources and playback
    t.modules.data = true                -- love.data: encode/decode, hashing, compression
    t.modules.event = true               -- love.event: the main loop's event queue
    t.modules.font = true                -- love.font: rasterizers behind Fonts and Typers
    t.modules.graphics = true            -- love.graphics: canvases, shaders, drawing
    t.modules.image = true               -- love.image: ImageData and image decoding
    t.modules.joystick = true            -- love.joystick: gamepad detection and input
    t.modules.keyboard = true            -- love.keyboard: key states and text input
    t.modules.math = true                -- love.math: random, noise and Transform
    t.modules.mouse = true               -- love.mouse: cursor position, buttons and wheel
    t.modules.physics = true             -- love.physics: Box2D worlds, bodies and shapes
    t.modules.sound = true               -- love.sound: SoundData decoding for short effects
    t.modules.system = true              -- love.system: OS name, clipboard, openURL
    t.modules.thread = true              -- love.thread: Channels and Threads
    t.modules.timer = true               -- love.timer: dt and sleep, used by the frame limiter
    t.modules.touch = true               -- love.touch: multitouch on mobile
    t.modules.video = true               -- love.video: Theora video playback
    t.modules.window = true              -- love.window: owns the window; graphics depends on it
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
