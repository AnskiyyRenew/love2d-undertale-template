-- Initialize
Global.SetVariable("FirstRoom", "Overworld.scene_ow_main_0")
--Global.SetVariable("FirstRoom", "TEST.gb")
--Global.SetVariable("FirstRoom", "TEST.scene_wingdings")   -- Wingdings visual check
Global.SetVariable("FirstRoom", "scene_logo")
Global.SetVariable("FirstRoom", "Battle.scene_battle_init")
Global.SetVariable("MainColor", {1, 1, 1})
--Global.SetVariable("MainColor", SE.tools.hexColor("#C14949"))
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

-- Controller / Input simulation (for testing on desktop without real hardware)
--   virtualKeyboard = true  -> force-show the on-screen virtual keyboard (click with mouse to test)
--   joystick        = true  -> pretend a gamepad is connected so you can simulate its buttons/axes
Global.SetVariable("ControllerSimulation", {
    virtualKeyboard = false,
    joystick        = false,
})

-- Analog stick dead-zone (0..1): how far the stick must travel from center
-- before it produces input. Higher tolerates more drift but loses precision.
--   sensitive = 0.10 | default = 0.15 | tolerant = 0.20
Global.SetVariable("ControllerDeadzone", 0.15)

-- Network things
Global.SetVariable("GamejoltID", nil)
Global.SetVariable("GamejoltPK", nil)
Global.SetVariable("DiscordAppID", "1342517648348680202") -- Default app.(yeah you can change it)

-- Limits
--[[
    The following are foolproof design measures: 
    if the number of images/typewriter entries/audio files you create exceeds this limit,
    you will be automatically notified.
    If it exceeds twice the limit, creation will begin to be blocked.

    Under normal circumstances, we do not need this many resources,
    so if you are blocked, please check whether the recycling function
    has any vulnerabilities.
]]
Global.SetVariable("SE_MEMORY_SAFETY", true)    -- DANGEROUS
Global.SetVariable("OPT_COUNT_SPRITES", 2000)
Global.SetVariable("OPT_COUNT_TYPERS", 300)
Global.SetVariable("OPT_MEMORY_MAXSIZE", 0.8)
Global.SetVariable("OPT_LRU_SPRITES", {true, 180})      -- Unit: seconds. If this time is exceeded without using the texture, it will be removed from the cache according to the LRU algorithm to free up space.
Guard = ImportFile("Engine.MemorySafety")