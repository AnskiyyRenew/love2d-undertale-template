local world = {}

function world.Init()
    world.physics_world = SE.physics.newWorld(0, 0, true)
end

return world