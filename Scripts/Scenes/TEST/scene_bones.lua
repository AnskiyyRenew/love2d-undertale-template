local scene = {}

Layers.new_layer("Bullets", 30)
local bones = ImportFile("Attacks.Bones")

-- ============================================================
-- Regular Dodecahedron — 20 vertices, 30 edges, 12 pentagons
-- ============================================================
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

-- ============================================================
-- Build the dodecahedron
-- ============================================================
local center = {320, 240, 0}
local R = 40  -- circumradius

local d_points = generate_dodecahedron(center[1], center[2], center[3], R)
local dodeca = bones.New3D(d_points, 0.5, "orthographic")
link_all_edges(dodeca)

-- Z‑zoom is built‑in for orthographic mode (ref distance = 500).
-- z=0 → 1×  |  z=100 → ~0.83×  |  z=-200 → 1.4×
Tween.CreateTween(function (v)
    dodeca.z = v
end, "Bounce", "Out", dodeca.z, -1600, 60)

local function bounce()
    Tween.CreateTween(function (v)
        dodeca.yscale = v
    end, "Quad", "InOut", 1, 1.5, 50)
    Tween.CreateTween(function (v)
        dodeca.yscale = v
    end, "Elastic", "Out", 1.5, 1, 60, 60)
end

-- ============================================================
-- Rotation control
-- ============================================================
local rotSpeed = {x = 0.6, y = 0.9, z = 0.4}

function scene.update(dt)
    bones.Update(dt)
    dodeca:Rotate("x", rotSpeed.x * 60 * dt)
    dodeca:Rotate("y", rotSpeed.y * 60 * dt)
    dodeca:Rotate("z", rotSpeed.z * 60 * dt)

    print(dodeca.z)

    if (Keyboard.GetState("k") == 1) then
        bounce()
    end
end

function scene.draw()
end

function scene.clear()
    Layers.clear()
end

return scene