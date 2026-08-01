local scene = {}

local bones = ImportFile("Attacks.Bones")
local bone = bones.New2D("sans", 60, {640, 240}, 0, {0, 0})
bone:SetPivot(0, 0.5)

function scene.update(dt)
    bones.Update(dt)

    --bone.rotation = bone.rotation + 1
end

function scene.draw()
end

function scene.clear()
    Layers.clear()
end

return scene