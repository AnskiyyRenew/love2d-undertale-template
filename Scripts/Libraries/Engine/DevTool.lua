--[[
    Scripts/Libraries/Engine/DevTool.lua
    Developer tool V2 - standalone SDL child window (Tree variable browser + Console REPL)

    Depends on:
      Windows.lua (Scripts/Libraries/Utils/Windows.lua); requires LÖVE 12 (ships with SDL3).

    Usage (main.lua):
      DevTool = ImportFile("Engine.DevTool")        -- requiring it only registers the hooks
      -- in love.update:  DevTool.Update(dt)
      -- in love.draw:    DevTool.Draw()
      -- F8 opens/closes the window (dev builds only; call DevTool.Toggle() to do the same)
      -- The window stays closed until F8 is pressed once.

    [Tree] variable browser
      - Top-level roots: Player / Battle / Overworld / Scenes.current / Global(config) / _G(all)
      - Click a number/string leaf -> inline edit writes back to real engine memory
      - Click a boolean leaf -> toggles it; click a table node (or its arrow) -> expand/collapse
      - R rebuilds the selected node's children (refresh dynamic containers)
      - Quick edit bar on top: path = value read/write, e.g. Player.hp -> 999
    [Console] REPL
      - Sandbox evaluation (loadstring + setfenv) reading/writing engine globals
      - Supports expressions (Enter shows the result) and statements (e.g. Player.hp = 999)
      - Available variables: Player Battle Overworld Scenes Global _G

    Keyboard input notes:
      - The child window has no love.textinput, and SDL child-window keyboard events are
        unreliable in this LÖVE build (KF=YES still produced no input). Therefore keys are
        forwarded from the main window's love.keypressed and mapped from LÖVE key names.
      - Clicking the tool window requests OS keyboard focus (see KF:YES/NO top-right);
        if focus is never granted, keys are still forwarded while the mouse hovers the tool.
]]

local DevTool = {}

-- Windows native window library dependency (SDL3 child window + mouse/key events)
local window
do
    local ok, mod = pcall(require, "Scripts.Libraries.Utils.Windows")
    if ok and type(mod) == "table" then
        window = mod
    end
end
if not window then
    local ok2, mod2 = pcall(function() return ImportFile("Utils.Windows") end)
    if ok2 and type(mod2) == "table" then
        window = mod2
    end
end

-- ============================================================
-- Window / layout / theme parameters
-- ============================================================
local TOOL_W, TOOL_H   = 1280, 760
local PRESENT_INTERVAL = 1 / 30      -- readback throttle for the child-window present (30fps)
local ROW_H            = 20
local HEADER_H         = 26
local QUICK_TOP        = HEADER_H + 2
local QUICK_H          = 44
local LIST_TOP         = QUICK_TOP + QUICK_H + 3
local FOOTER_H         = 24
local LIST_BOTTOM      = TOOL_H - FOOTER_H - 3
local LIST_LEFT        = 4
local LIST_RIGHT       = TOOL_W - 4
local PAD_X            = 8
local MAX_CHILDREN     = 300
local MAX_DEPTH        = 26
local MAX_ROWS         = 40000

-- Console region (only relevant while the Tree mode hides the quick bar)
local CONSOLE_TOP      = HEADER_H + 4
local CONSOLE_INPUT_H  = 24

local COL = {
    bg     = { 0.071, 0.078, 0.102, 1 },
    panel  = { 0.106, 0.114, 0.149, 1 },
    row    = { 0.090, 0.098, 0.129, 1 },
    rowsel = { 0.176, 0.243, 0.361, 1 },
    border = { 0.165, 0.184, 0.231, 1 },
    text   = { 0.847, 0.871, 0.902, 1 },
    dim    = { 0.373, 0.400, 0.451, 1 },
    blue   = { 0.384, 0.710, 0.949, 1 },
    green  = { 0.592, 0.757, 0.471, 1 },
    orange = { 0.898, 0.753, 0.420, 1 },
    red    = { 0.851, 0.424, 0.463, 1 },
    purple = { 0.780, 0.471, 0.871, 1 },
    cyan   = { 0.341, 0.710, 0.690, 1 },
}

-- Top-level roots (read live from engine memory)
local rootDefs = {
    { name = "Player",         get = function() return _G.Player end },
    { name = "Battle",         get = function() return _G.Battle end },
    { name = "Overworld",      get = function() return _G.Overworld end },
    { name = "Scenes.current", get = function() return (Scenes and Scenes.current) end },
    { name = "Global (config)",   get = function() return _G.Global end },
    { name = "_G (all globals)",  get = function() return _G end },
}

-- ============================================================
-- State
-- ============================================================
DevTool.enabled     = false   -- start closed; the first F8 press opens the window
DevTool.win         = nil
DevTool.canvas      = nil
DevTool.font        = nil
DevTool.fontSmall   = nil
DevTool.lastPresent = 0
DevTool._failed     = false

DevTool.tab         = "tree"     -- "tree" | "console"
DevTool.headerTabs  = nil        -- tab geometry from the last drawn frame, used for click hits

DevTool.roots       = {}
DevTool.scrollY     = 0
DevTool.selected    = nil
DevTool.editor      = nil        -- { node=..., buffer=..., vtype=... }
DevTool.mouse       = { x = -1, y = -1 }
DevTool._clicks     = {}
DevTool._wheels     = {}
DevTool.view        = nil        -- tree layout generated by the last Draw
DevTool._err        = nil
DevTool.quick       = {
    focus = "path",              -- "path" | "value" | nil
    path  = "Player.hp",
    value = "",
    curType = "?",
    err = nil,
    layout = nil,
}

DevTool.console     = {
    lines   = {},                -- { text=..., color=..., }
    maxLines = 300,
    scroll  = 0,                 -- 0 = pinned at the bottom (newest)
    input   = "",
    focus   = true,
}

-- ============================================================
-- Basic helpers
-- ============================================================
local function addr(v)
    local ok, s = pcall(tostring, v)
    return (ok and s) or "?"
end

local function keyName(k)
    if type(k) == "string" then return k end
    return "[" .. tostring(k) .. "]"
end

-- Read a node's "live" value: roots use the getter, leaves read parent[key] (auto-refreshing)
local function nodeValue(node)
    if node.isRoot then
        local ok, v = pcall(node.get)
        return (ok and v) or nil
    end
    local p = node.parent
    if type(p) ~= "table" then return nil end
    local ok, v = pcall(function() return p[node.key] end)
    if ok then return v end
    return nil
end

-- Count table fields with an upper bound (avoid very long scans)
local function tableCount(t, cap)
    cap = cap or 999
    local n = 0
    local ok = pcall(function()
        for _ in pairs(t) do
            n = n + 1
            if n > cap then error("cap") end
        end
    end)
    return n, (ok == false)
end

local function valueText(live, vtype, maxLen)
    if vtype == "nil" then return "nil" end
    if vtype == "table" then
        local n, over = tableCount(live)
        return "table(" .. n .. (over and "+" or "") .. ")"
    elseif vtype == "function" then
        return "function"
    elseif vtype == "boolean" then
        return live and "true" or "false"
    elseif vtype == "number" then
        return tostring(live)
    elseif vtype == "string" then
        local s = live
        if #s > maxLen then s = s:sub(1, maxLen) .. "~" end
        return '"' .. s .. '"'
    elseif vtype == "userdata" then
        local ok, s = pcall(tostring, live)
        return (ok and s) or "userdata"
    elseif vtype == "thread" then
        return "thread"
    else
        return tostring(vtype)
    end
end

local function valueColor(vtype)
    if vtype == "nil" or vtype == "function" or vtype == "thread" then return COL.dim end
    if vtype == "table" then return COL.blue end
    if vtype == "boolean" then return COL.orange end
    if vtype == "string" then return COL.green end
    if vtype == "number" then return COL.text end
    if vtype == "userdata" then return COL.purple end
    return COL.dim
end

local function fitText(font, s, maxW)
    if font:getWidth(s) <= maxW then return s end
    local cw = math.max(1, font:getWidth("A"))
    local maxc = math.floor((maxW - cw * 0.5) / cw)
    if maxc < 2 then return "" end
    return s:sub(1, maxc - 1) .. "~"
end

-- ============================================================
-- Tree building (lazy expansion + cycle detection)
-- ============================================================
local function buildChildren(node)
    node.children = {}
    node.built = true
    local t = nodeValue(node)
    if type(t) ~= "table" then return end

    -- Ancestor set: addresses of every table from the root down to this node, for cycle detection
    local anc = {}
    if node.ancestors then
        for k in pairs(node.ancestors) do anc[k] = true end
    end
    anc[addr(t)] = true
    node.ancestors = anc

    local list = {}
    local okIter = pcall(function()
        for k, v in pairs(t) do
            if type(v) ~= "function" then
                list[#list + 1] = { k = k, v = v }
            end
        end
    end)
    if not okIter then return end

    table.sort(list, function(a, b)
        local ta, tb = type(a.k), type(b.k)
        if ta == "number" and tb == "number" then return a.k < b.k end
        if ta == "number" then return true end
        if tb == "number" then return false end
        if ta == tb and ta == "string" then return a.k < b.k end
        return ta < tb
    end)

    local count = #list
    node.overflow = (count > MAX_CHILDREN) and (count - MAX_CHILDREN) or nil
    local shown = math.min(count, MAX_CHILDREN)
    for i = 1, shown do
        local e = list[i]
        local vt = type(e.v)
        local child = {
            isRoot    = false,
            name      = keyName(e.k),
            key       = e.k,
            parent    = t,
            up        = node,          -- tree path (used to display the full path)
            kind      = vt,
            expanded  = false,
            built     = false,
            ancestors = anc,
            cyclic    = false,
        }
        if vt == "table" and anc[addr(e.v)] then
            child.cyclic = true
        end
        node.children[#node.children + 1] = child
    end
end

-- Refresh the top-level roots (auto-detect if a referenced object was swapped, e.g. scene switch)
local function refreshRoots()
    for i, def in ipairs(rootDefs) do
        local root = DevTool.roots[i]
        local ok, live = pcall(def.get)
        live = (ok and live) or nil
        local a = addr(live)
        if not root then
            root = {
                isRoot   = true,
                name     = def.name,
                get      = def.get,
                expanded = true,
                built    = false,
            }
            DevTool.roots[i] = root
        end
        root.live = live
        if root.built and root.builtAddr ~= a then
            root.children = nil
            root.built = false
        end
        root.builtAddr = a
    end
end

-- Produce a flat row list (used for drawing and clicking)
local function layoutRows()
    local rows = {}
    local function walk(node, depth)
        if #rows >= MAX_ROWS then return end
        local live = nodeValue(node)
        local vt   = type(live)
        local expandable = (vt == "table") and (not node.cyclic) and (depth < MAX_DEPTH)
        rows[#rows + 1] = {
            node       = node,
            depth      = depth,
            vtype      = vt,
            live       = live,
            expandable = expandable,
        }
        if expandable and node.expanded then
            if not node.built then buildChildren(node) end
            local children = node.children
            if children then
                for _, c in ipairs(children) do
                    walk(c, depth + 1)
                    if #rows >= MAX_ROWS then break end
                end
            end
        end
    end
    for _, root in ipairs(DevTool.roots) do walk(root, 0) end
    return rows
end

local function nodePath(node)
    local parts = {}
    local cur = node
    while cur do
        if cur.isRoot then
            table.insert(parts, 1, cur.name)
            break
        else
            table.insert(parts, 1, cur.name)
        end
        cur = cur.up
    end
    return table.concat(parts, ".")
end

-- ============================================================
-- Quick path parsing / writing
-- ============================================================
local function splitPath(p)
    local segs = {}
    local i, n = 1, #p
    while i <= n do
        local c = p:sub(i, i)
        if c == "." then
            i = i + 1
        elseif c == "[" then
            local j = p:find("]", i, true)
            if not j then break end
            local inner = p:sub(i + 1, j - 1)
            if inner:match("^%d+$") then
                segs[#segs + 1] = tonumber(inner)
            else
                segs[#segs + 1] = inner
            end
            i = j + 1
        else
            local j = i
            while j <= n and p:sub(j, j) ~= "." and p:sub(j, j) ~= "[" do j = j + 1 end
            local tok = p:sub(i, j - 1)
            if tok ~= "" then segs[#segs + 1] = tok end
            i = j
        end
    end
    return segs
end

-- Returns parent, lastKey, value; on failure returns nil,nil,nil,err
local function resolveSegs(segs)
    if #segs == 0 then return nil, nil, nil, "empty path" end
    local cur = _G
    local parent
    for i, k in ipairs(segs) do
        if type(cur) ~= "table" then
            return nil, nil, nil, "parent not table: " .. tostring(segs[i - 1])
        end
        local ok, v = pcall(function() return cur[k] end)
        if not ok then return nil, nil, nil, "read fail: " .. tostring(k) end
        parent = cur
        cur = v
    end
    return parent, segs[#segs], cur
end

local function fmtQuick(v)
    if v == nil then return "nil" end
    local t = type(v)
    if t == "number" or t == "boolean" then return tostring(v) end
    if t == "string" then return v end
    return ""
end

local function quickRead()
    local q = DevTool.quick
    local segs = splitPath(q.path)
    local parent, key, val, err = resolveSegs(segs)
    if err then
        q.curType = "?"
        q.value = ""
        q.err = err
        return
    end
    q.curType = type(val)
    q.value = fmtQuick(val)
    q.err = nil
    q.focus = "value"
end

local function quickSet()
    local q = DevTool.quick
    local segs = splitPath(q.path)
    local parent, key, val, err = resolveSegs(segs)
    if err then
        q.err = err
        return
    end
    local t = type(val)
    local newv
    if t == "number" then
        newv = tonumber(q.value)
        if newv == nil then q.err = "bad number" return end
    elseif t == "boolean" then
        newv = (q.value == "true" or q.value == "1" or q.value == "yes")
    elseif t == "string" then
        newv = q.value
    else
        q.err = "not writable: " .. tostring(t)
        return
    end
    local okWrite = pcall(function() parent[key] = newv end)
    q.err = okWrite and nil or "write fail"
    if okWrite then
        DevTool._err = nil
    end
end

-- ============================================================
-- Input helpers (key names -> characters)
-- ============================================================
local SHIFT_MAP = {
    ["1"] = "!", ["2"] = "@", ["3"] = "#", ["4"] = "$", ["5"] = "%",
    ["6"] = "^", ["7"] = "&", ["8"] = "*", ["9"] = "(", ["0"] = ")",
    ["-"] = "_", ["="] = "+", ["["] = "{", ["]"] = "}", ["\\"] = "|",
    [";"] = ":", ["'"] = '"', [","] = "<", ["."] = ">", ["/"] = "?",
    ["`"] = "~",
}

-- Apply the tree inline editor (Enter)
local function applyEditor()
    local e = DevTool.editor
    if not e then return end
    local node = e.node
    local p = node.parent
    if type(p) == "table" then
        local ok = true
        if e.vtype == "number" then
            local n = tonumber(e.buffer)
            if n == nil then
                ok = false
            else
                p[node.key] = n
            end
        elseif e.vtype == "string" then
            p[node.key] = e.buffer
        elseif e.vtype == "boolean" then
            p[node.key] = (e.buffer == "true" or e.buffer == "1")
        end
        if not ok then DevTool._err = "bad number: " .. tostring(e.buffer) end
    end
    DevTool.editor = nil
end

-- ============================================================
-- Console (REPL): sandbox evaluation
-- ============================================================
local function consoleAddLine(text, color)
    local c = DevTool.console
    c.lines[#c.lines + 1] = { text = tostring(text), color = color }
    while #c.lines > c.maxLines do
        table.remove(c.lines, 1)
    end
end

local function consoleRun()
    local c = DevTool.console
    local src = c.input
    c.input = ""
    if src == nil or src:match("^%s*$") then return end

    consoleAddLine("> " .. src, COL.cyan)

    -- Sandbox env: reads any global (__index = _G) but never pollutes _G itself
    local env = {}
    setmetatable(env, { __index = _G })

    -- Try parsing as an expression first (Enter prints the return value)
    local fn, err = loadstring("return " .. src, "=devtool")
    if not fn then
        fn, err = loadstring(src, "=devtool")
    end
    if not fn then
        consoleAddLine("! " .. tostring(err), COL.red)
        return
    end

    -- Capture print() output into the console
    env.print = function(...)
        local parts = {}
        for i = 1, select("#", ...) do
            local ok, s = pcall(tostring, (select(i, ...)))
            parts[i] = (ok and s) or "?"
        end
        consoleAddLine(table.concat(parts, "\t"), COL.text)
    end

    setfenv(fn, env)
    local ok, res = pcall(fn)
    if not ok then
        consoleAddLine("! " .. tostring(res), COL.red)
    elseif res ~= nil then
        consoleAddLine("= " .. tostring(res), COL.orange)
    end
end

-- ============================================================
-- Character mapping (LÖVE key names coming from main.lua love.keypressed)
-- Note: SDL child-window keyboard events are unreliable in this LÖVE build
-- (KF=YES still yielded no input), so keys are forwarded from the main window
-- by main.lua and mapped from LÖVE key names here.
-- ============================================================
local ASCII_BY_NAME = {
    ["space"] = " ", ["grave"] = "`", ["minus"] = "-", ["equals"] = "=",
    ["left bracket"] = "[", ["right bracket"] = "]", ["backslash"] = "\\",
    ["semicolon"] = ";", ["apostrophe"] = "'", ["comma"] = ",", ["period"] = ".",
    ["slash"] = "/",
}

local function loveKeyChar(name, shift)
    if not name then return nil end
    if #name == 1 then
        if name:match("%a") then
            return shift and string.upper(name) or name
        end
        if name:match("%d") then
            return shift and (SHIFT_MAP[name] or name) or name
        end
        return name
    end
    local base = ASCII_BY_NAME[name]
    if not base then return nil end
    if shift then
        if base:match("%a") then return string.upper(base) end
        return SHIFT_MAP[base] or base
    end
    return base
end

-- The current input sink: "console" / "editor" / "path" / "value" / nil
local function activeSink()
    if DevTool.tab == "console" then return "console" end
    if DevTool.editor then return "editor" end
    local f = DevTool.quick.focus
    if f == "path" or f == "value" then return f end
    return nil
end

local function insertChar(ch)
    if ch == nil or ch == "" then return end
    local s = activeSink()
    if s == "console" then
        DevTool.console.input = DevTool.console.input .. ch
    elseif s == "editor" then
        DevTool.editor.buffer = DevTool.editor.buffer .. ch
    elseif s == "path" then
        DevTool.quick.path = DevTool.quick.path .. ch
    elseif s == "value" then
        DevTool.quick.value = DevTool.quick.value .. ch
    end
end

local function backspaceSink()
    local s = activeSink()
    if s == "console" then
        DevTool.console.input = DevTool.console.input:sub(1, -2)
    elseif s == "editor" then
        DevTool.editor.buffer = DevTool.editor.buffer:sub(1, -2)
    elseif s == "path" then
        DevTool.quick.path = DevTool.quick.path:sub(1, -2)
    elseif s == "value" then
        DevTool.quick.value = DevTool.quick.value:sub(1, -2)
    end
end

---Whether main-window keys should be forwarded to the tool
---(the child window has focus, or the mouse is hovering over it).
function DevTool.WantsKeys()
    if not DevTool.enabled or not DevTool.win or not window then return false end
    local focused = false
    if window.SDLIsWindowFocused then
        focused = window.SDLIsWindowFocused(DevTool.win)
    end
    local hover = false
    if window.SDLHoveredWin then
        hover = (window.SDLHoveredWin() == DevTool.win)
    end
    return focused or hover
end

---Entry point forwarded from main.lua's love.keypressed (characters/controls/hotkeys unified).
---@param name string LÖVE key name (e.g. "a","return","backspace","period")
---@param isrepeat boolean whether this is an auto-repeat
---@param shift boolean whether Shift is held
function DevTool.HandleKey(name, isrepeat, shift)
    if not DevTool.enabled then return end
    if isrepeat then return end

    -- Control keys
    if name == "return" then
        if DevTool.tab == "console" then
            consoleRun()
            DevTool.console.scroll = 0
        elseif DevTool.editor then
            applyEditor()
        elseif DevTool.quick.focus == "path" then
            quickRead()
        elseif DevTool.quick.focus == "value" then
            quickSet()
        end
        return
    elseif name == "escape" then
        if DevTool.tab == "console" then
            DevTool.console.input = ""
        elseif DevTool.editor then
            DevTool.editor = nil
        elseif DevTool.quick.focus then
            DevTool.quick.focus = nil
        end
        return
    elseif name == "backspace" then
        backspaceSink()
        return
    elseif name == "tab" then
        if DevTool.tab ~= "console" and DevTool.quick.focus then
            DevTool.quick.focus = (DevTool.quick.focus == "path") and "value" or "path"
        end
        return
    end

    -- Printable characters (require an active input sink)
    local ch = loveKeyChar(name, shift)
    if ch and activeSink() then
        insertChar(ch)
        return
    end

    -- Hotkeys (Tree mode only, when no input sink is active)
    if DevTool.tab == "tree" and not activeSink() then
        if name == "r" then
            local sel = DevTool.selected
            if sel and not sel.isRoot and sel.built then
                sel.built = false
                sel.children = nil
                DevTool._err = nil
            end
        elseif name == "c" then
            DevTool.tab = "console"
            DevTool.editor = nil
            DevTool.quick.focus = nil
            DevTool.console.focus = true
        elseif name == "t" then
            DevTool.tab = "tree"
        end
    end
end

function DevTool._onMouseMotion(x, y, dx, dy)
    if not DevTool.enabled then return end
    DevTool.mouse.x, DevTool.mouse.y = x, y
end

function DevTool._onMouseButton(button, x, y, down, clicks)
    if not DevTool.enabled then return end
    if down and button == 1 then
        -- When clicking into the tool, request OS keyboard focus (see KF:Y/N top-right)
        if DevTool.win and window and window.SDLSetKeyboardFocus then
            pcall(window.SDLSetKeyboardFocus, DevTool.win)
        end
        DevTool._clicks[#DevTool._clicks + 1] = { button = button, x = x, y = y }
    end
end

function DevTool._onWheel(x, y)
    if not DevTool.enabled then return end
    if y ~= 0 then
        DevTool._wheels[#DevTool._wheels + 1] = y
    end
end

-- ============================================================
-- Click / wheel consumption (called from love.update)
-- ============================================================
local function hitRow(c)
    local v = DevTool.view
    if not v then return nil end
    local idx = math.floor((c.y - v.listTop + v.scrollY) / ROW_H) + 1
    if idx >= 1 and idx <= #v.rows then return v.rows[idx] end
    return nil
end

local function inRect(x, y, rx, ry, rw, rh)
    return x >= rx and x <= rx + rw and y >= ry and y <= ry + rh
end

-- Header tab clicks
local function handleHeaderClick(c)
    local tabs = DevTool.headerTabs
    if not tabs then return end
    for _, t in ipairs(tabs) do
        if inRect(c.x, c.y, t.x, t.y, t.w, t.h) then
            if t.name ~= DevTool.tab then
                if t.name == "console" then
                    DevTool.tab = "console"
                    DevTool.editor = nil
                    DevTool.quick.focus = nil
                    DevTool.console.focus = true
                else
                    DevTool.tab = "tree"
                    DevTool.quick.focus = DevTool.quick.focus or "path"
                end
                DevTool.selected = nil
            end
            return
        end
    end
end

-- Quick-edit bar clicks
local function handleQuickClick(c)
    local q = DevTool.quick
    local L = q.layout
    if not L then return end
    local fy = L.fieldY
    if c.y >= fy and c.y <= fy + L.fieldH then
        if inRect(c.x, c.y, L.pathX, fy, L.pathW, L.fieldH) then
            q.focus = "path"
        elseif inRect(c.x, c.y, L.readX, fy, L.btnW, L.fieldH) then
            q.focus = nil
            quickRead()
        elseif inRect(c.x, c.y, L.valueX, fy, L.valueW, L.fieldH) then
            q.focus = "value"
        elseif inRect(c.x, c.y, L.setX, fy, L.btnW2, L.fieldH) then
            q.focus = nil
            quickSet()
        end
    end
end

-- Tree area clicks
local function handleTreeClick(c)
    local row = hitRow(c)
    if not row then
        DevTool.selected = nil
        DevTool.editor = nil
        DevTool.quick.focus = nil
        return
    end
    local node = row.node
    DevTool.quick.focus = nil
    DevTool.selected = node

    local arrowW = 16
    local indentX = PAD_X + row.depth * 14
    if row.expandable and c.x <= indentX + arrowW then
        node.expanded = not node.expanded
        DevTool.editor = nil
        return
    end

    local vt = row.vtype
    if vt == "table" then
        if row.expandable then node.expanded = not node.expanded end
        DevTool.editor = nil
    elseif vt == "boolean" then
        local p = node.parent
        if type(p) == "table" then
            pcall(function() p[node.key] = not p[node.key] end)
        end
        DevTool.editor = nil
    elseif vt == "number" or vt == "string" then
        if type(node.parent) == "table" then
            DevTool.editor = { node = node, buffer = tostring(row.live), vtype = vt }
        end
    else
        DevTool.editor = nil
    end
end

local function handleClick(c)
    if c.y < HEADER_H then
        handleHeaderClick(c)
        return
    end
    if DevTool.tab == "console" then
        DevTool.console.focus = true
        return
    end
    if c.y >= LIST_TOP and c.y <= LIST_BOTTOM then
        handleTreeClick(c)
    else
        handleQuickClick(c)
    end
end

local function consumeInput()
    -- Wheel
    if DevTool.tab == "console" then
        for _, y in ipairs(DevTool._wheels) do
            DevTool.console.scroll = math.max(0, DevTool.console.scroll + y * 3)
        end
    else
        for _, y in ipairs(DevTool._wheels) do
            DevTool.scrollY = DevTool.scrollY - y * ROW_H * 2
        end
    end
    DevTool._wheels = {}

    -- Clamp the tree scroll offset
    if DevTool.tab ~= "console" and DevTool.view then
        local maxScroll = math.max(0, #DevTool.view.rows * ROW_H - (DevTool.view.listBottom - DevTool.view.listTop))
        DevTool.scrollY = math.max(0, math.min(DevTool.scrollY, maxScroll))
    end

    -- Clicks
    for _, c in ipairs(DevTool._clicks) do
        handleClick(c)
    end
    DevTool._clicks = {}
end

-- ============================================================
-- Window lifecycle
-- ============================================================
local function loadFonts()
    local ok1, f1 = pcall(SE.graphics.newFont, "Resources/Fonts/determination_mono.ttf", 15)
    DevTool.font = (ok1 and f1) or SE.graphics.newFont(15)
    local ok2, f2 = pcall(SE.graphics.newFont, "Resources/Fonts/determination_mono.ttf", 12)
    DevTool.fontSmall = (ok2 and f2) or SE.graphics.newFont(12)
end

local function openTool()
    if not window then
        print("[DevTool] Windows.lua / SDL3 not available.")
        DevTool._failed = true
        return
    end
    local win, err = window.CreateWindow({
        title  = "LOVE DevTool - Variable Tree / Console (F8)",
        width  = TOOL_W,
        height = TOOL_H,
    })
    if not win then
        print("[DevTool] open window failed: " .. tostring(err))
        DevTool._failed = true
        return
    end

    -- LÖVE 12 canvases are not readable by default; readable=true is required for readback to SDL
    local okC, canvas = pcall(SE.graphics.newCanvas, TOOL_W, TOOL_H, nil, { readable = true })
    if not okC or not canvas then
        print("[DevTool] create canvas failed; closing window.")
        window.DestroyWindowSDL(win)
        DevTool._failed = true
        return
    end

    DevTool.win = win
    DevTool.canvas = canvas
    loadFonts()

    -- Keyboard is forwarded from main.lua (SDL child-window key events are unreliable here)
    window.SDLSetMouseCallback(win, {
        motion = DevTool._onMouseMotion,
        button = DevTool._onMouseButton,
        wheel  = DevTool._onWheel,
    })

    DevTool.scrollY = 0
    DevTool.lastPresent = 0
    DevTool.selected = nil
    DevTool.editor = nil
    DevTool.view = nil
    DevTool._err = nil
    DevTool._clicks = {}
    DevTool._wheels = {}
    DevTool.tab = DevTool.tab or "tree"
    DevTool.console.input = ""
    DevTool.console.scroll = 0
    consoleAddLine("LOVE DevTool console V2 - sandbox", COL.dim)
    consoleAddLine("try: Player.hp = 999 | Player.hp | Battle.state | 1+2", COL.dim)
    refreshRoots()
    print("[DevTool] opened (F8 toggles).")
end

local function closeTool()
    if DevTool.win then
        pcall(window.DestroyWindowSDL, DevTool.win)
    end
    DevTool.win = nil
    DevTool.canvas = nil
    DevTool.view = nil
    DevTool._clicks = {}
    DevTool._wheels = {}
    print("[DevTool] closed.")
end

---Toggle the tool window (F8)
function DevTool.Toggle()
    if DevTool._failed then return end
    DevTool.enabled = not DevTool.enabled
end

-- ============================================================
-- Drawing
-- ============================================================
local function drawHeader(g)
    g.setColor(COL.panel)
    g.rectangle("fill", 0, 0, TOOL_W, HEADER_H)

    local ty = 3
    local th = HEADER_H - 6
    local tw = 64
    local tabs = {}
    local defs = { { "tree", "Tree" }, { "console", "Console" } }
    g.setFont(DevTool.fontSmall)
    for i, d in ipairs(defs) do
        local tx = PAD_X + (i - 1) * (tw + 6)
        local active = (DevTool.tab == d[1])
        g.setColor(active and COL.rowsel or COL.row)
        g.rectangle("fill", tx, ty, tw, th)
        g.setColor(COL.border)
        g.rectangle("line", tx, ty, tw, th)
        g.setColor(active and COL.cyan or COL.text)
        g.print(d[2], tx + 14, ty + 3)
        tabs[i] = { x = tx, y = ty, w = tw, h = th, name = d[1] }
    end
    DevTool.headerTabs = tabs

    g.setFont(DevTool.font)
    g.setColor(COL.text)
    g.print("LOVE DevTool V2", PAD_X + 2 * tw + 14, 4)

    g.setFont(DevTool.fontSmall)
    g.setColor(COL.dim)
    g.print("F8=toggle", TOOL_W - 170, 6)
    local focused = false
    if window and window.SDLIsWindowFocused and DevTool.win then
        focused = window.SDLIsWindowFocused(DevTool.win)
    end
    g.setColor(focused and COL.green or COL.dim)
    g.print(focused and "KF:YES" or "KF:NO", TOOL_W - 90, 6)
end

local function drawQuickBar(g)
    local q = DevTool.quick
    local fy = QUICK_TOP + 22
    local fieldH = 18

    g.setColor(COL.panel)
    g.rectangle("fill", 0, QUICK_TOP, TOOL_W, QUICK_H)

    g.setFont(DevTool.fontSmall)
    g.setColor(COL.dim)
    g.print("Quick edit [path] Enter=read -> [value] Enter=write | Tab=switch | Esc=exit | Shift=UPPER", PAD_X, QUICK_TOP + 4)

    local L = {
        pathX = PAD_X,            pathW = 300,
        readX = PAD_X + 300 + 8,  btnW = 46,
        valueX = PAD_X + 300 + 8 + 46 + 16, valueW = 300,
        setX = PAD_X + 300 + 8 + 46 + 16 + 300 + 8, btnW2 = 56,
        fieldY = fy, fieldH = fieldH,
    }
    q.layout = L

    local function drawBox(x, w, text, focused, textColor)
        g.setColor(COL.bg)
        g.rectangle("fill", x, fy, w, fieldH)
        g.setColor(focused and COL.cyan or COL.border)
        g.rectangle("line", x, fy, w, fieldH)
        g.setColor(textColor)
        g.setFont(DevTool.fontSmall)
        g.print(fitText(DevTool.fontSmall, text, w - 8), x + 4, fy + 3)
    end

    drawBox(L.pathX, L.pathW, q.path, q.focus == "path", COL.text)
    g.setColor(COL.rowsel); g.rectangle("fill", L.readX, fy, L.btnW, fieldH)
    g.setColor(COL.border); g.rectangle("line", L.readX, fy, L.btnW, fieldH)
    g.setColor(COL.blue);   g.print("Read", L.readX + 10, fy + 3)
    drawBox(L.valueX, L.valueW, q.value, q.focus == "value", COL.text)
    g.setColor(COL.rowsel); g.rectangle("fill", L.setX, fy, L.btnW2, fieldH)
    g.setColor(COL.border); g.rectangle("line", L.setX, fy, L.btnW2, fieldH)
    g.setColor(COL.green);  g.print("Set", L.setX + 12, fy + 3)

    g.setFont(DevTool.fontSmall)
    g.setColor(COL.orange)
    g.print("type=" .. tostring(q.curType), L.setX + L.btnW2 + 10, fy + 3)
    local errMsg = q.err or DevTool._err
    if errMsg then
        g.setColor(COL.red)
        g.print("ERR: " .. tostring(errMsg), L.setX + L.btnW2 + 130, fy + 3)
    end
end

local function drawRow(g, row, i, y)
    local node = row.node
    local isSel = (DevTool.selected == node)
    local isEdit = (DevTool.editor and DevTool.editor.node == node)

    if isSel or isEdit then
        g.setColor(COL.rowsel)
        g.rectangle("fill", LIST_LEFT, y, LIST_RIGHT - LIST_LEFT, ROW_H)
    elseif i % 2 == 0 then
        g.setColor(COL.row)
        g.rectangle("fill", LIST_LEFT, y, LIST_RIGHT - LIST_LEFT, ROW_H)
    end

    local indentX = PAD_X + row.depth * 14
    g.setFont(DevTool.font)

    g.setColor(COL.cyan)
    if row.expandable then
        local mark = node.expanded and "-" or "+"
        g.print(mark, indentX, y + 2)
    end

    local textX = indentX + 14
    local nameC = (row.vtype == "table") and COL.blue or COL.text
    g.setColor(nameC)
    local nameS = fitText(DevTool.font, node.name, 240)
    g.print(nameS, textX, y + 2)

    local vx = textX + DevTool.font:getWidth(nameS) + 6
    local vs = valueText(row.live, row.vtype, 70)
    g.setColor(valueColor(row.vtype))
    g.print(vs, vx, y + 2)

    if isEdit then
        g.setColor(COL.red)
        g.rectangle("fill", vx, y + ROW_H - 2, math.min(DevTool.font:getWidth(vs) + 2, 300), 1)
    end
    if isSel then
        g.setColor(COL.cyan)
        g.print(">", LIST_LEFT + 1, y + 2)
    end
end

local function drawTree(g)
    local rows = DevTool.view.rows
    local top, bot = DevTool.view.listTop, DevTool.view.listBottom
    for i, row in ipairs(rows) do
        local y = top - DevTool.view.scrollY + (i - 1) * ROW_H
        if y + ROW_H >= top and y <= bot then
            drawRow(g, row, i, y)
        end
    end
end

-- Console output area + input row
local function drawConsole(g)
    local c = DevTool.console
    local y0 = CONSOLE_TOP
    local inputTop = LIST_BOTTOM - CONSOLE_INPUT_H
    local y1 = inputTop - 4
    local inputY = inputTop + 3
    local rowH = 16

    -- Background
    g.setColor(COL.bg)
    g.rectangle("fill", 0, y0, TOOL_W, TOOL_H - FOOTER_H - y0)

    -- Output
    g.setFont(DevTool.fontSmall)
    local visible = math.floor((y1 - y0) / rowH)
    local count = #c.lines
    local top = math.max(0, count - visible - c.scroll)
    for i = top + 1, math.min(count, top + visible) do
        local ln = c.lines[i]
        local yy = y0 + (i - 1 - top) * rowH
        g.setColor(ln.color or COL.text)
        g.print(fitText(DevTool.fontSmall, ln.text, LIST_RIGHT - LIST_LEFT - 12), PAD_X + 2, yy)
    end

    -- Input row
    g.setColor(COL.panel)
    g.rectangle("fill", 0, inputY - 3, TOOL_W, CONSOLE_INPUT_H)
    g.setFont(DevTool.fontSmall)
    g.setColor(COL.dim)
    g.print(">>> ", PAD_X, inputY + 2)
    local caretX = PAD_X + 20 + DevTool.fontSmall:getWidth(c.input)
    g.setColor(COL.text)
    g.print(fitText(DevTool.fontSmall, c.input, LIST_RIGHT - LIST_LEFT - 120), PAD_X + 20, inputY + 2)
    if c.focus then
        g.setColor(COL.cyan)
        g.print("_", caretX, inputY + 2)
    end
    g.setColor(COL.dim)
    g.print("Enter=run | Esc=clear", LIST_RIGHT - 170, inputY + 2)
end

local function drawFooter(g)
    local y = LIST_BOTTOM + 3
    g.setColor(COL.panel)
    g.rectangle("fill", 0, LIST_BOTTOM, TOOL_W, TOOL_H - LIST_BOTTOM)

    g.setFont(DevTool.fontSmall)
    if DevTool.tab == "console" then
        g.setColor(COL.cyan)
        g.print("Console sandbox: Player/Battle/Overworld/Scenes/Global/_G | scroll=history", PAD_X, y + 2)
        g.setColor(COL.dim)
        g.print("C=console | T=tree", TOOL_W - 160, y + 2)
        return
    end

    if DevTool.editor then
        local e = DevTool.editor
        local p = nodePath(e.node)
        local msg = "EDIT [" .. p .. "] = " .. e.buffer
        g.setColor(COL.orange)
        g.print(msg, PAD_X, y + 2)
        g.setColor(COL.dim)
        local hintX = PAD_X + DevTool.fontSmall:getWidth(msg) + 16
        g.print("Enter=apply | Esc=cancel | Backspace=del", hintX, y + 2)
    else
        local sel = DevTool.selected
        local path = sel and nodePath(sel) or "-"
        g.setColor(COL.cyan)
        g.print("Sel: " .. path, PAD_X, y + 2)
        g.setColor(COL.dim)
        g.print("click num/str=edit | bool=toggle | R=rebuild | C=console | F8=toggle", 420, y + 2)
    end
    g.setColor(COL.red)
    if DevTool._err and not DevTool.quick.err then
        g.print("ERR: " .. tostring(DevTool._err), 900, y + 2)
    end
end

local function drawUI(g)
    g.clear(COL.bg[1], COL.bg[2], COL.bg[3], 1)
    drawHeader(g)

    if DevTool.tab == "console" then
        drawConsole(g)
        drawFooter(g)
        return
    end

    drawQuickBar(g)
    g.setFont(DevTool.font)
    drawTree(g)
    drawFooter(g)
end

local function drawInner()
    if not DevTool.win or not DevTool.canvas or not DevTool.font then return end
    refreshRoots()

    -- Tree mode: lay out before drawing (drawTree depends on DevTool.view for scroll/hit-testing)
    if DevTool.tab ~= "console" then
        local rows = layoutRows()
        DevTool.view = {
            rows       = rows,
            scrollY    = DevTool.scrollY,
            listTop    = LIST_TOP,
            listBottom = LIST_BOTTOM,
        }
    else
        DevTool.view = nil
    end

    local g = SE.graphics
    g.setCanvas(DevTool.canvas)
    local ok, err = pcall(drawUI, g)
    g.setCanvas()

    if not ok then
        DevTool._err = "Draw: " .. tostring(err)
    end

    DevTool.lastPresent = SE.timer.getTime()
    pcall(window.SDLPresentCanvas, DevTool.win, DevTool.canvas)
end

-- ============================================================
-- Main entry points (called from main.lua)
-- ============================================================
function DevTool.Update(dt)
    if DevTool._failed then return end
    local ok, err = pcall(function()
        if DevTool.enabled then
            if not DevTool.win then openTool() end
            if DevTool.win then
                if window and window.SDLIsClosePending and window.SDLIsClosePending(DevTool.win) then
                    DevTool.enabled = false
                    closeTool()
                else
                    consumeInput()
                end
            end
        else
            if DevTool.win then closeTool() end
        end
    end)
    if not ok then
        DevTool._err = "Update: " .. tostring(err)
    end
end

function DevTool.Draw()
    if DevTool._failed then return end
    if not DevTool.enabled or not DevTool.win or not DevTool.canvas then return end
    local now = SE.timer.getTime()
    if now - DevTool.lastPresent < PRESENT_INTERVAL then return end
    local ok, err = pcall(drawInner)
    if not ok then
        DevTool._err = "Draw: " .. tostring(err)
    end
end

return DevTool
