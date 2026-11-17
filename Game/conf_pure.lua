Global.SetVariable("FirstRoom", "scene_logo")
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

-- Controller / Input simulation (desktop testing without real hardware):
-- virtualKeyboard shows the on-screen keyboard, joystick pretends a pad exists.
Global.SetVariable("ControllerSimulation", {
    virtualKeyboard = false,
    joystick        = false,
})

-- Analog stick dead-zone (0..1): 0.10 sensitive | 0.15 default | 0.20 tolerant.
Global.SetVariable("ControllerDeadzone", 0.15)

-- Network things
Global.SetVariable("GamejoltID", nil)
Global.SetVariable("GamejoltPK", nil)
Global.SetVariable("DiscordAppID", "1342517648348680202")

-- Limits: exceeding a count warns, exceeding it twice blocks creation, so check
-- the recycling logic if you get blocked.
Global.SetVariable("SE_MEMORY_SAFETY", true)    -- DANGEROUS
Global.SetVariable("OPT_COUNT_SPRITES", 2000)
Global.SetVariable("OPT_COUNT_TYPERS", 300)
Global.SetVariable("OPT_MEMORY_MAXSIZE", 0.8)
Global.SetVariable("OPT_LRU_SPRITES", {false, 180}) -- {enabled, seconds}: unused textures are evicted (LRU).
Guard = ImportFile("Engine.MemorySafety")