local Typers = {
    _cc = {}
}

local path = (...):match("(.-)[^%.]+$")
Typers.NText = require(path .. "Typers.ntext")
Typers.EText = require(path .. "Typers.etext")
Typers.SText = require(path .. "Typers.stext")
Typers.InstText = require(path .. "Typers.insttext")

function Typers.CCAdd(text, x, y, layer, align, anim_func)
    local cc = {
        time = 0,
        inst = Typers.InstText.New(text, {x, y}, (layer or 0)),
        func = anim_func or (function(self)
            self.time = self.time + 1
            if (self.time == 1) then
                Tween.CreateTween(function (v)
                    self.inst.alpha = v
                end, "Linear", "", 0, 1, 40)
                Tween.CreateTween(function (v)
                    self.inst.alpha = v
                end, "Linear", "", 1, 0, 40, 70)
                Tween.CreateTween(function (v)
                    self.inst.y = v
                end, "Quad", "Out", self.inst.y, self.inst.y - 30, 50)
                Tween.CreateTween(function (v)
                    self.inst.y = v
                end, "Quad", "In", self.inst.y - 30, self.inst.y - 60, 50, 70)
            end
        end)
    }
    cc.inst.alpha = 0
    cc.inst:SetAlign((align or "center"))

    table.insert(Typers._cc, cc)
    return cc
end

function Typers.Update(dt)
    Typers.NText.Update(dt)
    Typers.EText.Update(dt)
    Typers.SText.Update(dt)

    for i = #Typers._cc, 1, -1
    do
        local c = Typers._cc[i]
        c:func()
    end
end

--- Destroy all active typer instances across all modules.
function Typers.ClearAll()
    local modules = {Typers.NText, Typers.EText, Typers.SText, Typers.InstText}
    for _, mod in ipairs(modules) do
        if (mod and mod.insts) then
            for i = #mod.insts, 1, -1 do
                local typer = mod.insts[i]
                if (typer and typer.Destroy) then
                    typer:Destroy()
                end
            end
            mod.insts = {}
        end
    end
end

return Typers