Global.SetVariable("FirstRoom", "Overworld.scene_ow_main_0")
Global.SetVariable("FirstRoom", "scene_logo")
Global.SetVariable("FirstRoom", "Battle.scene_battle_init")
Global.SetVariable("MainColor", {1, 1, 1})
Global.SetVariable("EnableFriskDance", false)
Global.SetVariable("Language", "en")
Global.SetVariable("Language", "zh_CN")
Global.SetVariable("UseRealTime(dt)", false)
Global.SetVariable("ScreenShaders", {})
Global.SetVariable("FPS", 60)
Global.SetVariable("F2Room", "scene_logo")
Global.SetVariable("Volume", {
    Master = 1,
    Music  = 1,
    Sounds = 1
})

-- Simulate the virtual keyboard / gamepad on desktop; both default off.
Global.SetVariable("ControllerSimulation", {
    virtualKeyboard = false,
    joystick        = false,
})

-- Analog stick dead-zone (0..1). Higher tolerates drift but loses precision
-- (0.10 sensitive, 0.15 default, 0.20 tolerant).
Global.SetVariable("ControllerDeadzone", 0.15)

Global.SetVariable("GamejoltID", nil)
Global.SetVariable("GamejoltPK", nil)
Global.SetVariable("DiscordAppID", "1342517648348680202")

-- Foolproof limits: passing one prints a warning, twice the limit blocks
-- creation. If you get blocked, check the resource recycling code.
Global.SetVariable("SE_MEMORY_SAFETY", true)    -- DANGEROUS
Global.SetVariable("OPT_COUNT_SPRITES", 2000)
Global.SetVariable("OPT_COUNT_TYPERS", 300)
Global.SetVariable("OPT_MEMORY_MAXSIZE", 0.8)
Global.SetVariable("OPT_LRU_SPRITES", {false, 180})      -- seconds; unused textures are evicted by LRU after this
Guard = ImportFile("Engine.MemorySafety")