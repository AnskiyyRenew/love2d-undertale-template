--[[
    Scripts/Libraries/Engine/DevMode.lua
    In-game developer mode: type e-n-d to unlock, then jump between waves.
    Entry: Update / Draw / HandleKey / Mouse*; the scene below is paused while
    the panel is open. The overlay draws in 640x480 canvas space.
    Every label is a DevMode.* key from Localization/<lang>.json.
]]

-- Release build: dev-only tool, load nothing (see _RELEASED in conf.lua).
if (_RELEASED) then
    return {}
end

local devmode = {
    enabled = false,
    open = false,
    invincible = false,

    _seq = "",
    _seq_time = 0,

    _rows = {},
    _cursor = 1,
    _scroll = 1,
    _expanded = {},
    _hover = 0,
    _mouse = { x = 0, y = 0 },

    _scene = nil,
    _scene_pausing = false,

    _battle_fresh = false,
    _last_time_f = -1,

    _notice = nil,
    _notice_time = 0,
}

-- Localize is imported after this module, so the global is resolved per lookup;
-- keys live in the engine's Localization/<lang>.json, Game may override them.
---@param key string A DevMode.* key from the language files.
---@param formats table|string|nil Passed through to Localize.localizeText.
---@return string text The translation, or the key when Localize is unavailable.
local function L(key, formats)
    local l = rawget(_G, "Localize")
    if (type(l) ~= "table" or type(l.localizeText) ~= "function") then
        return key
    end

    local ok, text = pcall(l.localizeText, key, formats)
    if (ok and type(text) == "string" and text ~= "") then
        return text
    end
    return key
end

local PANEL = { x = 24, y = 18, w = 592, h = 444 }
local ROW_H = 22
local TITLE_Y = PANEL.y + 8
local INFO_Y = PANEL.y + 27
local LIST_Y = PANEL.y + 46
local LIST_H = 362
local HINT_Y = PANEL.y + PANEL.h - 26
local VISIBLE_ROWS = math.floor(LIST_H / ROW_H)
local ROW_X = PANEL.x + 12
local ROW_W = PANEL.w - 24

local COL = {
    fill      = { 0, 0, 0, 0.97 },
    dim       = { 0, 0, 0, 0.85 },
    title     = { 1, 1, 1 },
    info      = { 0.62, 0.62, 0.62 },
    folder    = { 1, 0.85, 0.35 },
    wave      = { 0.85, 0.85, 0.85 },
    current   = { 0.4, 1, 1 },
    hover     = { 1, 1, 1, 0.10 },
    cursor    = { 1, 1, 1, 0.22 },
    hint      = { 0.55, 0.55, 0.55 },
    notice    = { 1, 0.55, 0.45 },
    scrollbar = { 1, 1, 1, 0.35 },
}

-- The panel mixes CJK labels with ASCII wave names, so a string is split into
-- ASCII / non-ASCII runs drawn with determination_mono 13 and simsun 13.
local font_ascii, font_cjk

local function ensureFonts()
    if (font_ascii) then return end
    font_ascii = Fonts.New("determination_mono.ttf", 13)
    font_cjk = Fonts.New("simsun.ttc", 13)
    font_ascii:setFilter("nearest", "nearest")
    font_cjk:setFilter("nearest", "nearest")
end

--- Walk `str` and hand every run of same-width characters to `fn`.
---@param str string
---@param fn fun(segment: string, is_ascii: boolean)
local function eachSegment(str, fn)
    local i, n = 1, #str

    while (i <= n) do
        local is_ascii = str:byte(i) < 128
        local j = i

        while (j <= n) do
            local b = str:byte(j)
            if (b == nil) then break end
            if ((b < 128) ~= is_ascii) then break end
            j = j + (is_ascii and 1 or 3) -- UTF-8 CJK is 3 bytes
        end

        fn(str:sub(i, j - 1), is_ascii)
        i = j
    end
end

--- Width of `str` in pixels, mixed fonts included.
---@param str string
---@return number
local function textWidth(str)
    ensureFonts()
    local w = 0
    eachSegment(str, function (seg, is_ascii)
        w = w + (is_ascii and font_ascii or font_cjk):getWidth(seg)
    end)
    return w
end

--- Draw `str` at (x, y) with mixed fonts. Returns the drawn width.
---@param str string
---@param x number
---@param y number
---@param color table {r, g, b[, a]}
---@return number width
local function drawText(str, x, y, color)
    ensureFonts()
    SE.graphics.setColor(color[1], color[2], color[3], color[4] or 1)

    local cx = x
    eachSegment(str, function (seg, is_ascii)
        local font = is_ascii and font_ascii or font_cjk
        SE.graphics.setFont(font)
        SE.graphics.print(seg, math.floor(cx), math.floor(y))
        cx = cx + font:getWidth(seg)
    end)

    return cx - x
end

--- Draw `str` so that its right edge lands on `right`.
local function drawTextRight(str, right, y, color)
    return drawText(str, right - textWidth(str), y, color)
end

-- Same resolution order as the engine (Game area first, engine fallback). A
-- folder is a namespace: the module name is prefix .. "." .. relative path.
local WAVE_ROOTS = {
    { dir = "Game/Waves",    prefix = "Game.Waves",    labelKey = "DevMode.Root.Game" },
    { dir = "Scripts/Waves", prefix = "Scripts.Waves", labelKey = "DevMode.Root.Engine" },
}

local function listDir(path)
    local ok, items = pcall(function () return SE.filesystem.getDirectoryItems(path) end)
    if (not ok or type(items) ~= "table") then return {} end
    table.sort(items)
    return items
end

local function isDirectory(path)
    local ok, info = pcall(function () return SE.filesystem.getInfo(path) end)
    if (ok and type(info) == "table") then
        return info.type == "directory" or info.type == "dir"
    end

    -- No usable getInfo: a path that can be listed is a directory.
    local ok2, items = pcall(function () return SE.filesystem.getDirectoryItems(path) end)
    return (ok2 and type(items) == "table")
end

--- Append `dir`'s folders (recursing into open ones) and wave files to `rows`.
---@param rows table[]
---@param dir string Project-relative directory.
---@param rel string Wave-name prefix of `dir` ("" at the root).
---@param depth integer Indent level.
---@param prefix string Module prefix of the root ("Game.Waves").
local function collectRows(rows, dir, rel, depth, prefix)
    local folders, files = {}, {}

    for _, item in ipairs(listDir(dir)) do
        -- "_template.lua" and friends are scaffolding, not waves.
        if (item:sub(1, 1) ~= "." and item:sub(1, 1) ~= "_") then
            local full = dir .. "/" .. item
            if (isDirectory(full)) then
                table.insert(folders, item)
            elseif (item:sub(-4):lower() == ".lua") then
                table.insert(files, item)
            end
        end
    end

    for _, item in ipairs(folders) do
        local full = dir .. "/" .. item
        local sub_rel = (rel == "") and item or (rel .. "." .. item)
        local is_open = devmode._expanded[full] == true

        table.insert(rows, {
            kind = "folder", depth = depth, label = item, path = full, open = is_open,
        })

        if (is_open) then
            collectRows(rows, full, sub_rel, depth + 1, prefix)
        end
    end

    for _, item in ipairs(files) do
        local base = item:sub(1, -5) -- strip ".lua"
        local wave = (rel == "") and base or (rel .. "." .. base)

        table.insert(rows, {
            kind = "wave",
            depth = depth,
            label = base,
            wave = wave,
            module = prefix .. "." .. wave,
            file = dir .. "/" .. item,
        })
    end
end

--- Rebuild the visible row list from the expanded-folder state.
function devmode.Rebuild()
    local rows = {}

    for _, root in ipairs(WAVE_ROOTS) do
        local is_open = devmode._expanded[root.dir] == true

        table.insert(rows, {
            kind = "folder", depth = 0, label = L(root.labelKey), path = root.dir, open = is_open,
        })

        if (is_open) then
            collectRows(rows, root.dir, "", 1, root.prefix)
        end
    end

    devmode._rows = rows

    local max_scroll = math.max(1, #rows - VISIBLE_ROWS + 1)
    devmode._scroll = math.min(math.max(devmode._scroll, 1), max_scroll)
    devmode._cursor = math.min(math.max(devmode._cursor, 1), math.max(1, #rows))
end

--- True when a battle scene is the one currently running.
--- Either the scene name contains "battle", or Battle.TIME_F advanced (tracked
--- in Update, frozen while the panel is open so a paused battle still counts).
---@return boolean
local function battleReady()
    if (type(Battle) ~= "table") then
        return false
    end
    if (type(Battle.game) ~= "table" or type(Battle.game.enemies) ~= "table") then
        return false
    end

    local current = tostring(Scenes and Scenes.name_current or "")
    if (current:lower():find("battle", 1, true)) then
        return true
    end

    return devmode._battle_fresh == true
end

--- Why the running battle cannot be driven from here, or nil when it can.
--- `Battle` outlives the scene, so a stale Battle may lack the debug entries;
--- callers report this reason verbatim.
---@param entry string "DebugJumpWave" or "DebugEndWave"
---@return string|nil
local function entryMissing(entry)
    if (type(Battle) ~= "table") then
        return L("DevMode.Error.BattleMissing")
    end
    if (type(Battle[entry]) ~= "function") then
        return L("DevMode.Error.EntryMissing", { entry })
    end
    return nil
end

--- Current wave name, or nil outside a battle.
---@return string|nil
local function currentWave()
    if (type(Battle) ~= "table") then return nil end
    return Battle.wave
end

function devmode.Notify(text)
    devmode._notice = tostring(text)
    devmode._notice_time = 2.5
    print("[DevMode] " .. devmode._notice)
end

--- Expand every folder leading to the wave that is loaded right now, so the
--- panel opens where the tester left off.
local function revealCurrent()
    local wave = currentWave()
    if (not wave) then return end

    local module = (type(Battle) == "table") and Battle.waveModule or nil
    local root_dir, rel = nil, nil

    if (type(module) == "string") then
        for _, root in ipairs(WAVE_ROOTS) do
            local head = root.prefix .. "."
            if (module:sub(1, #head) == head) then
                root_dir, rel = root.dir, module:sub(#head + 1)
                break
            end
        end
    end

    if (not root_dir) then
        -- Not loaded yet: assume the Game area, the engine probes it first.
        root_dir, rel = WAVE_ROOTS[1].dir, wave
    end

    devmode._expanded[root_dir] = true

    local path = root_dir
    local parts = {}
    for part in tostring(rel):gmatch("[^%.]+") do
        table.insert(parts, part)
    end

    -- Every part but the last is a folder of the wave's namespace.
    for i = 1, #parts - 1 do
        path = path .. "/" .. parts[i]
        devmode._expanded[path] = true
    end
end

local function scrollToCursor()
    if (devmode._cursor < devmode._scroll) then
        devmode._scroll = devmode._cursor
    elseif (devmode._cursor > devmode._scroll + VISIBLE_ROWS - 1) then
        devmode._scroll = devmode._cursor - VISIBLE_ROWS + 1
    end
end

--- Move the cursor, clamped to the row list, and keep it on screen.
---@param index integer
function devmode.SetCursor(index)
    local rows = devmode._rows
    if (#rows == 0) then return end
    devmode._cursor = math.min(math.max(index, 1), #rows)
    scrollToCursor()
end

--- Put the cursor on the row whose path is `path` (used after expanding a folder).
local function focusPath(path)
    for i, row in ipairs(devmode._rows) do
        if (row.path == path) then
            devmode.SetCursor(i)
            return
        end
    end
end

local function jumpTo(row)
    if (not battleReady()) then
        devmode.Notify(L("DevMode.Error.NoBattleJump"))
        return
    end
    local missing = entryMissing("DebugJumpWave")
    if (missing) then
        devmode.Notify(missing)
        return
    end

    local ok, err = Battle.DebugJumpWave(row.wave)
    if (ok) then
        devmode.Close()
    else
        devmode.Notify(L("DevMode.Error.JumpFailed", { tostring(err) }))
    end
end

local function endWave()
    if (not battleReady()) then
        devmode.Notify(L("DevMode.Error.NoBattle"))
        return
    end
    local missing = entryMissing("DebugEndWave")
    if (missing) then
        devmode.Notify(missing)
        return
    end

    if (Battle.DebugEndWave()) then
        devmode.Notify(L("DevMode.WaveEnded"))
        devmode.Close()
    else
        devmode.Notify(L("DevMode.Error.NotEnemyTurn"))
    end
end

--- Activate a row: folders toggle, waves are jumped to.
---@param row table|nil
function devmode.ActivateRow(row)
    if (not row) then return end

    if (row.kind == "folder") then
        devmode._expanded[row.path] = not (devmode._expanded[row.path] == true)
        devmode.Rebuild()
        focusPath(row.path)
    else
        jumpTo(row)
    end
end

local function toggleFolder(open)
    local row = devmode._rows[devmode._cursor]
    if (not row or row.kind ~= "folder") then return end
    devmode._expanded[row.path] = open
    devmode.Rebuild()
    focusPath(row.path)
end

--- Keep Player.Hurt wrapped while developer mode is on, so invincible can veto
--- damage at the source (a lethal hit would kill before a heal could undo it).
local function ensureHurtHook()
    if (type(Player) ~= "table" or type(Player.Hurt) ~= "function") then return end
    if (Player._devmode_hurt) then return end

    local original = Player.Hurt
    Player._devmode_hurt = original
    Player.Hurt = function (amount, time, use_sound)
        if (devmode.invincible) then return end
        return original(amount, time, use_sound)
    end
end

function devmode.ToggleInvincible()
    devmode.invincible = not devmode.invincible
    devmode.Notify(L("DevMode.Invincible", {
        devmode.invincible and L("DevMode.On") or L("DevMode.Off")
    }))
end

--- Open the panel. The running scene is paused underneath it.
---@return boolean opened
function devmode.Open()
    if (devmode.open) then return true end

    devmode.Rebuild()
    revealCurrent()
    devmode.Rebuild()

    -- Cursor on the wave that is playing, else on the first wave row.
    local wave = currentWave()
    local found = false
    if (wave) then
        for i, row in ipairs(devmode._rows) do
            if (row.kind == "wave" and row.wave == wave) then
                devmode._cursor = i
                found = true
                break
            end
        end
    end
    if (not found) then
        for i, row in ipairs(devmode._rows) do
            if (row.kind == "wave") then
                devmode._cursor = i
                break
            end
        end
    end
    scrollToCursor()

    devmode._hover = 0
    devmode._scene = Scenes.current
    devmode._scene_pausing = (devmode._scene and devmode._scene.pausing) or false
    if (devmode._scene) then
        devmode._scene.pausing = true
    end

    devmode.open = true
    print("[DevMode] wave picker opened (" .. tostring(#devmode._rows) .. " rows)")
    return true
end

function devmode.Close()
    if (not devmode.open) then return end

    if (devmode._scene and Scenes.current == devmode._scene) then
        devmode._scene.pausing = devmode._scene_pausing
    end
    devmode._scene = nil
    devmode.open = false
end

function devmode.Toggle()
    devmode.enabled = not devmode.enabled

    if (devmode.enabled) then
        print("[DevMode] developer mode ON")
        print("[DevMode]   e-n-d again = lock | F10 = wave picker | S = end turn | I = invincible")
        -- Only open by itself inside a battle: pausing the overworld on a key
        -- sequence would be a surprise. F10 opens the panel anywhere.
        if (battleReady()) then
            devmode.Open()
        else
            print("[DevMode] no battle loaded: F10 opens the panel")
        end
    else
        devmode.Close()
        print("[DevMode] developer mode OFF")
    end
end

local SEQUENCE = "end"
local SEQ_TIMEOUT = 1.5

local function hasModifier()
    for _, key in ipairs({ "lctrl", "rctrl", "lalt", "ralt", "lgui", "rgui" }) do
        local ok, down = pcall(function () return love.keyboard.isDown(key) end)
        if (ok and down) then return true end
    end
    return false
end

local function textInputActive()
    local ok, active = pcall(function () return love.keyboard.hasTextInput() end)
    return (ok and active) and true or false
end

local function trackSequence(key)
    if (hasModifier() or textInputActive()) then
        devmode._seq = ""
        return
    end

    if (#key ~= 1 or not key:match("^%a$")) then
        devmode._seq = ""
        return
    end

    local now = SE.timer.getTime()
    if (now - devmode._seq_time > SEQ_TIMEOUT) then
        devmode._seq = ""
    end
    devmode._seq_time = now

    local candidate = devmode._seq .. key:lower()
    if (SEQUENCE:sub(1, #candidate) == candidate) then
        devmode._seq = candidate
        if (candidate == SEQUENCE) then
            devmode._seq = ""
            devmode.Toggle()
        end
    else
        -- Wrong letter: only restart the buffer when it is the first one.
        devmode._seq = (key:lower() == SEQUENCE:sub(1, 1)) and key:lower() or ""
    end
end

--- List navigation keys. Returns true when the key was consumed.
---@param key string
---@return boolean
local function navigate(key)
    if (key == "down") then
        devmode.SetCursor(devmode._cursor + 1)
    elseif (key == "up") then
        devmode.SetCursor(devmode._cursor - 1)
    elseif (key == "pagedown") then
        devmode.SetCursor(devmode._cursor + VISIBLE_ROWS)
    elseif (key == "pageup") then
        devmode.SetCursor(devmode._cursor - VISIBLE_ROWS)
    elseif (key == "home") then
        devmode.SetCursor(1)
    elseif (key == "end") then
        devmode.SetCursor(#devmode._rows)
    elseif (key == "return" or key == "kpenter" or key == "space") then
        devmode.ActivateRow(devmode._rows[devmode._cursor])
    elseif (key == "right") then
        toggleFolder(true)
    elseif (key == "left") then
        toggleFolder(false)
    else
        return false
    end

    return true
end

--- love.keypressed hook. Returns true when the key belongs to the overlay and
--- must not reach the scene below.
---@param key string
---@param isrepeat boolean|nil
---@return boolean consumed
function devmode.HandleKey(key, isrepeat)
    if (devmode.open) then
        if (isrepeat) then
            return navigate(key)
        end

        if (key == "f10" or key == "escape") then
            devmode.Close()
            return true
        end

        -- e-n-d also works inside the panel: it locks the mode and closes
        -- everything, the only way out that does not need F10.
        if (#key == 1 and key:match("^%a$")) then
            trackSequence(key)
            if (not devmode.open) then return true end
        end

        if (navigate(key)) then return true end

        if (key == "s") then endWave(); return true end
        if (key == "i") then devmode.ToggleInvincible(); return true end

        -- Swallow everything else: the battle below must not act on it.
        return true
    end

    if (key == "f10") then
        if (devmode.enabled) then
            devmode.Open()
            return true
        end
        print("[DevMode] wave picker is locked (type end first)")
        return false
    end

    trackSequence(key)
    return false
end

local function rowAt(cx, cy)
    if (cx < PANEL.x or cx > PANEL.x + PANEL.w) then return nil end
    if (cy < LIST_Y or cy > LIST_Y + LIST_H) then return nil end

    local index = devmode._scroll + math.floor((cy - LIST_Y) / ROW_H)
    return devmode._rows[index], index
end

--- love.mousepressed hook. Swallows every click while the panel is up.
---@return boolean consumed
function devmode.MousePressed(x, y, button)
    if (not devmode.open) then return false end
    if (button ~= 1) then return true end

    local cx, cy = GUI.Input.ScreenToCanvas(x, y)
    local row, index = rowAt(cx, cy)

    if (row) then
        devmode._cursor = index
        devmode.ActivateRow(row)
    end

    return true
end

--- love.mousereleased hook.
---@return boolean consumed
function devmode.MouseReleased()
    return devmode.open
end

--- love.mousemoved hook.
---@return boolean consumed
function devmode.MouseMoved(x, y)
    if (not devmode.open) then return false end
    local cx, cy = GUI.Input.ScreenToCanvas(x, y)
    devmode._mouse.x, devmode._mouse.y = cx, cy
    return false
end

--- love.wheelmoved hook.
---@return boolean consumed
function devmode.WheelMoved(_, y)
    if (not devmode.open) then return false end

    local rows = devmode._rows
    local max_scroll = math.max(1, #rows - VISIBLE_ROWS + 1)
    devmode._scroll = math.min(math.max(devmode._scroll - y, 1), max_scroll)
    return true
end

function devmode.Update(dt)
    if (devmode.enabled) then
        ensureHurtHook()
    end

    -- Battle.TIME_F only advances while a battle drives it, so it separates "old
    -- Battle table" from "battle running". Skipped while the panel is open,
    -- where the scene is paused on purpose.
    if (not devmode.open) then
        if (type(Battle) == "table" and type(Battle.TIME_F) == "number") then
            devmode._battle_fresh = (Battle.TIME_F ~= devmode._last_time_f)
            devmode._last_time_f = Battle.TIME_F
        else
            devmode._battle_fresh = false
            devmode._last_time_f = -1
        end
    end

    if (devmode._notice) then
        devmode._notice_time = devmode._notice_time - dt
        if (devmode._notice_time <= 0) then
            devmode._notice = nil
        end
    end

    if (not devmode.open) then return end

    -- A scene switch under the panel would leave the old scene paused forever.
    if (Scenes.current ~= devmode._scene) then
        devmode.Close()
        return
    end

    -- Cursor position is read every frame: mousemoved may never fire (it does not
    -- when the OS scales the window).
    local sx, sy = SE.mouse.getPosition()
    devmode._mouse.x, devmode._mouse.y = GUI.Input.ScreenToCanvas(sx, sy)

    local _, index = rowAt(devmode._mouse.x, devmode._mouse.y)
    devmode._hover = index or 0
end

function devmode.Draw()
    if (not devmode.open) then return end
    ensureFonts()

    local main_color = Global.GetVariable("MainColor") or { 1, 1, 1 }
    local rows = devmode._rows

    SE.graphics.setColor(COL.dim)
    SE.graphics.rectangle("fill", 0, 0, 640, 480)

    SE.graphics.setColor(COL.fill)
    SE.graphics.rectangle("fill", PANEL.x, PANEL.y, PANEL.w, PANEL.h)
    SE.graphics.setColor(main_color[1], main_color[2], main_color[3], 1)
    SE.graphics.setLineWidth(2)
    SE.graphics.rectangle("line", PANEL.x, PANEL.y, PANEL.w, PANEL.h)

    -- Title + live battle state
    drawText(L("DevMode.Title"), ROW_X, TITLE_Y, COL.title)
    local state_text = L("DevMode.State.Wave") .. " " .. tostring(currentWave() or "-") ..
        "   " .. L("DevMode.State.State") .. " " ..
        tostring((type(Battle) == "table") and Battle.state or "-") ..
        (devmode.invincible and ("   " .. L("DevMode.State.Invincible")) or "")
    drawTextRight(state_text, PANEL.x + PANEL.w - 12, TITLE_Y, COL.info)

    drawText(L("DevMode.Info"), ROW_X, INFO_Y, COL.info)

    -- Row list
    SE.graphics.setScissor(PANEL.x + 2, LIST_Y, PANEL.w - 4, LIST_H)
    for i = 1, VISIBLE_ROWS do
        local index = devmode._scroll + i - 1
        local row = rows[index]
        if (not row) then break end

        local y = LIST_Y + (i - 1) * ROW_H

        if (index == devmode._cursor) then
            SE.graphics.setColor(COL.cursor)
            SE.graphics.rectangle("fill", ROW_X - 4, y, ROW_W, ROW_H - 1)
        elseif (index == devmode._hover) then
            SE.graphics.setColor(COL.hover)
            SE.graphics.rectangle("fill", ROW_X - 4, y, ROW_W, ROW_H - 1)
        end

        local indent = ROW_X + row.depth * 14
        local base_y = y + 4

        if (row.kind == "folder") then
            drawText(row.open and "[-] " or "[+] ", indent, base_y, COL.folder)
            drawText(row.label, indent + textWidth("[-] "), base_y, COL.folder)
        else
            local is_current = (row.wave == currentWave())
            drawText(is_current and "* " or "  ", indent, base_y, COL.current)
            drawText(row.label, indent + textWidth("  "), base_y,
                is_current and COL.current or COL.wave)

            -- Inside a namespace the leaf name alone is ambiguous, so the full
            -- wave name an encounter would use is repeated on the right.
            if (row.depth > 1) then
                drawTextRight(row.wave, PANEL.x + PANEL.w - 12, base_y,
                    is_current and COL.current or COL.hint)
            end
        end
    end

    SE.graphics.setScissor()

    -- Scrollbar (only when the list overflows)
    if (#rows > VISIBLE_ROWS) then
        local track_h = LIST_H - 4
        local bar_h = math.max(16, track_h * VISIBLE_ROWS / #rows)
        local max_scroll = math.max(1, #rows - VISIBLE_ROWS)
        local bar_y = LIST_Y + 2 + (track_h - bar_h) * (devmode._scroll - 1) / max_scroll

        SE.graphics.setColor(COL.scrollbar)
        SE.graphics.rectangle("fill", PANEL.x + PANEL.w - 8, bar_y, 3, bar_h)
    end

    -- Footer: live notice (errors, jump results) or the key hints
    local footer
    if (devmode._notice) then
        footer = devmode._notice
        drawText(footer, ROW_X, HINT_Y, COL.notice)
    else
        drawText(L("DevMode.Hint", {
            devmode.invincible and L("DevMode.On") or L("DevMode.Off")
        }), ROW_X, HINT_Y, COL.hint)
    end

    -- Row count on the right of the footer
    drawTextRight("#" .. tostring(#rows), PANEL.x + PANEL.w - 12, HINT_Y, COL.hint)

    SE.graphics.setColor(1, 1, 1, 1)
    SE.graphics.setLineWidth(1)
end

return devmode
