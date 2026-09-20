local bones = {
    _2D = {},
    _3D = {},
    _WALL = {},
    _WALLC = {}
}

-- 3D Math: axis rotation helpers (all angles in degrees)
local function _rotateX(point, center, angle)
    local rad = math.rad(angle)
    local y = point[2] - center[2]
    local z = point[3] - center[3]
    local cos_a, sin_a = math.cos(rad), math.sin(rad)
    return {
        point[1],
        center[2] + y * cos_a - z * sin_a,
        center[3] + y * sin_a + z * cos_a
    }
end

local function _rotateY(point, center, angle)
    local rad = math.rad(angle)
    local x = point[1] - center[1]
    local z = point[3] - center[3]
    local cos_a, sin_a = math.cos(rad), math.sin(rad)
    return {
        center[1] + x * cos_a + z * sin_a,
        point[2],
        center[3] - x * sin_a + z * cos_a
    }
end

local function _rotateZ(point, center, angle)
    local rad = math.rad(angle)
    local x = point[1] - center[1]
    local y = point[2] - center[2]
    local cos_a, sin_a = math.cos(rad), math.sin(rad)
    return {
        center[1] + x * cos_a - y * sin_a,
        center[2] + x * sin_a + y * cos_a,
        point[3]
    }
end

-- 3D → 2D projection helpers
--- Orthographic projection. When bulge > 0, applies a z-dependent scale:
---   z=0 → exact pixels,  z>0 → shrinks,  z<0 → expands
--- This creates an inflation / bulging effect.
local function _orthographic(point, bulge)
    if (bulge and bulge > 0) then
        local denom = bulge + point[3]
        if (denom <= 0) then denom = 0.001 end
        local factor = bulge / denom
        return point[1] * factor, point[2] * factor
    end
    return point[1], point[2]
end

local function _perspective(point, d)
    local factor = d / (d + point[3])
    return point[1] * factor, point[2] * factor
end

-- Shared helpers ------------------------------------------------------------

---Normalizes a character name to the folder used under "Resources/Sprites/Attacks".
---@param whose string|nil
---@return string
local function _characterFolder(whose)
    local name = tostring(whose or "Sans"):lower()
    if (name == "papyrus") then
        return "Papyrus"
    end
    return "Sans"
end

---Sounds the original attacks reference that this project does not ship.
local _soundFallbacks = {
    ["snd_pierce.wav"] = {"snd_spearappear.wav", "snd_lazer.wav"}
}

---Plays a sound defensively: a missing audio file must never break an attack.
---@param name string
local function _playSound(name)
    if (not name) then
        return
    end

    local tries = {name}
    for _, alternative in ipairs(_soundFallbacks[name] or {})
    do
        tries[#tries + 1] = alternative
    end

    for _, sound in ipairs(tries)
    do
        if (pcall(Audio.PlaySound, sound)) then
            return
        end
        print("[Attacks - Bones] Sound '" .. sound .. "' is unavailable, trying a fallback.")
    end
end

function bones.New2D(whose, length, position, angle, velocity)
    local bone = {}

    local _whose = whose
    if (
        not _whose or
        type(_whose) ~= "string" or 
        (_whose:lower() ~= "sans" and _whose:lower() ~= "papyrus")
    ) then
        print("[Attacks Bones] The argument 'whose' must be a string. Using 'sans' as default.")
        _whose = "sans"
    end

    local _len = (length or 0)
    if (
        type(_len) ~= "number"
    ) then
        print("[Attacks Bones] The argument 'length' must be a number. Using '0' as default.")
        _len = 0
    end

    local _pos = (position or {320, 240})
    if (
        type(_pos) ~= "table"
    ) then
        print("[Attacks Bones] The argument 'position' is an invalid value, using '{320, 240}' as default.")
        _pos = {320, 240}
    end

    local _angle = (angle or 0)
    if (
        type(_angle) ~= "number"
    ) then
        print("[Attacks Bones] The argument 'angle' is an invalid value, using '0' as default.")
        _pos = {320, 240}
    end

    local _vel = (velocity or {0, 0})
    if (
        type(_vel) ~= "table"
    ) then
        print("[Attacks - Bones] The argument 'velocity' is an invalid value, using '{0, 0}' as default.")
        _vel = {0, 0}
    end

    bone.whose = _whose:lower()
    bone.length = math.abs(_len)
    bone.x = _pos[1]
    bone.y = _pos[2]
    bone.rotation = _angle
    bone.velocity = _vel
    bone.concat = true
    bone.layer = "Bullets"
    bone.isBullet = true

    bone.xpivot = 0.5
    bone.ypivot = 0.5
    -- Head/tail width (px), used as the xpivot side-offset scale.
    bone.width = (bone.whose == "sans") and 10 or 13

    if (bone.whose == "sans") then
        bone._head = Sprites.CreateSprite("Attacks/Sans/spr_s_bonebul_top_0.png", "Bullets")
        bone._body = Sprites.CreateSprite("px.png", "Bullets")
        bone._tail = Sprites.CreateSprite("Attacks/Sans/spr_s_bonebul_bottom_0.png", "Bullets")

        bone._head.rotation = _angle
        bone._body.rotation = _angle
        bone._tail.rotation = _angle

        bone._head.ypivot = 1
        bone._tail.ypivot = 0
        bone._body.xscale = 6
    elseif (bone.whose == "papyrus") then
        bone._head = Sprites.CreateSprite("Attacks/Papyrus/spr_bonetop_0.png", "Bullets")
        bone._body = Sprites.CreateSprite("px.png", "Bullets")
        bone._tail = Sprites.CreateSprite("Attacks/Papyrus/spr_bonebottom_0.png", "Bullets")

        bone._head.rotation = _angle
        bone._body.rotation = _angle
        bone._tail.rotation = _angle

        bone._head.ypivot = 1
        bone._tail.ypivot = 0
        bone._body.xscale = 5
    end

    --- Change the layer of this 2D bone and all its Sprites.
    --- @param layer string|number  The target layer (name string or numeric).
    function bone:SetLayer(layer)
        self.layer = layer
        if self._head then self._head.layer = layer end
        if self._body then self._body.layer = layer end
        if self._tail then self._tail.layer = layer end
    end

    --- Set the bone's anchor point (pivot), normalized 0~1 each.
    --- ypivot runs along the bone: 0 = head end, 1 = tail end, 0.5 = center
    --- (spans the whole bone: head + body + tail).
    --- xpivot runs across the head/tail width to the sides: 0 = one edge,
    --- 1 = the other edge (0~1 spans the full width: 10px for sans, 13px for papyrus).
    --- @param xp number|nil  x pivot (omit to keep the current value)
    --- @param yp number|nil  y pivot (omit to keep the current value)
    function bone:SetPivot(xp, yp)
        if (type(xp) == "number") then self.xpivot = xp end
        if (type(yp) == "number") then self.ypivot = yp end
    end

    function bone:SetStencils(stencils)
        if self._head then self._head:SetStencils(stencils) end
        if self._body then self._body:SetStencils(stencils) end
        if self._tail then self._tail:SetStencils(stencils) end
    end


    function bone:ToDown(arena)
        self.y = arena.y + arena.height / 2 - (self.length + 12) / 2
    end

    function bone:ToUp(arena)
        self.y = arena.y - arena.height / 2 + (self.length + 12) / 2
    end

    function bone:ToLeft(arena)
        self.x = arena.x - arena.width / 2 + (self.length + 12) / 2
    end

    function bone:ToRight(arena)
        self.x = arena.x + arena.width / 2 - (self.length + 12) / 2
    end

    function bone:SetMode(mode, color)
        if (self._head) then
            if (color) then
                self._head.color = color
            end
            self._head["HurtMode"] = (mode or "normal")
        end
        if (self._body) then
            if (color) then
                self._body.color = color
            end
            self._body["HurtMode"] = (mode or "normal")
        end
        if (self._tail) then
            if (color) then
                self._tail.color = color
            end
            self._tail["HurtMode"] = (mode or "normal")
        end
    end

    function bone:SetColor(color)
        if (self._head) then
            self._head.color = (color or Global.GetVariable("MainColor"))
        end
        if (self._body) then
            self._body.color = (color or Global.GetVariable("MainColor"))
        end
        if (self._tail) then
            self._tail.color = (color or Global.GetVariable("MainColor"))
        end
    end

    ---Idempotent: a wall and bones.Clear() may both try to destroy the same bone.
    function bone:Destroy()
        if (self._destroyed) then
            return
        end
        self._destroyed = true

        self._head:Destroy()
        self._body:Destroy()
        self._tail:Destroy()

        for i = #bones._2D, 1, -1
        do
            local b = bones._2D[i]
            if (b == self) then
                table.remove(bones._2D, i)
            end
        end
    end

    table.insert(bones._2D, bone)
    return bone
end



function bones.New3D(points, percent, mode)
    local bone = {
        bones = {}
    }
    bone.concat = true

    -- Metatable: assigning bone.x / bone.y / bone.z directly
    -- repositions all 3D vertices (keeps synced with _center).
    --
    -- NOTE: x/y/z are NEVER stored directly in the bone table.
    --   - Reading  (__index)    → reads from _center
    --   - Writing (__newindex)  → shifts all points, updates _center, but does NOT store in table
    -- This guarantees every assignment properly propagates to all vertices.
    local bone_mt = {}
    function bone_mt.__index(t, k)
        if (k == "x") then return t._center and t._center[1] end
        if (k == "y") then return t._center and t._center[2] end
        if (k == "z") then return t._center and t._center[3] end
        return nil
    end
    function bone_mt.__newindex(t, k, v)
        if (k == "x" or k == "y" or k == "z") then
            local idx = (k == "x" and 1) or (k == "y" and 2) or 3
            local old = t._center and t._center[idx]
            if (old ~= nil and old ~= v) then
                local dv = v - old
                for _, p in ipairs(t.points or {}) do
                    p[idx] = p[idx] + dv
                end
                t._center[idx] = v
            end
            -- Do NOT rawset — x/y/z stay out of the table so __newindex fires every time.
        else
            rawset(t, k, v)
        end
    end
    setmetatable(bone, bone_mt)

    local _percent = (percent or 0.5)
    if (type(_percent) ~= "number") then
        print("[Attacks - Bones] The argument 'percent' is an invalid value. Using '0.5' as default.")
        _percent = 0.5
    end
    bone.percent = _percent

    -- Perspective or Orthographic
    local _mode = (mode or "orthographic")
    if (type(_mode) ~= "string") then
        _mode = "orthographic"
    else
        if (_mode:sub(1, 1):lower() == "o") then
            _mode = "o"
        else
            _mode = "p"
        end
    end

    -- Check points. (puns haha.)
    local _points = points
    local x, y, z = 0, 0, 0
    if (not points) then
        print("[Attacks - Bones] The argument 'points' is an invalid value. This operation is stopped automatically.")
        return {}
    end
    for _, p in ipairs(_points)
    do
        if (type(p) ~= "table") then
            print("[Attacks - Bones] The argument 'points' is an invalid value. This operation is stopped automatically.")
            return {}
        end
        if (type(p) == "table" and #p < 3) then
            print("[Attacks - Bones] The argument 'points' has an invalid position, inserting '0' for empty indexes.:")
            print("                  " .. unpack(p))

            -- Please...don't put strings here, I don't want to check them.
            while (#p < 3)
            do
                p[#p + 1] = 0
            end
        elseif (type(p) == "table" and #p == 3) then
            -- Now I want to check them.
            if (type(p[1]) == "number" and type(p[2]) == "number" and type(p[3]) == "number") then
                -- Yes I 'have' to check them
                x = x + p[1]
                y = y + p[2]
                z = z + p[3]
            else
                print("[Attacks - Bones] The argument 'points' is an invalid value. This operation is stopped automatically.")
                return {}
            end
        end
    end

    bone.points = _points
    bone.mode = _mode
    bone._center = {
        x / #_points,
        y / #_points,
        z / #_points,
    }
    -- Don't assign x/y/z to the table — __index / __newindex on the metatable
    -- handle reads/writes transparently via _center.
    bone.bulge = 0  -- 0 = pure orthographic; >0 adds z-scale inflation effect
    bone.xscale = 1 -- 2D view scale (applied post-projection, does not affect 3D data)
    bone.yscale = 1

    -- Funcs

    --- Move the bone's center to (x, y, z) directly.
    --- @param x number
    --- @param y number
    --- @param z number|nil  (optional)
    function bone:MoveTo(x, y, z)
        local cx, cy, cz = self._center[1], self._center[2], self._center[3]
        local dz = (z ~= nil and z or cz)
        local dx = x - cx
        local dy = y - cy
        local ddz = dz - cz
        for _, p in ipairs(self.points) do
            p[1] = p[1] + dx
            p[2] = p[2] + dy
            p[3] = p[3] + ddz
        end
        self._center[1] = x
        self._center[2] = y
        self._center[3] = dz
        self.x, self.y, self.z = x, y, dz
    end

    --- Translate the bone by (x, y, z).
    --- @param x number
    --- @param y number
    --- @param z number|nil  (optional)
    function bone:Move(x, y, z)
        local dz = (z ~= nil and z or 0)
        for _, p in ipairs(self.points) do
            p[1] = p[1] + x
            p[2] = p[2] + y
            p[3] = p[3] + dz
        end
        self._center[1] = self._center[1] + x
        self._center[2] = self._center[2] + y
        self._center[3] = self._center[3] + dz
        self.x = self._center[1]
        self.y = self._center[2]
        self.z = self._center[3]
    end

    --- Rotate all points around the bone's center.
    --- @param axis string  "x", "y", or "z"
    --- @param angle number  degrees
    function bone:Rotate(axis, angle)
        local rotFunc
        local a = axis:lower()
        if (a == "x") then
            rotFunc = _rotateX
        elseif (a == "y") then
            rotFunc = _rotateY
        elseif (a == "z") then
            rotFunc = _rotateZ
        else
            print("[Attacks - Bones] Rotate: invalid axis '" .. axis .. "'. Use 'x', 'y', or 'z'.")
            return
        end
        for i, p in ipairs(self.points) do
            self.points[i] = rotFunc(p, self._center, angle)
        end
    end

    --- Link two 3D points with a 2D bone.
    --- @param whose string   "sans" or "papyrus"
    --- @param point_1 number  1-based index of the first 3D point
    --- @param point_2 number  1-based index of the second 3D point
    --- @param percent_ number|nil  (optional) length as fraction of the edge
    function bone:Link(whose, point_1, point_2, percent_)
        local bone_ = bones.New2D(whose, 0)
        bone_.x = 999
        bone_.y = 999
        bone_._3d_pindexes = {point_1, point_2}
        bone_._3d_percent  = (percent_ or _percent)
        bone.bones[#bone.bones + 1] = bone_
    end

    function bone:SetLayer(layer)
        for _, b in ipairs(self.bones) do
            b.layer = layer
            if b._head then b._head.layer = layer end
            if b._body then b._body.layer = layer end
            if b._tail then b._tail.layer = layer end
        end
    end

    --- Scale the 2D view of all projected points around the bone's visual center.
    --- This is a purely visual transform — it does NOT modify internal 3D point data,
    --- so resetting to (1, 1) always restores the original appearance.
    --- @param sx number  X scale factor (default 1)
    --- @param sy number  Y scale factor (default 1)
    function bone:Scale(sx, sy)
        self.xscale = sx or 1
        self.yscale = sy or 1
    end

    table.insert(bones._3D, bone)
    return bone
end

------------------------------------------------------------------
-- Walls
------------------------------------------------------------------

---Tears a wall down: the warning bar first, then every bone, then unregisters
---it from whichever list holds it.
---@param wall table
local function _destroyWall(wall)
    if (wall.warning) then
        wall.warning:Destroy()
        wall.warning = nil
    end

    for i = #wall.bones, 1, -1
    do
        local bone = wall.bones[i]
        if (not bone._destroyed) then
            bone:Destroy()
        end
        table.remove(wall.bones, i)
    end

    wall.isactive = false

    for _, list in ipairs({bones._WALL, bones._WALLC})
    do
        for i = #list, 1, -1
        do
            if (list[i] == wall) then
                table.remove(list, i)
            end
        end
    end
end

---Applies stencil masks to the warning bar and to every bone of a wall.
---@param wall table
---@param masks table
local function _wallSetStencils(wall, masks)
    if (masks) then
        wall.stencils = masks
    end

    if (wall.warning) then
        wall.warning:SetStencils(masks)
    end

    for i = #wall.bones, 1, -1
    do
        wall.bones[i]:SetStencils(masks)
    end
end

-- Method tables: _WALL (one sliding bone sprite per direction) and _WALLC
-- (20 bones per side). They share the same behaviour today but stay separate
-- so each variant can grow its own methods later.
local wall_methods = {
    SetStencils = _wallSetStencils,
    Destroy = _destroyWall
}
wall_methods.__index = wall_methods

local wallc_methods = {
    SetStencils = _wallSetStencils,
    Destroy = _destroyWall
}
wallc_methods.__index = wallc_methods

---Normalizes the animation table consumed by the wall tweens. The easing name
---is built by Tween as ("" .. In):lower(), so "SineOut" resolves to "sineout".
---@param animation table|nil  {In = "SineOut", Out = "BackIn", It = 15, Ot = 60}
---@return table
local function _animationTable(animation)
    if (type(animation) ~= "table") then
        return {In = "Linear", Out = "Linear", It = 15, Ot = 15}
    end

    return {
        In  = (animation.In  or "Linear"),
        Out = (animation.Out or "Linear"),
        It  = (animation.It  or 15),
        Ot  = (animation.Ot  or 15)
    }
end

---A straight wall: a single long bone sprite sliding in from one side of the
---arena, telegraphed by a blinking warning bar.
---@param arena table
---@param whose string  "Sans" | "Papyrus"
---@param warntime number  ticks the warning bar blinks for
---@param staytime number  ticks the wall stays fully extended
---@param length number
---@param direction string  "up" | "down" | "left" | "right"
---@param rotation number
---@param interval number
---@param animation table  {In = easingName, Out = easingName, It = ticks, Ot = ticks}
---@return table
function bones.Wall(arena, whose, warntime, staytime, length, direction, rotation, interval, animation)
    local X, Y = arena.black:GetPosition()
    local W, H = arena.width, arena.height

    warntime  = (warntime or 0)
    staytime  = (staytime or 0)
    length    = (length or 0)
    rotation  = (rotation or 0)
    animation = _animationTable(animation)

    local folder = _characterFolder(whose)
    local wall = {
        time = 0,
        bones = {},
        stencils = {},
        isactive = true,
        interval = (interval or 12),
        rotation = rotation,
        warntime = warntime,
        animation = animation,
        whose = folder,
        warning = Sprites.CreateSprite("px.png", "Bullets")
    }

    wall.warning:Scale(999, length * 2 + 12)
    wall.warning.alpha = 0.5

    -- The wall sprite is done once it has left the arena again.
    local function end_spr(spr)
        spr:Destroy()
        for i = #wall.bones, 1, -1
        do
            if (wall.bones[i] == spr) then
                table.remove(wall.bones, i)
            end
        end
    end

    -- No more angles calculation, just move the warning sprite directly.
    -- 0, 90, 180, 270 degrees only.
    if (direction == "down") then
        wall.warning:MoveTo(X, Y + H / 2)
        local wallspr = Sprites.CreateSprite("Attacks/" .. folder .. "/spr_wall.png", "Bullets")
        wallspr:MoveTo(X, Y + 480 / 2 + H / 2 + 20)
        wallspr.isBullet = true

        wallspr.logic = function (self)
            if (wall.time == warntime) then
                Tween.CreateTween(
                    function (value)
                        self.y = value
                    end,
                    "", animation.In, self.y, Y + H / 2 + 240 - (length + 6), animation.It
                )
            elseif (wall.time == warntime + animation.It + staytime) then
                Tween.CreateTween(
                    function (value)
                        self.y = value
                    end,
                    "", animation.Out, self.y, Y + 480 / 2 + H / 2 + 20, animation.Ot
                )
            elseif (wall.time >= warntime + animation.It + staytime + animation.Ot) then
                end_spr(self)
            end
        end

        table.insert(wall.bones, wallspr)
    elseif (direction == "up") then
        wall.warning:MoveTo(X, Y - H / 2)
        local wallspr = Sprites.CreateSprite("Attacks/" .. folder .. "/spr_wall.png", "Bullets")
        wallspr:MoveTo(X, Y - 480 / 2 - H / 2 - 20)
        wallspr.isBullet = true

        wallspr.logic = function (self)
            if (wall.time == warntime) then
                Tween.CreateTween(
                    function (value)
                        self.y = value
                    end,
                    "", animation.In, self.y, Y - H / 2 - 240 + (length + 6), animation.It
                )
            elseif (wall.time == warntime + animation.It + staytime) then
                Tween.CreateTween(
                    function (value)
                        self.y = value
                    end,
                    "", animation.Out, self.y, Y - 480 / 2 - H / 2 - 20, animation.Ot
                )
            elseif (wall.time >= warntime + animation.It + staytime + animation.Ot) then
                end_spr(self)
            end
        end

        table.insert(wall.bones, wallspr)
    elseif (direction == "left") then
        wall.warning.rotation = wall.warning.rotation + 90
        wall.warning:MoveTo(X - W / 2, Y)
        local wallspr = Sprites.CreateSprite("Attacks/" .. folder .. "/spr_wall.png", "Bullets")
        wallspr.rotation = wallspr.rotation + 90
        wallspr:MoveTo(X - 480 / 2 - W / 2 - 20, Y)
        wallspr.isBullet = true

        wallspr.logic = function (self)
            if (wall.time == warntime) then
                Tween.CreateTween(
                    function (value)
                        self.x = value
                    end,
                    "", animation.In, self.x, X - W / 2 - 240 + (length + 3), animation.It
                )
            elseif (wall.time == warntime + animation.It + staytime) then
                Tween.CreateTween(
                    function (value)
                        self.x = value
                    end,
                    "", animation.Out, self.x, X - 480 / 2 - W / 2 - 30, animation.Ot
                )
            elseif (wall.time >= warntime + animation.It + staytime + animation.Ot) then
                end_spr(self)
            end
        end

        table.insert(wall.bones, wallspr)
    elseif (direction == "right") then
        wall.warning.rotation = wall.warning.rotation + 90
        wall.warning:MoveTo(X + W / 2, Y)
        local wallspr = Sprites.CreateSprite("Attacks/" .. folder .. "/spr_wall.png", "Bullets")
        wallspr.rotation = wallspr.rotation + 90
        wallspr:MoveTo(X + 480 / 2 + W / 2 + 20, Y)
        wallspr.isBullet = true

        wallspr.logic = function (self)
            if (wall.time == warntime) then
                Tween.CreateTween(
                    function (value)
                        self.x = value
                    end,
                    "", animation.In, self.x, X + W / 2 + 240 - (length + 3), animation.It
                )
            elseif (wall.time == warntime + animation.It + staytime) then
                Tween.CreateTween(
                    function (value)
                        self.x = value
                    end,
                    "", animation.Out, self.x, X + 480 / 2 + W / 2 + 20, animation.Ot
                )
            elseif (wall.time >= warntime + animation.It + staytime + animation.Ot) then
                end_spr(self)
            end
        end

        table.insert(wall.bones, wallspr)
    end

    wall.logic = function (self)
        self.time = self.time + 1

        if (self.time <= self.warntime) then
            if (self.warning) then
                if (self.time % 6 == 0) then
                    self.warning.color = {1, 0, 0}
                    _playSound("snd_warning_0.wav")
                elseif (self.time % 6 == 3) then
                    self.warning.color = {1, 1, 0}
                    _playSound("snd_warning_1.wav")
                end
            end
        else
            -- The first frame past the warning phase is the impact frame.
            if (self.time == self.warntime + 1) then
                _playSound("snd_pierce.wav")
            end

            if (self.warning) then
                self.warning:Destroy()
                self.warning = nil
            end
        end

        for i = #self.bones, 1, -1
        do
            local bone = self.bones[i]
            if (bone.logic) then
                bone:logic()
            end
        end

        -- Nothing left to drive once the warning bar and every bone are gone.
        if (#self.bones == 0 and not self.warning) then
            self:Destroy()
        end
    end

    setmetatable(wall, wall_methods)
    table.insert(bones._WALL, wall)
    return wall
end

---A wall built out of 20 bones per side: the bones stay parked just outside the
---arena edge (stencil-clipped) and then grow in, forming a "complex" wall.
---@param arena table
---@param whose string  "Sans" | "Papyrus"
---@param warntime number
---@param staytime number
---@param length number
---@param direction string  "up" | "down" | "left" | "right"
---@param rotation number
---@param interval number
---@param animation table  {In = easingName, Out = easingName, It = ticks, Ot = ticks}
---@return table
function bones.WallComplex(arena, whose, warntime, staytime, length, direction, rotation, interval, animation)
    local X, Y = arena.black:GetPosition()
    local W, H = arena.width, arena.height

    warntime  = (warntime or 0)
    staytime  = (staytime or 0)
    length    = (length or 0)
    rotation  = (rotation or 0)
    animation = _animationTable(animation)

    local cos, sin = math.cos(math.rad(rotation)), math.sin(math.rad(rotation))
    local wall = {
        time = 0,
        bones = {},
        stencils = {},
        isactive = true,
        interval = (interval or 12),
        rotation = rotation,
        warntime = warntime,
        warning = Sprites.CreateSprite("px.png", "Bullets")
    }

    wall.warning:Scale(999, length * 2 + 12)
    wall.warning.alpha = 0.5
    wall.warning.rotation = rotation

    -- Every bone of a complex wall shares the same grow/retract behaviour.
    local function make_logic()
        return function (self)
            if (wall.time == warntime) then
                Tween.CreateTween(
                    function (value)
                        self.length = value
                    end,
                    "", animation.In, 0, length * 2, animation.It
                )
            elseif (wall.time == warntime + animation.It + staytime) then
                Tween.CreateTween(
                    function (value)
                        self.length = value
                    end,
                    "", animation.Out, self.length, 0, animation.Ot
                )
            elseif (wall.time >= warntime + animation.It + staytime + animation.Ot) then
                self:Destroy()
                for j = #wall.bones, 1, -1
                do
                    if (wall.bones[j] == self) then
                        table.remove(wall.bones, j)
                    end
                end
            end
        end
    end

    if (direction == "down") then
        -- h = sqrt(pow(w / 2 * cos, 2) - pow(w / 2, 2))
        -- h += w/2 * tan R
        wall.warning:MoveTo(
            X - (H / 2 + 10) * sin,
            Y + (H / 2 + 10) * cos + W / 2 * math.tan(math.rad(rotation)) + 6
        )
        for i = 1, 20 do
            local bone = bones.New2D(whose, 0)
            bone.rotation = wall.rotation
            bone.x = X + wall.interval * (i - 1) * cos - (H / 2 + 10) * sin
            bone.y = Y + (H / 2 + 10) * cos + (wall.interval * (i - 1)) * sin
            bone.y = bone.y + W / 2 * math.tan(math.rad(rotation)) + 6
            bone.logic = make_logic()
            table.insert(wall.bones, bone)

            local bone = bones.New2D(whose, 0)
            bone.rotation = wall.rotation
            bone.x = X - wall.interval * i * cos - (H / 2 + 10) * sin
            bone.y = Y + (H / 2 + 10) * cos - (wall.interval * i) * sin
            bone.y = bone.y + W / 2 * math.tan(math.rad(rotation)) + 6
            bone.logic = make_logic()
            table.insert(wall.bones, bone)
        end
    elseif (direction == "up") then
        wall.warning:MoveTo(
            X - (H / 2 + 10) * sin,
            Y - (H / 2 + 10) * cos - W / 2 * math.tan(math.rad(rotation)) - 6
        )
        for i = 1, 20 do
            local bone = bones.New2D(whose, 0)
            bone.rotation = wall.rotation
            bone.x = X + wall.interval * (i - 1) * cos - (H / 2 + 10) * sin
            bone.y = Y - (H / 2 + 10) * cos + (wall.interval * (i - 1)) * sin
            bone.y = bone.y - W / 2 * math.tan(math.rad(rotation)) - 6
            bone.logic = make_logic()
            table.insert(wall.bones, bone)

            local bone = bones.New2D(whose, 0)
            bone.rotation = wall.rotation
            bone.x = X - wall.interval * i * cos - (H / 2 + 10) * sin
            bone.y = Y - (H / 2 + 10) * cos - (wall.interval * i) * sin
            bone.y = bone.y - W / 2 * math.tan(math.rad(rotation)) - 6
            bone.logic = make_logic()
            table.insert(wall.bones, bone)
        end
    elseif (direction == "left") then
        wall.warning.rotation = wall.warning.rotation + 90
        wall.warning:MoveTo(
            X - (W / 2 + 10) * cos - H / 2 * math.tan(math.rad(rotation)) - 6,
            Y - (W / 2 + 10) * sin
        )
        for i = 1, 20 do
            local bone = bones.New2D(whose, 0)
            bone.rotation = wall.rotation + 90
            bone.x = X - (W / 2 + 10) * cos - (wall.interval * (i - 1)) * sin
            bone.y = Y + wall.interval * (i - 1) * cos - (W / 2 + 10) * sin
            bone.x = bone.x - H / 2 * math.tan(math.rad(rotation)) - 6
            bone.logic = make_logic()
            table.insert(wall.bones, bone)

            local bone = bones.New2D(whose, 0)
            bone.rotation = wall.rotation + 90
            bone.x = X - (W / 2 + 10) * cos + (wall.interval * i) * sin
            bone.y = Y - wall.interval * i * cos - (W / 2 + 10) * sin
            bone.x = bone.x - H / 2 * math.tan(math.rad(rotation)) - 6
            bone.logic = make_logic()
            table.insert(wall.bones, bone)
        end
    elseif (direction == "right") then
        wall.warning.rotation = wall.warning.rotation + 90
        wall.warning:MoveTo(
            X + (W / 2 + 10) * cos + H / 2 * math.tan(math.rad(rotation)) + 6,
            Y + (W / 2 + 10) * sin
        )
        for i = 1, 20 do
            local bone = bones.New2D(whose, 0)
            bone.rotation = wall.rotation + 90
            bone.x = X + (W / 2 + 10) * cos - (wall.interval * (i - 1)) * sin
            bone.y = Y + wall.interval * (i - 1) * cos + (W / 2 + 10) * sin
            bone.x = bone.x + H / 2 * math.tan(math.rad(rotation)) + 6
            bone.logic = make_logic()
            table.insert(wall.bones, bone)

            local bone = bones.New2D(whose, 0)
            bone.rotation = wall.rotation + 90
            bone.x = X + (W / 2 + 10) * cos + (wall.interval * i) * sin
            bone.y = Y - wall.interval * i * cos + (W / 2 + 10) * sin
            bone.x = bone.x + H / 2 * math.tan(math.rad(rotation)) + 6
            bone.logic = make_logic()
            table.insert(wall.bones, bone)
        end
    end

    wall.logic = function (self)
        self.time = self.time + 1

        if (self.time <= self.warntime) then
            if (self.warning) then
                if (self.time % 6 == 0) then
                    self.warning.color = {1, 0, 0}
                elseif (self.time % 6 == 3) then
                    self.warning.color = {1, 1, 0}
                end
            end
        else
            if (self.warning) then
                self.warning:Destroy()
                self.warning = nil
            end
        end

        for i = #self.bones, 1, -1
        do
            local bone = self.bones[i]
            if (bone.logic) then
                bone:logic()
            end
        end

        -- Nothing left to drive once the warning bar and every bone are gone.
        if (#self.bones == 0 and not self.warning) then
            self:Destroy()
        end
    end

    setmetatable(wall, wallc_methods)
    table.insert(bones._WALLC, wall)
    return wall
end

function bones.Update(dt)
    local _2D = bones._2D
    for i = #_2D, 1, -1
    do
        local b = _2D[i]
        if (b.concat) then
            local head, body, tail = b._head, b._body, b._tail

            b.x = b.x + b.velocity[1]
            b.y = b.y + b.velocity[2]

            head.rotation = b.rotation
            body.rotation = b.rotation
            tail.rotation = b.rotation

            head.isBullet = b.isBullet
            body.isBullet = b.isBullet
            tail.isBullet = b.isBullet

            body.yscale = b.length

            local rad = math.rad(b.rotation)
            local s, c = math.sin(rad), math.cos(rad)
            local width = b.width or 10
            local offL = (b.ypivot - 0.5) * b.length  -- along the bone (toward head = +)
            local offS = (b.xpivot - 0.5) * width     -- to the side

            local bx = b.x + offL * s + offS * c
            local by = b.y - offL * c + offS * s

            body:MoveTo(bx, by)
            local abs_length = math.abs(b.length)
            head:MoveTo(
                bx + abs_length / 2 * s,
                by - abs_length / 2 * c
            )
            tail:MoveTo(
                bx - abs_length / 2 * s,
                by + abs_length / 2 * c
            )
        end

        -- Step
        if (b.Step) then
            b:Step()
        end
    end

    local _3D = bones._3D
    for i = #_3D, 1, -1
    do
        local b = _3D[i]
        if (b.concat) then
            local projected = {}
            local isOrtho = (b.mode == "o")
            local d = 500
            for idx, p in ipairs(b.points) do
                if (isOrtho) then
                    projected[idx] = {_orthographic(p, b.bulge)}
                else
                    projected[idx] = {_perspective(p, d)}
                end
            end

            -- Uniform z‑zoom: scale all projected points around the bone's center
            -- based on the center's z value. Reference distance = 500 (same as
            -- the perspective projection default).
            --   z=0 (at screen)    → factor=1 (normal)
            --   z>0 (behind)       → factor<1 (shrinks)
            --   z<0 (in front)     → factor>1 (enlarges)
            --
            -- Split formula avoids singularities:
            --   z >= 0  → 500 / (500 + z)     hyperbolic decay
            --   z <  0  → (500 - z) / 500      linear growth
            if (isOrtho) then
                local cz = b._center[3]
                local factor
                if (cz >= 0) then
                    factor = 500 / (500 + cz)
                else
                    factor = (500 - cz) / 500
                end
                local cx, cy = b._center[1], b._center[2]
                for _, pt in ipairs(projected) do
                    pt[1] = cx + (pt[1] - cx) * factor
                    pt[2] = cy + (pt[2] - cy) * factor
                end
            end

            -- Apply 2D view scale (xscale/yscale) around the visual center of all projected points.
            -- This is purely cosmetic — it does NOT touch the internal 3D point data,
            -- so resetting to (1, 1) always restores the original appearance.
            local sx, sy = b.xscale or 1, b.yscale or 1
            if (sx ~= 1 or sy ~= 1) then
                local pcx, pcy = 0, 0
                for _, pt in ipairs(projected) do
                    pcx = pcx + pt[1]
                    pcy = pcy + pt[2]
                end
                local n = #projected
                if (n > 0) then
                    pcx = pcx / n
                    pcy = pcy / n
                    for _, pt in ipairs(projected) do
                        pt[1] = pcx + (pt[1] - pcx) * sx
                        pt[2] = pcy + (pt[2] - pcy) * sy
                    end
                end
            end

            for _, link in ipairs(b.bones) do
                local idx1 = link._3d_pindexes[1]
                local idx2 = link._3d_pindexes[2]
                local p1 = projected[idx1]
                local p2 = projected[idx2]
                local mx = (p1[1] + p2[1]) / 2
                local my = (p1[2] + p2[2]) / 2

                local dx = p2[1] - p1[1]
                local dy = p2[2] - p1[2]
                local dist = math.sqrt(dx * dx + dy * dy)
                local angle = 0
                if (dist > 0.0001) then
                    angle = math.deg(math.atan2(dx, -dy))
                end

                -- Apply to the 2D bone
                link.x = mx
                link.y = my
                link.length = dist * link._3d_percent
                link.rotation = angle
            end
        end

        -- Step
        if (b.Step) then
            b:Step()
        end
    end

    -- Walls: the warning bar plus the bone waves. Every wall keeps its own
    -- timer and drives its own bones (wall.logic calls bone:logic()).
    -- Updated last so newly tweened bone lengths are applied from the next
    -- frame on, exactly like the original implementation.
    for _, list in ipairs({bones._WALL, bones._WALLC})
    do
        for i = #list, 1, -1
        do
            local wall = list[i]
            if (wall.isactive and wall.logic) then
                wall.logic(wall)
            end
        end
    end
end

---Destroys every wall and every 2D bone created through this library.
---Walls go first: a wall owns bones that also live in `_2D`, and destroying the
---wall already unregisters them from that list.
function bones.Clear()
    for _, list in ipairs({bones._WALL, bones._WALLC})
    do
        for i = #list, 1, -1
        do
            list[i]:Destroy()
        end
    end

    for i = #bones._2D, 1, -1
    do
        bones._2D[i]:Destroy()
    end
end

return bones
