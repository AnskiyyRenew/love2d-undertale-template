local anim = {
    running = true,
    x = 0,
    y = 0,

    mode = 1,
    elements = {},

    rotating = false,
    time = 0,
    rotate_speed = 1
}

local b = ImportFile("Attacks.Bones")

local phi = (1 + math.sqrt(5)) / 2  -- golden ratio ~1.618

--- Generate 20 vertices of a regular dodecahedron, centered at (cx,cy,cz)
--- with circumscribed sphere radius R.
local function generate_dodecahedron(cx, cy, cz, R)
    -- scale = R / √3  because the raw coordinates are on a sphere of radius √3
    local s = R / math.sqrt(3)

    local raw = {
        -- (±1, ±1, ±1) — 8 vertices (a cube)
        { 1,  1,  1}, { 1,  1, -1}, { 1, -1,  1}, { 1, -1, -1},
        {-1,  1,  1}, {-1,  1, -1}, {-1, -1,  1}, {-1, -1, -1},

        -- (0, ±1/φ, ±φ) — 4 vertices
        { 0,  1/phi,  phi}, { 0,  1/phi, -phi},
        { 0, -1/phi,  phi}, { 0, -1/phi, -phi},

        -- (±1/φ, ±φ, 0) — 4 vertices
        { 1/phi,  phi,  0}, {-1/phi,  phi,  0},
        { 1/phi, -phi,  0}, {-1/phi, -phi,  0},

        -- (±φ, 0, ±1/φ) — 4 vertices
        { phi,  0,  1/phi}, { phi,  0, -1/phi},
        {-phi,  0,  1/phi}, {-phi,  0, -1/phi},
    }

    -- Scale & translate
    local points = {}
    for _, v in ipairs(raw) do
        points[#points + 1] = {
            cx + v[1] * s,
            cy + v[2] * s,
            cz + v[3] * s,
        }
    end
    return points
end

--- Connect all 30 edges of the dodecahedron by finding each vertex's
--- 3 nearest neighbours (correct edge-length in this coordinate system).
--- @param dodeca  the 3D bone object
local function link_all_edges(dodeca)
    local pts = dodeca.points
    local n = #pts
    local added = {}  -- track already-added edges: "i<j" → true

    for i = 1, n do
        local vi = pts[i]
        -- Compute squared distances from vertex i to all others
        local dists = {}
        for j = 1, n do
            if i ~= j then
                local vj = pts[j]
                local dx, dy, dz = vi[1] - vj[1], vi[2] - vj[2], vi[3] - vj[3]
                dists[j] = dx * dx + dy * dy + dz * dz
            else
                dists[j] = math.huge
            end
        end

        -- Find the 3 closest vertices (ties won't happen for a regular polyhedron)
        -- Simple approach: sort indices by distance
        local order = {}
        for j = 1, n do order[j] = j end
        table.sort(order, function(a, b) return dists[a] < dists[b] end)

        for k = 1, 3 do  -- each vertex has degree 3
            local j = order[k]
            local key = i < j and (i .. "," .. j) or (j .. "," .. i)
            if not added[key] then
                added[key] = true
                dodeca:Link("sans", i, j)
            end
        end
    end
end

function anim.Init()
    local center = {320, 140, 0}
    local R = 70

    local d_points = generate_dodecahedron(center[1], center[2], center[3], R)
    local dodeca = b.New3D(d_points, 1, "orthographic")
    link_all_edges(dodeca)
    dodeca:SetLayer("UI")
    table.insert(anim.elements, dodeca)

    anim.cube = dodeca
end

function anim.Zoom(z, duration)
    Tween.CreateTween(function (v)
        anim.cube.z = v
    end, "Quad", "InOut", anim.cube.z, z, duration)
end

function anim.RotateFaster()
    Tween.CreateTween(function (v)
        anim.rotate_speed = v
    end, "Quad", "In", 1, 5, 30)
    Tween.CreateTween(function (v)
        anim.rotate_speed = v
    end, "Quad", "Out", 5, 1, 60, 60)
end

function anim.Bounce()
    Tween.CreateTween(function (v)
        anim.cube.y = v
    end, "Quad", "Out", anim.cube.y, 80, 30)
    Tween.CreateTween(function (v)
        anim.cube.y = v
    end, "Bounce", "Out", 80, 140, 60, 30)
end

function anim.Update(dt)
    b.Update(dt)
    if (not anim.running) then
        return
    end

    local dodeca = anim.cube
    dodeca:Rotate("x", 3 * 3 * anim.rotate_speed * dt)
    dodeca:Rotate("y", 5 * 3 * anim.rotate_speed * dt)
    dodeca:Rotate("z", 6 * 3 * anim.rotate_speed * dt)
end

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