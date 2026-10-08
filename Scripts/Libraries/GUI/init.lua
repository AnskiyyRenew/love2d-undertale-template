--[[
    GUI - UNDERTALE-style GUI library

    Components:
      GUI.Window      visual window (two stacked rectangles: thick border + fill)
      GUI.Label       text label (CJK/Latin mixed, wraps Typers.InstText)
      GUI.Button      button (selection prefix + yellow highlight; mouse hit area)
      GUI.Slider      horizontal value slider (track + knob; mouse drag + wheel)
      GUI.TextInput   single-line text field (blinking cursor; OS text input)
      GUI.Dropdown    dropdown menu (trigger button + expandable option list; up/down)
      GUI.Input       mouse input helper (screen->canvas coords, edge detection)
      GUI.primitives  low-level draw primitives (drawWindow / drawBorder / drawRect ...)

    Font convention (measured; only these sizes render crisp; see project memory):
      Latin  Resources/Fonts/determination_mono.ttf   size 27 or 13
      CJK    Resources/Fonts/simsun.ttc                size 13 (draw size 27 needs
                                                        scale=2; Typers.InstText
                                                        handles this in its bondfont)

    Coordinate convention: top-left (x,y) + size (w,h); Window:SetCenter switches
    to centre-point semantics. Layer defaults to 1000 (above battle elements);
    adjust with :SetLayer. Mouse coords are converted screen->canvas by GUI.Input
    (the engine draws onto a 640x480 canvas then scales it to the window; raw
    mouse coords are window space).

    Lifecycle: callers hold references and Destroy on scene clear; Layers.clear()
    stops external_draw rendering but Lua objects still need explicit Destroy to
    release InstText Text-cache references. TextInput.Focus enables OS text
    input; Blur / Destroy must disable it again.

    Loading: `GUI = ImportFile("GUI")` in main.lua, after Typers.
]]

local GUI = {}

local path = (...):match("(.-)[^%.]+$")
GUI.primitives  = require(path .. "GUI.primitives")
GUI.Window      = require(path .. "GUI.window")
GUI.Label       = require(path .. "GUI.label")
GUI.Button      = require(path .. "GUI.button")
GUI.Slider      = require(path .. "GUI.slider")
GUI.TextInput   = require(path .. "GUI.textinput")
GUI.Dropdown    = require(path .. "GUI.dropdown")
GUI.Input       = require(path .. "GUI.input")

-- Convenience alias for the default palette
GUI.COLORS = GUI.primitives.COLORS

return GUI
