-- Game-side configuration, layered over the engine's conf_pure.lua. Keys set
-- here win; anything missing keeps the engine default.
-- Entry scenes: FirstRoom is entered on launch, F2Room after an F2 reload
-- (F2 also reloads localization and the game config).
Global.SetVariable("FirstRoom", "scene_logo")
Global.SetVariable("F2Room", "scene_logo")

-- Visuals: MainColor tints cursors, typer text, battle UI, the game over screen
-- and the borderless outline; EnableFriskDance unlocks the Overworld easter egg
-- triggered by pressing up+down against a wall.
Global.SetVariable("MainColor", {1, 1, 1})
Global.SetVariable("EnableFriskDance", false)

-- Localization directory key handed to Localize.setFile; last assignment wins.
Global.SetVariable("Language", "en")
Global.SetVariable("Language", "zh_CN")

-- Timing: true makes souls integrate wall-clock time, so frame stutter does not
-- slow them down. The key literally contains "(dt)" - keep it verbatim.
Global.SetVariable("UseRealTime(dt)", false)

-- Rendering: ScreenShaders is a list of shaders run over the canvas every frame
-- (empty means none); FPS caps the software frame limiter in main.lua.
Global.SetVariable("ScreenShaders", {})
Global.SetVariable("FPS", 60)

-- Audio: three independent channels, each in 0..1.
Global.SetVariable("Volume", {
    Master = 1,
    Music  = 1,
    Sounds = 1
})

-- Controllers: simulation fakes a virtual keyboard or a gamepad for testing;
-- deadzone is the stick deflection below which input counts as zero.
Global.SetVariable("ControllerSimulation", {
    virtualKeyboard = false,
    joystick        = false,
})

Global.SetVariable("ControllerDeadzone", 0.15)

-- Online services: GameJolt credentials (nil leaves the API disabled) and the
-- Discord Rich Presence application id.
Global.SetVariable("GamejoltID", nil)
Global.SetVariable("GamejoltPK", nil)
Global.SetVariable("DiscordAppID", "1342517648348680202")

-- Memory safety. Sprites warns at OPT_COUNT_SPRITES instances and refuses to
-- create past twice that; OPT_COUNT_TYPERS caps live typers. OPT_LRU_SPRITES is
-- {enabled, idle_seconds} for texture cache reclaim, and OPT_MEMORY_MAXSIZE is
-- stored for Guard but no check reads it yet. Guard loads last: it reads these.
Global.SetVariable("SE_MEMORY_SAFETY", true)
Global.SetVariable("OPT_COUNT_SPRITES", 2000)
Global.SetVariable("OPT_COUNT_TYPERS", 300)
Global.SetVariable("OPT_MEMORY_MAXSIZE", 0.8)
Global.SetVariable("OPT_LRU_SPRITES", {false, 180})
Guard = ImportFile("Engine.MemorySafety")
