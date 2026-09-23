--[[
    VirtualKeyboard.lua - Mesh-rendered on-screen touch controller.

    Layout (normalized coordinates, so it survives any resolution / DPI):

        * dpad     - one big disc, bottom-left, split into 8 sectors of 45 deg.
                     A finger that lands anywhere on the disc and SLIDES around
                     switches direction without ever lifting: sliding from the
                     top sector into the right sector releases "up" and presses
                     "right". Diagonal sectors press both keys at once, so the
                     pad stays an 8-way d-pad (no analog, no 360 degrees).
        * buttons  - round keys. Z / X / C sit in a triangle at the bottom-right,
                     plus extra function keys (menu at the top-left, layout
                     editor next to it, ...).

    Everything is drawn from Meshes that are built ONCE in unit space
    (radius = 1) and only transformed at draw time, so no geometry is rebuilt
    per frame and the shapes stay smooth at any size.

    Auto-enabled on touch devices; on desktop force it on with
    Global.GetVariable("ControllerSimulation").virtualKeyboard == true and click
    with the mouse (a mouse drag is treated exactly like a sliding finger).

    Presses go through the same simulated-input path as Keyboard (or Joystick),
    so game logic reading GetState() sees the exact same feedback:
        1 = just pressed, 2 = held, -1 = just released, 0 = released.
--]]

local VirtualKeyboard = {
    enabled = false,          -- master on/off
    visible = true,           -- whether the overlay is drawn
    autoDetect = true,        -- enable automatically on touch devices
    target = "Keyboard",      -- "Keyboard" (simulates keys) or "Joystick" (simulates buttons)
    emitEvents = true,        -- also fire love.keypressed / keyreleased, like a real key
    alpha = 0.25,              -- default opacity for every control
    deadzone = 0.28,          -- dpad: fraction of the radius that stays neutral
    grabScale = 1.8,          -- dpad: sectors extend this far past the drawn rim
    hysteresis = math.rad(12),-- dpad: extra angle needed before the sector flips
    editMode = false,         -- layout editing on/off
    debug = false,            -- draw the real hit area (grab circle + last touch)

    controls = {},            -- array of control objects
    boundTouches = {},        -- touch id -> { ctrl, startX, startY, offX, offY, moved }

    -- Palette (shapes are all drawn in unit space and tinted from here).
    baseColor = { 0.08, 0.08, 0.12 },   -- control body
    idleColor = { 0.20, 0.20, 0.27 },   -- inactive dpad face (the octagon's 8 faces)
    rimColor  = { 0.82, 0.85, 0.95 },   -- outer rim
    iconColor = { 0.76, 0.79, 0.87 },   -- menu bars / move icon / menu text
    textColor = { 1.00, 1.00, 1.00 },   -- labels

    hitPadding = 1.08,        -- buttons grab slightly outside their rim
    savePath = "vk_layout.json",

    -- Outline drawn just OUTSIDE the d-pad octagon. Width is in screen pixels,
    -- so it stays 2px thin whatever the disc radius is (the band mesh is
    -- rebuilt if the radius changes). width <= 0 turns it off.
    outlineColor = { 0.00, 0.00, 0.00 },
    outlineWidth = 2,

    -- Text follows the engine's bondfont convention: ASCII is drawn with
    -- determination_mono 27, anything non-ASCII (Chinese) with SimSun 13
    -- scaled x2 -- the two come out the same apparent size. A caller asking
    -- for another pixel size gets that base font scaled up or down.
    engFont     = "Resources/Fonts/determination_mono.ttf",
    engSize     = 27,
    engScale    = 1,
    nonEngFont  = "Resources/Fonts/simsun.ttc",
    nonEngSize  = 13,
    nonEngScale = 2,

    -- Menu wording: taken from Localization/<lang>.json ("VirtualKeyboard.*")
    -- when Localize is running, else from the built-in tables below.
    useLocalize = true,
    l10nPrefix = "VirtualKeyboard.",

    -- menu / editor state
    menuOpen = false,         -- menu panel visible
    menuPage = "root",        -- "root" | "addpad" | "addkey"
    keyPage = 0,              -- page of the key picker
    keysPerPage = 24,         -- keys per page (6 columns x 4 rows)
    keyColumns = 6,
    deleteMode = false,       -- next tap on a control deletes it
    menuItems = {},           -- rebuilt by MenuLayout()
    menuRect = nil,
    uiTouches = {},           -- touches spent on the menu / delete mode
    lang = nil,               -- nil = follow the game language; "zh"/"en"/table forces one
    toastText = nil,
    toastUntil = 0,
}

-- Backwards compatible alias: the old build exposed "buttons".
VirtualKeyboard.buttons = VirtualKeyboard.controls

local MOUSE_TOUCH_ID = "__vk_mouse"
local TWO_PI = math.pi * 2
local STEP = math.pi / 4        -- 45deg: one dpad sector
local QUARTER = math.pi / 2     -- 90deg: quarter turn

-- Radius (fraction of the disc) of the neutral hub AND of the sectors' inner
-- edge. Keeping them equal is what stops a dark ring showing around the hub.
local HUB = 0.26
local APOTHEM = math.cos(math.pi / 8)   -- distance to an octagon face, r = 1

-- Direction key sets, one per scheme, indexed by sector:
-- 0 = right, then clockwise on screen (y grows downwards), so index * 45deg IS
-- the direction's angle in screen space. A disc picks its scheme with the
-- `scheme` field, so a layout can carry an arrow disc AND a WASD disc.
local DIR_SCHEMES = {
    arrows = {
        [0] = { "right" },
        [1] = { "right", "down" },
        [2] = { "down" },
        [3] = { "left", "down" },
        [4] = { "left" },
        [5] = { "left", "up" },
        [6] = { "up" },
        [7] = { "up", "right" },
    },
    wasd = {
        [0] = { "d" },
        [1] = { "d", "s" },
        [2] = { "s" },
        [3] = { "a", "s" },
        [4] = { "a" },
        [5] = { "a", "w" },
        [6] = { "w" },
        [7] = { "w", "d" },
    },
}

--- Register (or replace) a custom 8-direction key set.
---@param name string
---@param list table array indexed 0..7 of key arrays
function VirtualKeyboard.SetScheme(name, list)
    if (type(name) ~= "string" or type(list) ~= "table") then return end
    DIR_SCHEMES[name] = list
end

--- Names of every registered scheme (for the "add d-pad" picker).
---@return table
function VirtualKeyboard.GetSchemes()
    local names = {}
    for name in pairs(DIR_SCHEMES) do names[#names + 1] = name end
    table.sort(names)
    return names
end

--- Keys a disc presses for a given sector (nil for "no direction").
local function dirKeys(ctrl, dir)
    if (not dir or dir < 0) then return nil end
    local set = DIR_SCHEMES[ctrl.scheme] or DIR_SCHEMES.arrows
    return set[dir]
end

--- Change which key set a disc uses ("arrows", "wasd", or a custom one).
---@param id string
---@param scheme string
function VirtualKeyboard.SetDpadScheme(id, scheme)
    local ctrl = VirtualKeyboard.GetControl(id)
    if (ctrl and ctrl.kind == "dpad" and DIR_SCHEMES[scheme]) then
        ctrl.scheme = scheme
        return true
    end
    return false
end

-- Default layout. nx / ny = centre as a fraction of the screen, fr = radius as
-- a fraction of min(screen width, screen height) so controls keep a sane pixel
-- size in both portrait and landscape.
-- kind: "dpad" | "button". fn = "layout" marks the layout-editor key.
local defaultLayout = {
    { id = "dpad",  kind = "dpad",   nx = 0.20, ny = 0.72, fr = 0.170, color = { 1.00, 1.00, 1.00 } },
    { id = "z",     kind = "button", nx = 0.88, ny = 0.84, fr = 0.075, key = "z", label = "Z", color = { 0.22, 0.52, 0.85 } },
    { id = "x",     kind = "button", nx = 0.72, ny = 0.84, fr = 0.075, key = "x", label = "X", color = { 0.78, 0.30, 0.32 } },
    { id = "c",     kind = "button", nx = 0.80, ny = 0.66, fr = 0.075, key = "c", label = "C", color = { 0.45, 0.34, 0.78 } },
    { id = "menu",  kind = "button", nx = 0.055, ny = 0.080, fr = 0.045, icon = "bars", fn = "menu",  color = { 0.35, 0.38, 0.46 } },
    { id = "edit",  kind = "button", nx = 0.140, ny = 0.080, fr = 0.042, icon = "move", fn = "layout", color = { 0.30, 0.44, 0.38 } },
    -- top-right corner, mirroring the two menu keys: ESC and the engine's F2
    -- (back to the logo room). Both are real keys, so they also raise
    -- love.keypressed -- which is the only thing F2/ESC consumers listen to.
    { id = "esc",   kind = "button", nx = 0.860, ny = 0.080, fr = 0.045, key = "escape", label = "ESC", color = { 0.58, 0.36, 0.34 } },
    { id = "f2",    kind = "button", nx = 0.945, ny = 0.080, fr = 0.045, key = "f2", label = "F2", color = { 0.34, 0.44, 0.58 } },
}

-- Every key the engine knows about, most-used first, so a button can be mapped
-- to literally anything (V, H, F5, mouse1, ...).
-- Real key names and the engine's bind names both work: "confirm"/"cancel"/
-- "menu" are what game code usually reads.
local keyChoices = {}
do
    local seen = {}
    local function addKey(k)
        if (not seen[k]) then seen[k] = true; keyChoices[#keyChoices + 1] = k end
    end
    -- the ones people reach for first
    for _, k in ipairs({
        "z", "x", "c", "up", "down", "left", "right",
        "confirm", "cancel", "menu", "shift", "ctrl", "alt",
        "space", "return", "escape", "tab", "backspace",
    }) do addKey(k) end
    -- full alphabet, then digits, then function keys
    for i = 97, 122 do addKey(string.char(i)) end
    for i = 48, 57 do addKey(string.char(i)) end
    for i = 1, 12 do addKey("f" .. i) end
    -- everything else on a keyboard
    for _, k in ipairs({
        "lshift", "rshift", "lctrl", "rctrl", "lalt", "ralt",
        "capslock", "numlock", "scrolllock", "insert", "delete",
        "home", "end", "pageup", "pagedown", "printscreen", "pause",
        "mouse1", "mouse2", "mouse3", "mouse4", "mouse5",
        "-", "=", "[", "]", "\\", ";", "'", ",", ".", "/", "`",
    }) do addKey(k) end
    for i = 0, 9 do addKey("kp" .. i) end
end

-- Never removable: without them the overlay could not be operated any more.
local protectedIds = { menu = true, edit = true }

----------------------------------------------------------------------
-- Small helpers
----------------------------------------------------------------------

local function clamp(v, lo, hi)
    if (v < lo) then return lo end
    if (v > hi) then return hi end
    return v
end

local function alphaOf(ctrl)
    return ctrl.alpha or VirtualKeyboard.alpha or 0.5
end

local function setColor(c, a)
    SE.graphics.setColor(c[1], c[2], c[3], clamp(a, 0, 1))
end

local function mixColor(a, b, t)
    return {
        a[1] + (b[1] - a[1]) * t,
        a[2] + (b[2] - a[2]) * t,
        a[3] + (b[3] - a[3]) * t,
    }
end

----------------------------------------------------------------------
-- Labels / toast (menu + editor feedback)
----------------------------------------------------------------------

-- Chinese needs a CJK font; if it cannot be loaded the overlay falls back to
-- the ASCII wording below, which any font can draw.
local LABEL_SETS = {
    en = {
        title = "VIRTUAL PAD", add_button = "Add button", add_dpad = "Add d-pad",
        delete = "Delete a control", edit = "Edit layout", import = "Import",
        export = "Export", reset = "Reset layout", close = "Close", back = "Back",
        pick_key = "Pick a key to map", pick_scheme = "Pick a direction scheme",
        delete_hint = "Tap a control to delete it",
        exported = "Exported", imported = "Imported", deleted = "Deleted", added = "Added",
        no_json = "JSON library missing", export_failed = "Export failed",
        import_failed = "Import failed", failed = "Failed",
    },
    zh = {
        title = "虚拟按键", add_button = "添加按钮", add_dpad = "添加方向盘",
        delete = "删除按键", edit = "编辑布局", import = "导入布局",
        export = "导出布局", reset = "重置布局", close = "关闭", back = "返回",
        pick_key = "选择要映射的按键", pick_scheme = "选择方向键映射方案",
        delete_hint = "点按要删除的控件",
        exported = "已导出", imported = "已导入", deleted = "已删除", added = "已添加",
        no_json = "缺少 JSON 库", export_failed = "导出失败",
        import_failed = "导入失败", failed = "操作失败",
    },
}

----------------------------------------------------------------------
-- Label lookup (Localize -> built-in tables -> raw key)
----------------------------------------------------------------------

--- The engine's localization table, or false when it is not running.
--- Resolved lazily: `Localize` is a global created by main.lua, and the
--- overlay may be loaded before that happens.
local localizeRef
local function currentLocalize()
    if (localizeRef) then return localizeRef end
    -- only a positive result is cached: `Localize` is a global that main.lua
    -- creates, and the overlay may be loaded (or first drawn) before that
    local l = rawget(_G, "Localize")
    if (type(l) == "table" and l.localizeText) then localizeRef = l end
    return localizeRef
end

--- Which built-in wording table to use. An explicit SetLanguage() wins;
--- otherwise the language follows the one Localize has loaded.
local function resolveLanguage()
    if (VirtualKeyboard.lang) then return VirtualKeyboard.lang end
    local l = currentLocalize()
    local code = l and tostring(l.currentLanguage or "")
    if (code and code:sub(1, 2):lower() == "zh") then return "zh" end
    return "en"
end

-- Lookups are cached because Localize prints a warning for every missing key
-- and the menu redraws every frame. The cache is dropped whenever the game
-- language changes (see ClearLabelCache).
local labelCache = {}
local labelCacheLang

--- Drop the cached Localize lookups (call after a runtime language switch).
function VirtualKeyboard.ClearLabelCache()
    labelCache = {}
    labelCacheLang = nil
end

--- Look up a menu / editor string.
---@param key string
---@return string
function VirtualKeyboard.L(key)
    if (VirtualKeyboard.useLocalize and not VirtualKeyboard.lang) then
        local l = currentLocalize()
        if (l) then
            local lang = tostring(l.currentLanguage or "")
            if (lang ~= labelCacheLang) then
                labelCache, labelCacheLang = {}, lang
            end
            local cached = labelCache[key]
            if (cached == nil) then
                local full = VirtualKeyboard.l10nPrefix .. key
                local ok, value = pcall(l.localizeText, full)
                cached = (ok and type(value) == "string" and value ~= "") and value or false
                labelCache[key] = cached
            end
            if (cached) then return cached end
        end
    end
    local set = LABEL_SETS[resolveLanguage()] or LABEL_SETS.en
    return set[key] or LABEL_SETS.en[key] or key
end

--- Force a label language: "zh", "en", or a full custom table.
function VirtualKeyboard.SetLanguage(which)
    if (type(which) == "table") then
        LABEL_SETS.custom = which
        VirtualKeyboard.lang = "custom"
    elseif (LABEL_SETS[which]) then
        VirtualKeyboard.lang = which
    end
end

--- Show a short lived message near the top of the screen.
local function toast(key)
    VirtualKeyboard.toastText = VirtualKeyboard.L(key)
    local now = (SE.timer and SE.timer.getTime) and SE.timer.getTime() or 0
    VirtualKeyboard.toastUntil = now + 1.8
end

----------------------------------------------------------------------
-- Simulated input (identical behaviour for Keyboard and Joystick targets)
----------------------------------------------------------------------

----------------------------------------------------------------------
-- Key events
--
-- Simulating a key only feeds the engine's POLLED state (Keyboard.GetState).
-- Anything the game reads from an EVENT -- love.keypressed("f2"), "escape",
-- the dev keys -- would therefore never see a virtual press, which looks
-- exactly like "my button does nothing". So a virtual press also queues the
-- matching love.keypressed / love.keyreleased, mirroring a real key.
--
-- The queue is drained from Update(), i.e. once the input phase is over and
-- before the scene reads its input: firing it from inside the touch handler
-- itself would let a handler switch scenes and then hand the very same touch
-- to the new scene.
----------------------------------------------------------------------

local eventQueue = {}
local eventPending = {}     -- key -> true while its press is still undelivered
local flushing = false      -- guard against a handler queuing during a flush

--- Can this name be delivered as a real key event? Bind names ("confirm",
--- "menu", ...) exist only inside the engine and never arrive as events, and
--- mouse buttons are not keys either, so those stay state-only.
local function isEventKey(key)
    if (type(key) ~= "string" or key == "") then return false end
    if (key:sub(1, 5):lower() == "mouse") then return false end
    local binds = Keyboard and Keyboard.binds
    if (binds and (binds[key] or binds[key:lower()])) then return false end
    return true
end

local function flushEvents()
    if (flushing or #eventQueue == 0) then return end
    flushing = true
    local events = eventQueue
    eventQueue = {}
    for _, e in ipairs(events) do
        local fn = love and love[e.kind]
        if (type(fn) == "function") then
            -- scancode is the same name for every key we can emit here
            fn(e.key, e.key, false)
        end
    end
    flushing = false
end

local function pressKey(key)
    if (not key) then return end
    if (VirtualKeyboard.target == "Joystick") then
        if (Joystick and Joystick.SimulatePress) then Joystick.SimulatePress(key) end
    else
        if (Keyboard and Keyboard.SimulatePress) then Keyboard.SimulatePress(key) end
        if (VirtualKeyboard.emitEvents and isEventKey(key) and not eventPending[key]) then
            eventPending[key] = true
            eventQueue[#eventQueue + 1] = { kind = "keypressed", key = key }
        end
    end
end

local function releaseKey(key)
    if (not key) then return end
    if (VirtualKeyboard.target == "Joystick") then
        if (Joystick and Joystick.SimulateRelease) then Joystick.SimulateRelease(key) end
    else
        if (Keyboard and Keyboard.SimulateRelease) then Keyboard.SimulateRelease(key) end
        if (eventPending[key]) then
            eventPending[key] = nil
            eventQueue[#eventQueue + 1] = { kind = "keyreleased", key = key }
        end
    end
end

--- Press exactly the given set of keys, releasing whatever is no longer wanted.
--- Shared keys (e.g. "up" when sliding up -> up-right) stay held, so the
--- character never stutters while the finger crosses a sector boundary.
local function applyKeys(ctrl, keys)
    local wanted = {}
    if (keys) then
        for _, k in ipairs(keys) do wanted[k] = true end
    end
    for k in pairs(ctrl.held) do
        if (not wanted[k]) then
            releaseKey(k)
            ctrl.held[k] = nil
        end
    end
    for k in pairs(wanted) do
        if (not ctrl.held[k]) then
            pressKey(k)
            ctrl.held[k] = true
        end
    end
end

----------------------------------------------------------------------
-- Controls
----------------------------------------------------------------------

local function makeControl(def)
    local ctrl = {
        id = def.id,
        kind = def.kind or "button",
        key = def.key,
        label = def.label,
        icon = def.icon,
        fn = def.fn,
        scheme = def.scheme,        -- dpad only: "arrows" | "wasd" | custom
        nx = def.nx or 0.5,
        ny = def.ny or 0.5,
        fr = def.fr or 0.07,
        color = def.color or { 0.35, 0.35, 0.45 },
        alpha = def.alpha,          -- nil -> global alpha
        outlineWidth = def.outlineWidth,    -- dpad only: nil -> global width
        outlineColor = def.outlineColor,    -- dpad only: nil -> global colour
        enabled = def.enabled ~= false,
        -- runtime state
        held = {},
        pressed = false,
        dir = -1,
        boundBy = nil,
        cx = 0, cy = 0, r = 1,
        x = 0, y = 0, w = 0, h = 0, -- rect form, kept for compatibility
    }
    return ctrl
end

local function buildDefaultControls()
    VirtualKeyboard.controls = {}
    for _, def in ipairs(defaultLayout) do
        table.insert(VirtualKeyboard.controls, makeControl(def))
    end
    VirtualKeyboard.buttons = VirtualKeyboard.controls
end

--- Make sure the menu key and the layout key are always present (an imported
--- layout must not be able to remove the only way to reach the editor).
local function ensureSystemControls()
    local hasMenu, hasEdit = false, false
    for _, c in ipairs(VirtualKeyboard.controls) do
        if (c.fn == "menu") then hasMenu = true end
        if (c.fn == "layout") then hasEdit = true end
    end
    for _, def in ipairs(defaultLayout) do
        if (def.fn == "menu" and not hasMenu) then
            table.insert(VirtualKeyboard.controls, makeControl(def))
        elseif (def.fn == "layout" and not hasEdit) then
            table.insert(VirtualKeyboard.controls, makeControl(def))
        end
    end
end

-- Saved-layout format version. Bump it whenever the DEFAULT layout gains a
-- control: ApplyLayoutTable then merges those defaults back into an older save
-- once (otherwise a player who already has a vk_layout.json would simply never
-- see the new key). Saves written at this version are taken exactly as they are.
local LAYOUT_VERSION = 2

--- Re-add any default control an older save is missing (positions of the rest
--- are kept).
local function mergeNewDefaults()
    local have = {}
    for _, c in ipairs(VirtualKeyboard.controls) do have[c.id] = true end
    for _, def in ipairs(defaultLayout) do
        if (not have[def.id]) then
            table.insert(VirtualKeyboard.controls, makeControl(def))
        end
    end
end

--- Give a freshly added control an id that does not collide with an existing one.
local function ensureUniqueId(ctrl)
    local base = ctrl.id or "ctrl"
    local id, n = base, 1
    while (VirtualKeyboard.GetControl(id)) do
        n = n + 1
        id = base .. "_" .. n
    end
    ctrl.id = id
    return ctrl
end

local KEY_COLORS = {
    z = { 0.22, 0.52, 0.85 }, x = { 0.78, 0.30, 0.32 }, c = { 0.45, 0.34, 0.78 },
    confirm = { 0.22, 0.62, 0.45 }, cancel = { 0.82, 0.52, 0.22 }, menu = { 0.35, 0.38, 0.46 },
    shift = { 0.40, 0.62, 0.62 }, up = { 0.30, 0.55, 0.70 }, down = { 0.30, 0.55, 0.70 },
    left = { 0.30, 0.55, 0.70 }, right = { 0.30, 0.55, 0.70 },
    f2 = { 0.34, 0.44, 0.58 }, escape = { 0.58, 0.36, 0.34 },
}

--- Append a control to the current layout and rebuild the geometry.
---@param def table
---@return table
function VirtualKeyboard.AddControl(def)
    local ctrl = ensureUniqueId(makeControl(def))
    table.insert(VirtualKeyboard.controls, ctrl)
    VirtualKeyboard.Layout()
    return ctrl
end

--- Remove a control by id (menu / layout keys are protected).
---@param id string
---@return boolean
function VirtualKeyboard.RemoveControl(id)
    if (protectedIds[id]) then return false end
    for i, c in ipairs(VirtualKeyboard.controls) do
        if (c.id == id) then
            applyKeys(c, nil)
            table.remove(VirtualKeyboard.controls, i)
            VirtualKeyboard.Layout()
            return true
        end
    end
    return false
end

--- Add a round button mapped to `key` and drop straight into edit mode so it
--- can be dragged into place.
---@param key string
---@return table
function VirtualKeyboard.AddKeyButton(key)
    local ctrl = VirtualKeyboard.AddControl({
        id = "btn_" .. tostring(key),
        kind = "button",
        key = key,
        label = tostring(key):upper(),
        nx = 0.5, ny = 0.42, fr = 0.075,
        color = KEY_COLORS[key] or { 0.35, 0.45, 0.55 },
    })
    VirtualKeyboard.SetMenuOpen(false)
    VirtualKeyboard.SetEditMode(true)
    VirtualKeyboard.SaveLayout()
    toast("added")
    return ctrl
end

--- Add another 8-way disc.
---@param scheme string|nil "arrows" (default) | "wasd" | a custom scheme
---@return table
function VirtualKeyboard.AddDpad(scheme)
    local ctrl = VirtualKeyboard.AddControl({
        id = "dpad", kind = "dpad", nx = 0.30, ny = 0.55, fr = 0.15,
        scheme = DIR_SCHEMES[scheme] and scheme or "arrows",
        color = { 1.00, 1.00, 1.00 },
    })
    VirtualKeyboard.SetMenuOpen(false)
    VirtualKeyboard.SetEditMode(true)
    VirtualKeyboard.SaveLayout()
    toast("added")
    return ctrl
end

function VirtualKeyboard.GetControl(id)
    for _, ctrl in ipairs(VirtualKeyboard.controls) do
        if (ctrl.id == id) then return ctrl end
    end
    return nil
end

--- Replace the whole layout. Each def: { id, kind, key, label, icon, fn,
--- nx, ny, fr, color, alpha, enabled }.
---@param layout table|nil
function VirtualKeyboard.SetLayout(layout)
    if (not layout) then layout = defaultLayout end
    VirtualKeyboard.controls = {}
    VirtualKeyboard.buttons = VirtualKeyboard.controls
    for _, def in ipairs(layout) do
        table.insert(VirtualKeyboard.controls, makeControl(def))
    end
    VirtualKeyboard.Layout()
end

--- Append one control to the current layout.
---@param def table
function VirtualKeyboard.AddButton(def)
    local ctrl = makeControl(def)
    table.insert(VirtualKeyboard.controls, ctrl)
    return ctrl
end

function VirtualKeyboard.SetButtonEnabled(id, bool)
    local ctrl = VirtualKeyboard.GetControl(id)
    if (ctrl) then ctrl.enabled = not not bool end
end

--- Move a control (normalized centre).
function VirtualKeyboard.SetControlPos(id, nx, ny)
    local ctrl = VirtualKeyboard.GetControl(id)
    if (not ctrl) then return end
    ctrl.nx = clamp(nx or ctrl.nx, 0, 1)
    ctrl.ny = clamp(ny or ctrl.ny, 0, 1)
end

--- Resize a control (radius as a fraction of min(w, h)).
function VirtualKeyboard.SetControlSize(id, fr)
    local ctrl = VirtualKeyboard.GetControl(id)
    if (ctrl and fr) then ctrl.fr = fr end
end

--- Per-control opacity (nil = follow the global alpha).
function VirtualKeyboard.SetControlAlpha(id, a)
    local ctrl = VirtualKeyboard.GetControl(id)
    if (ctrl) then ctrl.alpha = a end
end

--- Restore the factory layout and drop the saved one.
function VirtualKeyboard.ResetLayout()
    buildDefaultControls()
    VirtualKeyboard.Layout()
    if (SE.filesystem and SE.filesystem.remove) then
        pcall(SE.filesystem.remove, VirtualKeyboard.savePath)
    end
end

----------------------------------------------------------------------
-- Layout persistence (JSON, via Utils/SafeJson + love.filesystem)
----------------------------------------------------------------------

--- The engine's JSON helper (Utils/SafeJson -> dkjson). Resolved lazily: the
--- library is only touched when an import/export actually happens.
local jsonLibCache
local function jsonLib()
    if (jsonLibCache ~= nil) then return jsonLibCache or nil end
    jsonLibCache = false
    if (type(ImportFile) == "function") then
        local ok, lib = pcall(ImportFile, "Utils.SafeJson")
        if (ok and type(lib) == "table" and lib.encode and lib.parse) then
            jsonLibCache = lib
        end
    end
    return jsonLibCache or nil
end

--- Serialize the current layout to a plain table (ready to be JSON encoded).
function VirtualKeyboard.GetLayoutTable()
    local controls = {}
    for _, c in ipairs(VirtualKeyboard.controls) do
        controls[#controls + 1] = {
            id = c.id,
            kind = c.kind,
            key = c.key,
            label = c.label,
            icon = c.icon,
            fn = c.fn,
            scheme = c.scheme,
            nx = c.nx,
            ny = c.ny,
            fr = c.fr,
            alpha = c.alpha,
            outlineWidth = c.outlineWidth,
            outlineColor = c.outlineColor,
            color = c.color,
            enabled = c.enabled,
        }
    end
    return { format = "soulengine.vklayout", version = LAYOUT_VERSION, controls = controls }
end

--- Apply a layout table (the inverse of GetLayoutTable). Unknown ids are
--- created, controls missing from the table are dropped.
function VirtualKeyboard.ApplyLayoutTable(data)
    if (type(data) ~= "table" or type(data.controls) ~= "table") then return false end
    local controls = {}
    for _, entry in ipairs(data.controls) do
        if (type(entry) == "table" and type(entry.id) == "string") then
            controls[#controls + 1] = makeControl(entry)
        end
    end
    if (#controls == 0) then return false end
    VirtualKeyboard.controls = controls
    VirtualKeyboard.buttons = controls
    ensureSystemControls()
    if ((tonumber(data.version) or 1) < LAYOUT_VERSION) then mergeNewDefaults() end
    VirtualKeyboard.Layout()
    return true
end

function VirtualKeyboard.SaveLayout()
    if (not (SE.filesystem and SE.filesystem.write)) then return false end
    local lib = jsonLib()
    if (not lib) then return false end
    local ok, text = pcall(lib.encode, VirtualKeyboard.GetLayoutTable())
    if (not ok or type(text) ~= "string") then return false end
    return pcall(SE.filesystem.write, VirtualKeyboard.savePath, text)
end

function VirtualKeyboard.LoadLayout()
    if (not (SE.filesystem and SE.filesystem.read and SE.filesystem.getInfo)) then return false end
    if (not SE.filesystem.getInfo(VirtualKeyboard.savePath)) then return false end
    local lib = jsonLib()
    if (not lib) then return false end
    local text = SE.filesystem.read(VirtualKeyboard.savePath)
    if (type(text) ~= "string") then return false end
    local ok, data = pcall(lib.parse, text)
    if (not ok or type(data) ~= "table") then return false end
    if (not VirtualKeyboard.ApplyLayoutTable(data)) then return false end
    return true
end

--- Write the layout as JSON into the save directory (and to the clipboard when
--- the platform has one) so it can be copied off the device.
function VirtualKeyboard.ExportLayout()
    local lib = jsonLib()
    if (not lib) then toast("no_json"); return false end
    local ok, text = pcall(lib.encode, VirtualKeyboard.GetLayoutTable())
    if (not ok or type(text) ~= "string") then toast("export_failed"); return false end
    local written = false
    if (SE.filesystem and SE.filesystem.write) then
        written = pcall(SE.filesystem.write, VirtualKeyboard.savePath, text)
    end
    if (SE.system and SE.system.setClipboardText) then
        pcall(SE.system.setClipboardText, text)
    end
    toast(written and "exported" or "export-failed")
    return written
end

--- Read a layout from the save directory; if there is none, fall back to
--- whatever JSON is sitting on the clipboard.
function VirtualKeyboard.ImportLayout()
    local lib = jsonLib()
    if (not lib) then toast("no_json"); return false end
    local text
    if (SE.filesystem and SE.filesystem.getInfo and SE.filesystem.read
        and SE.filesystem.getInfo(VirtualKeyboard.savePath)) then
        text = SE.filesystem.read(VirtualKeyboard.savePath)
    end
    if (type(text) ~= "string" and SE.system and SE.system.getClipboardText) then
        local ok, clip = pcall(SE.system.getClipboardText)
        if (ok and type(clip) == "string" and clip:sub(1, 1) == "{") then text = clip end
    end
    if (type(text) ~= "string") then toast("import_failed"); return false end
    local ok, data = pcall(lib.parse, text)
    if (not ok or type(data) ~= "table") then toast("import_failed"); return false end
    if (not VirtualKeyboard.ApplyLayoutTable(data)) then toast("import_failed"); return false end
    VirtualKeyboard.SaveLayout()
    toast("imported")
    return true
end

----------------------------------------------------------------------
-- Menu (add / delete / import / export / edit)
----------------------------------------------------------------------

--- Open / close the menu. Opening also leaves delete mode and releases input.
function VirtualKeyboard.SetMenuOpen(bool)
    bool = not not bool
    if (bool == VirtualKeyboard.menuOpen) then return end
    VirtualKeyboard.menuOpen = bool
    if (bool) then
        VirtualKeyboard.deleteMode = false
        VirtualKeyboard.menuPage = "root"
        VirtualKeyboard.ReleaseAll()
        -- the game language may have changed since the panel was last open
        VirtualKeyboard.ClearLabelCache()
    end
    VirtualKeyboard.MenuLayout()
end

local function startDeleteMode()
    VirtualKeyboard.deleteMode = true
    VirtualKeyboard.SetMenuOpen(false)
end

local SCHEME_HINTS = {
    arrows = "up down left right",
    wasd = "W A S D",
}

local function openPage(page)
    VirtualKeyboard.menuPage = page
    VirtualKeyboard.keyPage = 0
    VirtualKeyboard.MenuLayout()
end

local rootActions = {
    { id = "add_button", label = "add_button", act = function() openPage("addkey") end },
    { id = "add_dpad", label = "add_dpad", act = function() openPage("addpad") end },
    { id = "delete", label = "delete", act = startDeleteMode },
    { id = "edit", label = "edit", act = function()
        VirtualKeyboard.SetEditMode(not VirtualKeyboard.editMode)
        VirtualKeyboard.SetMenuOpen(false)
    end },
    { id = "import", label = "import", act = function() VirtualKeyboard.SetMenuOpen(false); VirtualKeyboard.ImportLayout() end },
    { id = "export", label = "export", act = function() VirtualKeyboard.SetMenuOpen(false); VirtualKeyboard.ExportLayout() end },
    { id = "reset", label = "reset", act = function() VirtualKeyboard.ResetLayout(); VirtualKeyboard.SetMenuOpen(false) end },
    { id = "close", label = "close", act = function() VirtualKeyboard.SetMenuOpen(false) end },
}

local function buildMenuItems()
    local items = {}
    local page = VirtualKeyboard.menuPage

    if (page == "addpad") then
        -- which key set should the new disc emit
        local names = VirtualKeyboard.GetSchemes()
        for i, name in ipairs(names) do
            items[i] = {
                id = "scheme:" .. name,
                label = name,
                hint = SCHEME_HINTS[name],
                raw = true,
                act = function() VirtualKeyboard.AddDpad(name) end,
            }
        end
        items[#items + 1] = { id = "back", label = "back", act = function() openPage("root") end }

    elseif (page == "addkey") then
        -- every key, paged so the panel always fits on screen
        local perPage = VirtualKeyboard.keysPerPage
        local first = VirtualKeyboard.keyPage * perPage + 1
        local last = math.min(#keyChoices, first + perPage - 1)
        for i = first, last do
            local key = keyChoices[i]
            items[#items + 1] = {
                id = "key:" .. key,
                label = key,
                raw = true,        -- draw the key name verbatim, not translated
                act = function() VirtualKeyboard.AddKeyButton(key) end,
            }
        end
        items[#items + 1] = { id = "keyprev", label = "<", raw = true, act = function()
            if (VirtualKeyboard.keyPage > 0) then
                VirtualKeyboard.keyPage = VirtualKeyboard.keyPage - 1
                VirtualKeyboard.MenuLayout()
            end
        end }
        items[#items + 1] = { id = "keynext", label = ">", raw = true, act = function()
            if (last < #keyChoices) then
                VirtualKeyboard.keyPage = VirtualKeyboard.keyPage + 1
                VirtualKeyboard.MenuLayout()
            end
        end }
        items[#items + 1] = { id = "back", label = "back", act = function() openPage("root") end }

    else
        for i, a in ipairs(rootActions) do items[i] = a end
    end
    return items
end

--- Recompute the menu panel and every row rectangle (screen space).
function VirtualKeyboard.MenuLayout()
    local w = VirtualKeyboard.screenW or (SE.graphics and SE.graphics.getWidth() or 0)
    local h = VirtualKeyboard.screenH or (SE.graphics and SE.graphics.getHeight() or 0)
    local unit = math.min(w, h)
    if (unit <= 0) then return end

    local items = buildMenuItems()
    VirtualKeyboard.menuItems = items

    -- more columns on the picker pages: keys and schemes have short labels
    local cols = 1
    if (VirtualKeyboard.menuPage == "addkey") then cols = VirtualKeyboard.keyColumns
    elseif (VirtualKeyboard.menuPage == "addpad") then cols = 2 end
    local rows = math.ceil(#items / cols)
    local pad = unit * 0.028
    local rowH = unit * 0.105
    local titleH = rowH * 0.9
    local mw = math.min(w * 0.92, unit * 1.30)
    local mh = titleH + rows * rowH + pad * 2
    local mx = (w - mw) * 0.5
    local my = (h - mh) * 0.5

    VirtualKeyboard.menuRect = { x = mx, y = my, w = mw, h = mh }
    for i, item in ipairs(items) do
        local c = (i - 1) % cols
        local r = math.floor((i - 1) / cols)
        local cw = (mw - pad * 2) / cols
        item.x = mx + pad + c * cw
        item.y = my + pad + titleH + r * rowH
        item.w = cw
        item.h = rowH
    end
end

local function menuHit(x, y)
    for _, item in ipairs(VirtualKeyboard.menuItems) do
        if (item.x and x >= item.x and x <= item.x + item.w
            and y >= item.y and y <= item.y + item.h) then
            return item
        end
    end
    return nil
end

local function inMenuPanel(x, y)
    local r = VirtualKeyboard.menuRect
    return (r ~= nil and x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h)
end

----------------------------------------------------------------------
-- Geometry: meshes are built once in unit space (radius = 1)
----------------------------------------------------------------------

local MESH = {}
local fontCache = {}

local function pushVertex(verts, x, y)
    verts[#verts + 1] = { x, y, 0, 0, 1, 1, 1, 1 }
end

local function pushTri(verts, ax, ay, bx, by, cx, cy)
    pushVertex(verts, ax, ay)
    pushVertex(verts, bx, by)
    pushVertex(verts, cx, cy)
end

local function buildCircleMesh(segments)
    local verts = {}
    pushVertex(verts, 0, 0)
    for i = 0, segments do
        local a = (i / segments) * TWO_PI
        pushVertex(verts, math.cos(a), math.sin(a))
    end
    return SE.graphics.newMesh(verts, "fan")
end

--- Band (annulus, or an annular sector) between two radii and two angles.
local function buildBandMesh(r0, r1, a0, a1, segments)
    local verts = {}
    for i = 0, segments - 1 do
        local t0, t1 = i / segments, (i + 1) / segments
        local ang0, ang1 = a0 + (a1 - a0) * t0, a0 + (a1 - a0) * t1
        local c0, s0 = math.cos(ang0), math.sin(ang0)
        local c1, s1 = math.cos(ang1), math.sin(ang1)
        pushTri(verts, r1 * c0, r1 * s0, r0 * c0, r0 * s0, r0 * c1, r0 * s1)
        pushTri(verts, r1 * c0, r1 * s0, r0 * c1, r0 * s1, r1 * c1, r1 * s1)
    end
    return SE.graphics.newMesh(verts, "triangles")

end

----------------------------------------------------------------------
-- Octagon geometry (the d-pad's look)
--
-- The disc is a regular octagon whose FLAT FACES sit on the eight sector
-- centres: vertices at (k + 0.5) * 45deg, so each face is exactly one
-- direction and the shape reads as a d-pad without any arrows. The hit
-- testing is untouched -- it stays radius + angle based (a circle), which is
-- why the debug overlay still draws round guides.
----------------------------------------------------------------------

--- A regular octagon of circumradius 1, flat face towards +x / +y / ... .
local function buildOctagonMesh()
    local verts = {}
    pushVertex(verts, 0, 0)
    for k = 0, 8 do
        local a = (k + 0.5) * STEP
        pushVertex(verts, math.cos(a), math.sin(a))
    end
    return SE.graphics.newMesh(verts, "fan")
end

--- Octagonal frame between two circumradii (constant face thickness).
local function buildOctagonRingMesh(rOuter, rInner)
    local verts = {}
    for k = 0, 7 do
        local a0, a1 = (k + 0.5) * STEP, (k + 1.5) * STEP
        local oc0, os0 = rOuter * math.cos(a0), rOuter * math.sin(a0)
        local oc1, os1 = rOuter * math.cos(a1), rOuter * math.sin(a1)
        local ic0, is0 = rInner * math.cos(a0), rInner * math.sin(a0)
        local ic1, is1 = rInner * math.cos(a1), rInner * math.sin(a1)
        pushTri(verts, oc0, os0, oc1, os1, ic1, is1)
        pushTri(verts, oc0, os0, ic1, is1, ic0, is0)
    end
    return SE.graphics.newMesh(verts, "triangles")
end

-- Outline meshes are built in screen-pixel space (drawn at scale 1) because the
-- stroke has to be a fixed number of pixels thick. Keyed by the two radii, so
-- a given disc size reuses one mesh; only a window resize builds a new one.
local outlineCache = {}
local outlineCount = 0

--- Octagonal stroke band from pixel radius `inner` out to `inner + width`.
local function getOutlineMesh(inner, width)
    local key = string.format("%.1f|%.1f", inner, width)
    local mesh = outlineCache[key]
    if (mesh == nil) then
        if (outlineCount > 16) then       -- window resize spam: start over
            outlineCache, outlineCount = {}, 0
        end
        mesh = buildOctagonRingMesh(inner + width, inner)
        outlineCache[key] = mesh
        outlineCount = outlineCount + 1
    end
    return mesh
end


--- One d-pad sector, centred on +x (rotate by i * 45deg for sector i).
--- The outer boundary is the octagon's flat face, so a lit sector ends
--- exactly at the edge instead of poking out of it.
local function buildSectorMesh(rInner, half, segments)
    local verts = {}
    -- the face runs at x = cos(22.5deg); the wedge stops just short of the
    -- vertex (half < 22.5deg) so neighbouring sectors stay visually separated
    local face = APOTHEM
    for i = 0, segments - 1 do
        local a0 = -half + (2 * half) * (i / segments)
        local a1 = -half + (2 * half) * ((i + 1) / segments)
        -- project the inner rim points onto the face along the ray
        local ix0, iy0 = rInner * math.cos(a0), rInner * math.sin(a0)
        local ix1, iy1 = rInner * math.cos(a1), rInner * math.sin(a1)
        pushTri(verts, ix0, iy0, face, iy0 / ix0 * face, face, iy1 / ix1 * face)
        pushTri(verts, ix0, iy0, face, iy1 / ix1 * face, ix1, iy1)
    end
    return SE.graphics.newMesh(verts, "triangles")
end

-- Arrow pointing along +x, in unit-disc space (0.34 .. 0.82 of the radius).
-- No longer drawn on the disc (the octagon shows the directions); it is still
-- the glyph for the "move" icon.
local ARROW_POINTS = {
    0.78, 0.00,
    0.48, -0.16,
    0.48, -0.08,
    0.33, -0.08,
    0.33, 0.08,
    0.48, 0.08,
    0.48, 0.16,
}

local function buildArrowMesh()
    local verts = {}
    local tris = SE.math.triangulate(ARROW_POINTS)
    for _, tri in ipairs(tris) do
        pushTri(verts, tri[1], tri[2], tri[3], tri[4], tri[5], tri[6])
    end
    return SE.graphics.newMesh(verts, "triangles")
end

local function buildRectMesh()
    local verts = {}
    pushTri(verts, -0.5, -0.5, 0.5, -0.5, 0.5, 0.5)
    pushTri(verts, -0.5, -0.5, 0.5, 0.5, -0.5, 0.5)
    return SE.graphics.newMesh(verts, "triangles")
end

local function buildMeshes()
    if (MESH.built) then return end
    -- round shapes: buttons, and the debug guides (the hit area IS a circle)
    MESH.circle = buildCircleMesh(64)
    MESH.ring = buildBandMesh(0.93, 1.00, 0, TWO_PI, 72)
    -- the d-pad: octagonal body, octagonal rim, one flat wedge per direction
    MESH.octagon = buildOctagonMesh()
    MESH.octRing = buildOctagonRingMesh(1.00, 0.93)
    -- Sector highlight: 45deg minus a small gap so the 8 faces read separately.
    MESH.wedge = buildSectorMesh(HUB, STEP * 0.5, 10)
    MESH.arrow = buildArrowMesh()
    MESH.rect = buildRectMesh()
    MESH.built = true
end

----------------------------------------------------------------------
-- Text: bondfont style -- mono 27 for ASCII, SimSun 13 x2 for the rest
----------------------------------------------------------------------

--- True when the string holds anything outside ASCII (Chinese and friends).
local function hasWideChar(s)
    for i = 1, #s do
        if (string.byte(s, i) >= 0x80) then return true end
    end
    return false
end

local function loadFont(path, size)
    size = math.floor(size + 0.5)
    if (size < 6) then size = 6 end
    local key = tostring(path) .. "|" .. size
    local f = fontCache[key]
    if (f == nil) then
        local ok, font
        if (path) then
            ok, font = pcall(SE.graphics.newFont, path, size)
        else
            ok, font = pcall(SE.graphics.newFont, size)
        end
        f = (ok and font) or false
        fontCache[key] = f
    end
    return f or nil
end

--- Font and scale for `text` at a requested pixel size.
---@return table|nil font, number scale, number lineHeight
local function fontFor(text, size)
    size = math.floor((size or 16) + 0.5)
    if (size < 6) then size = 6 end

    local path, base, mul
    if (hasWideChar(text)) then
        path, base, mul = VirtualKeyboard.nonEngFont, VirtualKeyboard.nonEngSize, VirtualKeyboard.nonEngScale
    else
        path, base, mul = VirtualKeyboard.engFont, VirtualKeyboard.engSize, VirtualKeyboard.engScale
    end

    local unit = (tonumber(base) or 16) * (tonumber(mul) or 1)
    if (unit <= 0) then unit = size end

    local f = loadFont(path, base)
    if (f) then
        local s = size / unit
        return f, s, f:getHeight() * s
    end
    -- neither custom font could be loaded: plain engine font, no scaling
    f = loadFont(nil, size)
    return f, 1, (f and f:getHeight() or size)
end

--- Width of `text` when drawn at `size` pixels (scale included).
local function textWidth(text, size)
    local f, s = fontFor(text, size)
    if (not f) then return 0 end
    return f:getWidth(text) * s
end

--- Draw `text` with its top-left at (x, y), scaled to `size` pixels.
local function drawText(text, x, y, size)
    local f, s = fontFor(text, size)
    if (not f) then return end
    local prev = SE.graphics.getFont()
    SE.graphics.setFont(f)
    SE.graphics.print(text, x, y, 0, s, s)
    if (prev) then SE.graphics.setFont(prev) end
end

--- Draw `text` centred on (cx, cy) at `size` pixels.
local function drawTextCentered(text, cx, cy, size)
    local f, s, h = fontFor(text, size)
    if (not f) then return end
    drawText(text, cx - f:getWidth(text) * s * 0.5, cy - h * 0.5, size)
end

--- Font / scale / line height a string would be drawn with. Exposed for
--- tooling and tests: it is how you check which of the two families wins.
function VirtualKeyboard.FontFor(text, size)
    return fontFor(text, size)
end

----------------------------------------------------------------------
-- Enable / visibility / targets
----------------------------------------------------------------------

function VirtualKeyboard.IsTouchDevice()
    if (love and love.system and love.system.getOS) then
        local os = love.system.getOS()
        if (os == "Android" or os == "iOS" or os == "tvOS") then
            return true
        end
    end
    return false
end

function VirtualKeyboard.SetEnabled(bool)
    VirtualKeyboard.enabled = not not bool
    if (not VirtualKeyboard.enabled) then VirtualKeyboard.ReleaseAll() end
end

function VirtualKeyboard.SetVisible(bool)
    VirtualKeyboard.visible = not not bool
    if (not VirtualKeyboard.visible) then VirtualKeyboard.ReleaseAll() end
end

function VirtualKeyboard.SetAutoDetect(bool)
    VirtualKeyboard.autoDetect = not not bool
end

function VirtualKeyboard.SetTarget(target)
    VirtualKeyboard.target = (target == "Joystick") and "Joystick" or "Keyboard"
end

--- Global default opacity (controls may override it individually).
function VirtualKeyboard.SetAlpha(a)
    if (a ~= nil) then VirtualKeyboard.alpha = clamp(a, 0, 1) end
end

--- Fraction of the disc radius that counts as "no direction".
function VirtualKeyboard.SetDeadzone(v)
    if (v ~= nil) then VirtualKeyboard.deadzone = clamp(v, 0, 0.9) end
end

--- How far the dpad's sectors reach past the drawn rim (1 = rim only).
function VirtualKeyboard.SetGrabScale(v)
    if (v ~= nil and v >= 1) then VirtualKeyboard.grabScale = v end
end

--- Extra angle (radians) the finger must rotate past a sector boundary before
--- the direction flips. Bigger = stickier, less chatter near the centre.
function VirtualKeyboard.SetHysteresis(v)
    if (v ~= nil) then VirtualKeyboard.hysteresis = clamp(v, 0, STEP) end
end

--- Draw the real hit area on top of the overlay (grab circle, sector
--- boundaries, dead zone and the last press point). Handy while tuning.
function VirtualKeyboard.SetDebug(bool)
    VirtualKeyboard.debug = not not bool
end

--- Outline around the d-pad octagon. `width` is in screen pixels (0 disables);
--- `color` is an {r, g, b} triple. Both may be overridden per control with the
--- `outlineWidth` / `outlineColor` fields in the layout table.
function VirtualKeyboard.SetOutline(width, color)
    if (width ~= nil) then
        VirtualKeyboard.outlineWidth = math.max(0, tonumber(width) or 0)
    end
    if (type(color) == "table") then
        VirtualKeyboard.outlineColor = { color[1], color[2], color[3] }
    end
end

----------------------------------------------------------------------
-- Layout / update
----------------------------------------------------------------------

--- Recompute pixel geometry from the normalized layout (cheap: called per frame).
function VirtualKeyboard.Layout()
    local w, h = SE.graphics.getDimensions()
    local unit = math.min(w, h)
    VirtualKeyboard.screenW = w
    VirtualKeyboard.screenH = h
    for _, ctrl in ipairs(VirtualKeyboard.controls) do
        ctrl.r = (ctrl.fr or 0.07) * unit
        ctrl.cx = (ctrl.nx or 0.5) * w
        ctrl.cy = (ctrl.ny or 0.5) * h
        ctrl.x = ctrl.cx - ctrl.r
        ctrl.y = ctrl.cy - ctrl.r
        ctrl.w = ctrl.r * 2
        ctrl.h = ctrl.r * 2
    end
end

--- Release every simulated key and clear all bindings.
function VirtualKeyboard.ReleaseAll()
    for _, ctrl in ipairs(VirtualKeyboard.controls) do
        applyKeys(ctrl, nil)
        ctrl.pressed = false
        ctrl.dir = -1
        ctrl.boundBy = nil
    end
    VirtualKeyboard.boundTouches = {}
    VirtualKeyboard.uiTouches = {}
end

function VirtualKeyboard.SetEditMode(bool)
    bool = not not bool
    if (bool == VirtualKeyboard.editMode) then return end
    VirtualKeyboard.editMode = bool
    VirtualKeyboard.ReleaseAll()
    if (not bool) then VirtualKeyboard.SaveLayout() end
end

function VirtualKeyboard.Update()
    -- Deliver queued key events first: by now the input phase is over, and the
    -- scene is about to read its input this frame.
    flushEvents()
    if (VirtualKeyboard.autoDetect and not VirtualKeyboard.enabled and VirtualKeyboard.IsTouchDevice()) then
        VirtualKeyboard.enabled = true
        if (not VirtualKeyboard.loadedLayout) then
            VirtualKeyboard.loadedLayout = true
            VirtualKeyboard.LoadLayout()
        end
    end
    if (not VirtualKeyboard.enabled or not VirtualKeyboard.visible) then
        VirtualKeyboard.ReleaseAll()
        return
    end
    VirtualKeyboard.Layout()
    if (VirtualKeyboard.menuOpen) then VirtualKeyboard.MenuLayout() end
end

----------------------------------------------------------------------
-- Hit testing / direction
----------------------------------------------------------------------

---@param x number
---@param y number
---@param kindOnly string|nil when set, only controls of this kind are considered
local function hitTest(x, y, kindOnly)
    -- Later controls draw on top, so test them first.
    for i = #VirtualKeyboard.controls, 1, -1 do
        local ctrl = VirtualKeyboard.controls[i]
        if (ctrl.enabled and (not kindOnly or ctrl.kind == kindOnly)) then
            -- The dpad's 8 sectors reach past the drawn rim (grabScale), so a
            -- finger that lands just outside the disc still steers.
            local pad = (ctrl.kind == "dpad") and VirtualKeyboard.grabScale or VirtualKeyboard.hitPadding
            local dx, dy = x - ctrl.cx, y - ctrl.cy
            local rr = ctrl.r * pad
            if (dx * dx + dy * dy <= rr * rr) then
                return ctrl
            end
        end
    end
    return nil
end

local TAN22_5 = math.tan(math.pi / 8)   -- 0.4142: half a sector (22.5deg)

--- Which of the 8 sectors a vector falls into, WITHOUT any atan.
--- atan2 exists on LuaJIT but not on the Lua 5.4 fallback build of LOVE, so the
--- sector is picked with two slope comparisons instead -- portable everywhere
--- (desktop, Android, either Lua flavour) and cheaper.
---@param dx number
---@param dy number
---@return integer 0=right, 1=down-right, 2=down ... 7=up-right
local function sectorOf(dx, dy)
    local adx, ady = math.abs(dx), math.abs(dy)
    if (ady <= adx * TAN22_5) then return (dx >= 0) and 0 or 4 end
    if (adx <= ady * TAN22_5) then return (dy >= 0) and 2 or 6 end
    if (dx >= 0) then return (dy >= 0) and 1 or 7 end
    return (dy >= 0) and 3 or 5
end

--- Recompute the sector a finger sits in and press / release accordingly.
---
--- Two rules keep it from feeling hair-trigger:
---   * the sector is decided by DIRECTION only, so it keeps working no matter
---     how far the finger slides past the rim (the wedge is unbounded outward);
---   * once a sector is held, the finger must rotate more than half a sector
---     PLUS `hysteresis` before it flips -- otherwise the direction chatters
---     the moment the finger drifts near a boundary (worst close to the centre).
---     The "how far past the line" test is a cross product, again no atan.
local function updateDirection(ctrl, x, y)
    local dx, dy = x - ctrl.cx, y - ctrl.cy
    local dist = math.sqrt(dx * dx + dy * dy)
    local dir = -1
    if (dist > ctrl.r * VirtualKeyboard.deadzone) then
        dir = sectorOf(dx, dy)
        if (ctrl.dir >= 0 and dir ~= ctrl.dir) then
            local delta = ((dir - ctrl.dir + 4) % 8) - 4   -- shortest way round
            if (delta == 1 or delta == -1) then
                -- only the neighbouring sector is "sticky"; a fast swipe across
                -- two sectors switches immediately
                local t = ctrl.dir * STEP + delta * (STEP * 0.5 + VirtualKeyboard.hysteresis)
                local cross = math.cos(t) * dy - math.sin(t) * dx
                if (delta * cross <= 0) then dir = ctrl.dir end
            end
        end
    end
    if (dir ~= ctrl.dir) then
        ctrl.dir = dir
        applyKeys(ctrl, dirKeys(ctrl, dir))
    end
end

----------------------------------------------------------------------
-- Touch / mouse input
----------------------------------------------------------------------

--- Drop a binding and release whatever it was holding. Does NOT run the tap
--- semantics (edit-mode toggle), so it is safe to call for a stale binding.
---@return table|nil slot
local function releaseTouch(id)
    local slot = VirtualKeyboard.boundTouches[id]
    if (not slot) then return nil end
    VirtualKeyboard.boundTouches[id] = nil
    local ctrl = slot.ctrl
    if (ctrl.boundBy == id) then ctrl.boundBy = nil end
    ctrl.pressed = false
    ctrl.dir = -1
    applyKeys(ctrl, nil)
    return slot
end

function VirtualKeyboard.TouchPressed(id, x, y)
    if (not VirtualKeyboard.enabled or not VirtualKeyboard.visible) then return false end
    -- A press for an id that is still bound means a release never arrived
    -- (mouse let go outside the window, dropped touch event, ...). Drop the
    -- stale binding instead of ignoring the press -- otherwise every later
    -- click is swallowed and the direction stays frozen on the old value.
    releaseTouch(id)

    VirtualKeyboard.lastPress = { x = x, y = y }

    -- Menu panel swallows every touch while it is open.
    if (VirtualKeyboard.menuOpen) then
        VirtualKeyboard.uiTouches[id] = true
        local item = menuHit(x, y)
        if (item and item.act) then
            item.act()
        elseif (not inMenuPanel(x, y)) then
            VirtualKeyboard.SetMenuOpen(false)
        end
        return true
    end

    -- Delete mode: the next tap on a control removes it.
    if (VirtualKeyboard.deleteMode) then
        VirtualKeyboard.uiTouches[id] = true
        local target = hitTest(x, y)
        if (target and not protectedIds[target.id]) then
            VirtualKeyboard.RemoveControl(target.id)
            VirtualKeyboard.SaveLayout()
            toast("deleted")
        end
        VirtualKeyboard.deleteMode = false
        return true
    end

    local ctrl = hitTest(x, y)
    if (not ctrl) then return false end

    local slot = {
        ctrl = ctrl,
        startX = x, startY = y,
        offX = x - ctrl.cx, offY = y - ctrl.cy,
        moved = false,
    }
    VirtualKeyboard.boundTouches[id] = slot

    if (VirtualKeyboard.editMode) then
        return true -- drag only, no input is generated
    end

    if (ctrl.kind == "dpad") then
        -- one finger steers the disc; a second finger on it is ignored
        if (ctrl.boundBy and ctrl.boundBy ~= id) then
            VirtualKeyboard.boundTouches[id] = nil
            return false
        end
        ctrl.boundBy = id
        ctrl.pressed = true
        updateDirection(ctrl, x, y)
        return true
    end

    if (ctrl.boundBy and ctrl.boundBy ~= id) then
        VirtualKeyboard.boundTouches[id] = nil
        return false
    end
    ctrl.boundBy = id
    ctrl.pressed = true
    applyKeys(ctrl, ctrl.key and { ctrl.key } or nil)
    return true
end

function VirtualKeyboard.TouchMoved(id, x, y)
    local slot = VirtualKeyboard.boundTouches[id]
    if (not slot) then return false end
    local ctrl = slot.ctrl

    if (math.abs(x - slot.startX) + math.abs(y - slot.startY) > 6) then
        slot.moved = true
    end

    if (VirtualKeyboard.editMode) then
        if (slot.moved) then
            local w = VirtualKeyboard.screenW or SE.graphics.getWidth()
            local h = VirtualKeyboard.screenH or SE.graphics.getHeight()
            ctrl.nx = clamp((x - slot.offX) / w, 0, 1)
            ctrl.ny = clamp((y - slot.offY) / h, 0, 1)
            VirtualKeyboard.Layout()
        end
        return true
    end

    if (ctrl.kind == "dpad") then
        updateDirection(ctrl, x, y)
    else
        -- Slide between round keys without lifting: dragging off Z onto X
        -- releases Z and presses X from scratch, and sliding back re-presses Z.
        local other = hitTest(x, y, "button")
        if (other and other ~= ctrl) then
            applyKeys(ctrl, nil)
            ctrl.pressed = false
            ctrl.boundBy = nil
            ctrl = other
            ctrl.boundBy = id
            ctrl.pressed = true
            applyKeys(ctrl, ctrl.key and { ctrl.key } or nil)
            slot.ctrl = ctrl
        end
    end
    return true
end

function VirtualKeyboard.TouchReleased(id, x, y)
    -- touches that were spent on the menu / delete mode end here
    if (VirtualKeyboard.uiTouches[id]) then
        VirtualKeyboard.uiTouches[id] = nil
        return true
    end

    local slot = VirtualKeyboard.boundTouches[id]
    if (not slot) then return false end
    local ctrl = slot.ctrl
    releaseTouch(id)

    if (VirtualKeyboard.editMode) then
        if (not slot.moved and ctrl.fn == "layout") then
            VirtualKeyboard.SetEditMode(false) -- exits and saves
        elseif (slot.moved) then
            VirtualKeyboard.SaveLayout()
        end
        return true
    end

    -- A tap (not a drag) on the layout key opens the editor, on the menu key it
    -- toggles the menu panel.
    if (not slot.moved and ctrl.fn == "layout") then
        VirtualKeyboard.SetEditMode(true)
    elseif (not slot.moved and ctrl.fn == "menu") then
        VirtualKeyboard.SetMenuOpen(not VirtualKeyboard.menuOpen)
    end
    return true
end

function VirtualKeyboard.MousePressed(sx, sy)
    if (not VirtualKeyboard.enabled or not VirtualKeyboard.visible) then return false end
    return VirtualKeyboard.TouchPressed(MOUSE_TOUCH_ID, sx, sy)
end

--- Desktop helper: dragging with the button held == sliding a finger.
function VirtualKeyboard.MouseMoved(sx, sy)
    return VirtualKeyboard.TouchMoved(MOUSE_TOUCH_ID, sx, sy)
end

function VirtualKeyboard.MouseReleased(sx, sy)
    return VirtualKeyboard.TouchReleased(MOUSE_TOUCH_ID, sx, sy)
end

----------------------------------------------------------------------
-- Drawing
----------------------------------------------------------------------

local function drawDisc(ctrl)
    local a = alphaOf(ctrl)
    local r = ctrl.r
    local cx, cy = ctrl.cx, ctrl.cy

    -- body + neutral centre. The hub is sized so its FLAT FACES land on the
    -- sectors' inner radius: an octagon inscribed at 0.26 would only reach
    -- 0.26 * cos(22.5deg) at the faces and leave a dark ring around the hub.
    setColor(VirtualKeyboard.baseColor, a)
    SE.graphics.draw(MESH.octagon, cx, cy, 0, r, r)
    setColor(VirtualKeyboard.idleColor, a * 0.75)
    local hub = r * HUB / APOTHEM
    SE.graphics.draw(MESH.octagon, cx, cy, 0, hub, hub)

    -- eight sectors -- the lit one is the whole face, no arrow needed
    for i = 0, 7 do
        local active = (i == ctrl.dir)
        if (active) then
            setColor(ctrl.color, clamp(a + 0.35, 0, 0.95))
        else
            setColor(VirtualKeyboard.idleColor, a)
        end
        SE.graphics.draw(MESH.wedge, cx, cy, i * STEP, r, r)
    end

    -- rim
    setColor(VirtualKeyboard.rimColor, clamp(a + 0.25, 0, 1))
    SE.graphics.draw(MESH.octRing, cx, cy, 0, r, r)

    -- dark outline just outside the octagon (per-control width wins)
    local ow = ctrl.outlineWidth or VirtualKeyboard.outlineWidth
    if (ow and ow > 0) then
        setColor(ctrl.outlineColor or VirtualKeyboard.outlineColor, clamp(a + 0.25, 0, 1))
        SE.graphics.draw(getOutlineMesh(r, ow), cx, cy, 0, 1, 1)
    end
end

local function drawIcon(ctrl, a)
    local r = ctrl.r
    local cx, cy = ctrl.cx, ctrl.cy
    setColor(VirtualKeyboard.iconColor, clamp(a + 0.30, 0, 1))
    if (ctrl.icon == "bars") then
        local bw, bh = r * 0.84, r * 0.15
        for i = -1, 1 do
            SE.graphics.draw(MESH.rect, cx, cy + i * r * 0.32, 0, bw, bh)
        end
    elseif (ctrl.icon == "move") then
        local s = r * 0.42
        for i = 0, 3 do
            SE.graphics.draw(MESH.arrow, cx, cy, i * QUARTER, s, s)
        end
    end
end

local function drawLabel(ctrl, a)
    local text = ctrl.label
    if (not text or text == "") then return end
    setColor(VirtualKeyboard.textColor, clamp(a + 0.35, 0, 1))
    -- shrink longer labels ("ESC", "BACKSPACE", ...) so they stay inside the rim
    local size = ctrl.r * 0.95
    local maxW = ctrl.r * 1.55
    while (size > 8 and textWidth(text, size) > maxW) do size = size - 1 end
    drawTextCentered(text, ctrl.cx, ctrl.cy, size)
end

local function drawButton(ctrl)
    local a = alphaOf(ctrl)
    local r = ctrl.r
    local cx, cy = ctrl.cx, ctrl.cy

    if (ctrl.pressed) then
        setColor(ctrl.color, clamp(a + 0.35, 0, 0.95))
    else
        -- idle body carries a hint of the accent color so Z/X/C stay telling
        setColor(mixColor(VirtualKeyboard.baseColor, ctrl.color, 0.35), a)
    end
    SE.graphics.draw(MESH.circle, cx, cy, 0, r, r)

    setColor(ctrl.color, clamp(a + 0.25, 0, 1))
    SE.graphics.draw(MESH.ring, cx, cy, 0, r, r)

    if (ctrl.icon) then
        drawIcon(ctrl, a)
    else
        drawLabel(ctrl, a)
    end
end

local function drawEditHint()
    local w = VirtualKeyboard.screenW or SE.graphics.getWidth()
    local size = 16
    local text = VirtualKeyboard.L("edit") .. " / " .. VirtualKeyboard.L("delete_hint")
    setColor({ 1, 1, 1 }, 0.9)
    drawText(text, (w - textWidth(text, size)) * 0.5, 12, size)
end

--- Draw the menu panel: a backing rect, the title and one row per entry.
local function drawMenu()
    local r = VirtualKeyboard.menuRect
    if (not r) then return end
    local pad = (VirtualKeyboard.menuItems[1] and VirtualKeyboard.menuItems[1].x - r.x) or 8

    -- panel: rim then body, both from the unit rect mesh
    setColor(VirtualKeyboard.rimColor, 0.85)
    SE.graphics.draw(MESH.rect, r.x + r.w * 0.5, r.y + r.h * 0.5, 0, r.w + 4, r.h + 4)
    setColor(VirtualKeyboard.baseColor, 0.96)
    SE.graphics.draw(MESH.rect, r.x + r.w * 0.5, r.y + r.h * 0.5, 0, r.w, r.h)

    local titleSize = math.max(12, (VirtualKeyboard.menuItems[1] and VirtualKeyboard.menuItems[1].h * 0.5) or 16)
    setColor(VirtualKeyboard.iconColor, 0.95)
    local title
    if (VirtualKeyboard.menuPage == "addkey") then
        local pages = math.max(1, math.ceil(#keyChoices / VirtualKeyboard.keysPerPage))
        title = VirtualKeyboard.L("pick_key") .. string.format("  %d/%d", VirtualKeyboard.keyPage + 1, pages)
    elseif (VirtualKeyboard.menuPage == "addpad") then
        title = VirtualKeyboard.L("pick_scheme")
    else
        title = VirtualKeyboard.deleteMode and VirtualKeyboard.L("delete_hint") or VirtualKeyboard.L("title")
    end
    drawText(title, r.x + (r.w - textWidth(title, titleSize)) * 0.5, r.y + pad * 0.5, titleSize)

    for _, item in ipairs(VirtualKeyboard.menuItems) do
        if (item.x) then
            setColor(VirtualKeyboard.idleColor, 0.9)
            SE.graphics.draw(MESH.rect, item.x + item.w * 0.5, item.y + item.h * 0.5, 0, item.w - 4, item.h - 4)

            local text = item.raw and item.label or VirtualKeyboard.L(item.label)
            -- shrink until the label fits its cell (key names get long)
            local fs = math.floor(item.h * 0.5)
            while (fs > 8 and textWidth(text, fs) > item.w - 8) do fs = fs - 1 end
            setColor(VirtualKeyboard.textColor, 0.98)
            local ty = item.y + item.h * 0.5 - fs * 0.6
            if (item.hint) then ty = item.y + item.h * 0.28 end
            drawText(text, item.x + (item.w - textWidth(text, fs)) * 0.5, ty, fs)

            if (item.hint) then
                local hs = math.max(8, math.floor(fs * 0.7))
                setColor(VirtualKeyboard.iconColor, 0.9)
                drawText(item.hint, item.x + (item.w - textWidth(item.hint, hs)) * 0.5,
                    item.y + item.h * 0.58, hs)
            end
        end
    end
end

local function drawToast()
    if (not VirtualKeyboard.toastText) then return end
    local now = (SE.timer and SE.timer.getTime) and SE.timer.getTime() or 0
    if (now > VirtualKeyboard.toastUntil) then
        VirtualKeyboard.toastText = nil
        return
    end
    local w = VirtualKeyboard.screenW or SE.graphics.getWidth()
    local h = VirtualKeyboard.screenH or SE.graphics.getHeight()
    local size = math.max(13, math.min(w, h) * 0.045)
    local tw = textWidth(VirtualKeyboard.toastText, size)
    setColor(VirtualKeyboard.baseColor, 0.85)
    SE.graphics.draw(MESH.rect, w * 0.5, h * 0.14, 0, tw + 24, size * 1.8)
    setColor(VirtualKeyboard.textColor, 0.98)
    drawText(VirtualKeyboard.toastText, w * 0.5 - tw * 0.5, h * 0.14 - size * 0.6, size)
end

local function drawDebugDisc(ctrl)
    local cx, cy, r = ctrl.cx, ctrl.cy, ctrl.r
    local outer = r * VirtualKeyboard.grabScale
    local inner = r * VirtualKeyboard.deadzone

    -- where a press is actually accepted
    setColor({ 0.30, 1.00, 0.45 }, 0.85)
    SE.graphics.draw(MESH.ring, cx, cy, 0, outer, outer)

    -- the 8 dividing lines, drawn all the way out to the grab radius
    setColor({ 1.00, 0.72, 0.20 }, 0.70)
    local len = outer - inner
    for i = 0, 7 do
        local a = (i + 0.5) * STEP
        local mx = cx + math.cos(a) * (inner + len * 0.5)
        local my = cy + math.sin(a) * (inner + len * 0.5)
        SE.graphics.draw(MESH.rect, mx, my, a, len, 3)
    end

    -- neutral centre
    setColor({ 1.00, 0.30, 0.35 }, 0.80)
    SE.graphics.draw(MESH.ring, cx, cy, 0, inner, inner)
end

local function drawDebugOverlay()
    for _, ctrl in ipairs(VirtualKeyboard.controls) do
        if (ctrl.enabled and ctrl.kind == "dpad") then drawDebugDisc(ctrl) end
    end

    local lp = VirtualKeyboard.lastPress
    if (lp) then
        setColor({ 1.00, 0.20, 0.60 }, 0.95)
        SE.graphics.draw(MESH.circle, lp.x, lp.y, 0, 7, 7)
    end

    local dpad = nil
    for _, ctrl in ipairs(VirtualKeyboard.controls) do
        if (ctrl.kind == "dpad") then dpad = ctrl break end
    end
    if (dpad) then
        setColor({ 1, 1, 1 }, 0.95)
        drawText(string.format("dir=%d  grab=%.2fr  hyst=%.0fdeg",
            dpad.dir, VirtualKeyboard.grabScale, math.deg(VirtualKeyboard.hysteresis)),
            dpad.cx - dpad.r, dpad.cy - dpad.r - 26, 18)
    end
end

function VirtualKeyboard.Draw()
    if (not VirtualKeyboard.enabled or not VirtualKeyboard.visible) then return end
    buildMeshes()

    for _, ctrl in ipairs(VirtualKeyboard.controls) do
        if (ctrl.enabled) then
            if (ctrl.kind == "dpad") then
                drawDisc(ctrl)
            else
                drawButton(ctrl)
            end
        end
    end

    if (VirtualKeyboard.deleteMode) then drawEditHint() end
    if (VirtualKeyboard.menuOpen) then drawMenu() end
    drawToast()
    if (VirtualKeyboard.debug) then drawDebugOverlay() end
    if (VirtualKeyboard.editMode) then drawEditHint() end

    -- Restore the colour before returning. This overlay is the LAST thing drawn
    -- in a frame and every control above paints with an alpha < 1, while LoEVE's
    -- default love.run does NOT reset the graphics state between frames (it only
    -- calls origin() + clear()). The colour left behind here therefore became the
    -- ambient colour of the NEXT frame -- and STI paints the tilemap with that
    -- ambient colour (Map.drawLayer -> lg.setColor(r, g, b, a * layer.opacity)),
    -- so a leaked tint made every map tile render translucent (once into STI's
    -- own map canvas, once again when that canvas is blitted back).
    SE.graphics.setColor(1, 1, 1, 1)
end

buildDefaultControls()

return VirtualKeyboard
