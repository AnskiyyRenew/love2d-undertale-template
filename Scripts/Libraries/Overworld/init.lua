local path = (...):match("(.-)[^%.]+$")
local overworld = {
    map = require(path .. "Overworld.map"),
    world = require(path .. "Overworld.world"),
    inst = {},

    debug = false,
}

Layers.new_layer("Background", -100)
Layers.new_layer("Map", 0)
Layers.new_layer("BelowPlayer", 49)
Layers.new_layer("Player", 50)
Layers.new_layer("UponPlayer", 51)
Layers.new_layer("TOP", 100)
Layers.new_layer("DEBUG", 200)

Overworld = overworld
Map = overworld.map
World = overworld.world

local blacktop = Sprites.CreateSprite("px.png", "TOP")
blacktop:Scale(1000, 1000)
blacktop.color = {0, 0, 0}
blacktop:MoveTo(Camera.x, Camera.y)
blacktop._decay = true
blacktop.Step = function (self)
    if (self._decay) then
        self.alpha = self.alpha - 0.05
        if (self.alpha <= 0) then
            self._decay = false
        end
    else
        if (self.alpha >= 1) then
            self._decay = true
        end
    end
end

function overworld.Init(lua_file)
    overworld.map.Init(lua_file)
end

function overworld.SetMusic(mpath)
    if (not Audio.FindMusic(mpath)) then
        local mus
        mus, overworld.inst = Audio.PlayMusic(mpath)
    end
end

function overworld.Update(dt)
    overworld.map.Update(dt)
end

function overworld.Draw()
    
end

function overworld.Clear()
    
end

return overworld