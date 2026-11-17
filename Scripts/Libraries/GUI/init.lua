--[[
    GUI - UNDERTALE-style GUI library

    Components: Window (two stacked rects: thick border + fill), Label (mixed
    CJK/Latin, wraps Typers.InstText), Button, Slider, TextInput, Dropdown,
    Input (mouse screen->canvas + edge detection), primitives (drawWindow /
    drawBorder / drawRect ...).

    Font convention (only these sizes render crisp):
      Latin  determination_mono.ttf  size 27 or 13
      CJK    simsun.ttc              size 13 (size 27 needs scale=2, handled by
                                       InstText's bondfont)

    Coordinate convention: top-left (x,y) + size (w,h); Window:SetCenter switches
    to centre-point semantics. Layer defaults to 1000. Mouse coords are converted
    screen->canvas by GUI.Input (the engine draws onto a 640x480 canvas).

    Lifecycle: callers hold references and Destroy on scene clear (Layers.clear()
    only stops rendering; Destroy also releases InstText Text-cache references).
    TextInput.Focus enables OS text input; Blur / Destroy must disable it again.

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
