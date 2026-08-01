local anim = {
    running = true,
    x = 0,
    y = 0,
    elements = {}
}

-- Create the sprites.
function anim.Init()
    local mirror = Sprites.CreateSprite("Mascots/sincera.png", "UI")
    mirror:MoveTo(120, 140)
    mirror:Scale(-0.25, 0.25)
end

function anim.Update(dt)
    if (not anim.running) then
        return
    end

    -- Put your monster's animation code here.
    --===================>

    --<===================
end

-- Destroy the anim.
-- You can also use `sprite:Dust` function here.
function anim.Destroy()
    for i = #anim.elements, 1, -1
    do
        local e = anim.elements[i]
        if (e.Destroy) then
            e:Destroy()
        end
    end
end

return anim