--- GUI - UNDERTALE-style GUI library

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

GUI.COLORS = GUI.primitives.COLORS

return GUI
