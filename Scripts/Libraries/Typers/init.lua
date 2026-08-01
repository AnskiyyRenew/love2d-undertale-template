local Typers = {}

local path = (...):match("(.-)[^%.]+$")
Typers.NText = require(path .. "Typers.ntext")
Typers.EText = require(path .. "Typers.etext")
Typers.SText = require(path .. "Typers.stext")
Typers.InstText = require(path .. "Typers.insttext")

function Typers.Update(dt)
    Typers.NText.Update(dt)
    Typers.EText.Update(dt)
    Typers.SText.Update(dt)
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