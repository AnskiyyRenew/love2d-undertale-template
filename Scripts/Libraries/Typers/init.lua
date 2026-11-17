local Typers = {
    _cc = {}
}

local path = (...):match("(.-)[^%.]+$")
Typers.NText = require(path .. "Typers.ntext")
Typers.EText = require(path .. "Typers.etext")
Typers.SText = require(path .. "Typers.stext")
Typers.InstText = require(path .. "Typers.insttext")

-- Lifetime of the default CC animation, in frames: the last tween writes its
-- final value on frame 123, so the rest is margin.
local CC_DEFAULT_LIFE = 125

-- Destroy a CC's InstText and drop it from the update list. Safe from inside a
-- CC's own anim_func: Typers.Update walks the list backwards.
local function cc_dispose(cc)
    if (not cc) then return end
    cc._dead = true
    if (cc.inst and cc.inst.Destroy) then
        cc.inst:Destroy()
    end
    for i = #Typers._cc, 1, -1 do
        if (Typers._cc[i] == cc) then
            table.remove(Typers._cc, i)
        end
    end
end

--- Remove one floating text created by CCAdd, destroying its InstText instance.
--- Custom anim_func CCs never end on their own, so call this when done.
function Typers.CCRemove(cc)
    cc_dispose(cc)
end

local function cc_default_anim(self)
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
    elseif (self.time >= CC_DEFAULT_LIFE) then
        cc_dispose(self)
    end
end

function Typers.CCAdd(text, x, y, layer, align, anim_func)
    local cc = {
        time = 0,
        inst = Typers.InstText.New(text, {x, y}, (layer or 0)),
        func = anim_func or cc_default_anim
    }
    cc.inst.alpha = 0
    cc.inst:SetAlign((align or "center"))

    table.insert(Typers._cc, cc)
    return cc
end

--- Width and height of the text a typer currently holds, as two numbers.
--- Works on any typer instance; `0, 0` when it holds no letters.
function Typers.GetLettersSize(typer)
    if (typer and typer.GetLettersSize) then
        return typer:GetLettersSize()
    end
    return 0, 0
end

function Typers.Update(dt)
    Typers.NText.Update(dt)
    Typers.EText.Update(dt)
    Typers.SText.Update(dt)

    for i = #Typers._cc, 1, -1
    do
        local c = Typers._cc[i]
        if (c and not c._dead) then
            c:func()
        else
            table.remove(Typers._cc, i)
        end
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

    -- Floating texts live in their own list, not InstText.insts. Destroy is
    -- idempotent, so entries already disposed above are no-ops here.
    for i = #Typers._cc, 1, -1 do
        local cc = Typers._cc[i]
        if (cc and cc.inst and cc.inst.Destroy) then
            cc.inst:Destroy()
        end
        table.remove(Typers._cc, i)
    end
end

return Typers
