local sprites = {
    images = {},
    cache = {}
}

local last_cache_cleanup = 0
local CACHE_CLEAN_INTERVAL = 5 -- seconds between cleanup runs
local function getLRUThreshold()
    local ok, v = pcall(function()
        return Global.GetVariable("OPT_LRU_SPRITES")[2]
    end)
    if ok and type(v) == "number" and v > 0 then
        return v
    end
    return 180
end

local pixel_smooth_shader = nil
local function getPixelPerfectShader()
    if not pixel_smooth_shader then
        pixel_smooth_shader = SE.graphics.newShader("Scripts/Shaders/PixelSmooth.glsl")
    end
    return pixel_smooth_shader
end

-- Filter changes are GPU texture state: only re-applied when the request
-- changes. Keyed per image, so sprites sharing a texture must want the same
-- filter (`pixel_smooth` is the only path asking for "linear").
local _applied_filter = setmetatable({}, {__mode = "k"})

local function applyFilter(image, min_filter, mag_filter)
    if (image == nil) then return end
    local want = tostring(min_filter) .. "/" .. tostring(mag_filter or min_filter)
    if (_applied_filter[image] == want) then return end
    _applied_filter[image] = want
    image:setFilter(min_filter, mag_filter)
end

-- Pixel snapping. Nearest-neighbour art needs the quad's EDGES on whole
-- pixels, so the edge is snapped and the centre follows (a snapped centre is
-- only correct for even-sized art). Applied at draw time only: stored x / y
-- keep their sub-pixel value, so slow motion still accumulates.
-- `sprites.pixel_snap` is the global switch; a sprite's own `pixel_snap`
-- (true / false, nil = follow global) overrides it.
sprites.pixel_snap = false

--- Snap one coordinate to the nearest whole pixel (half-up).
local function snapCoord(v)
    if (type(v) ~= "number") then return v end
    return math.floor(v + 0.5)
end

function sprites.SnapCoord(v)
    return snapCoord(v)
end

--- Snap the LEADING EDGE of a quad to the pixel grid and return the centre that
--- puts it there. `offset` is edge-to-centre distance (pivot offset * scale).
function sprites.SnapEdge(centre, offset)
    if (type(centre) ~= "number") then return centre end
    return snapCoord(centre - (offset or 0)) + (offset or 0)
end

--- Turn pixel snapping on / off for every sprite that does not override it.
function sprites.SetPixelSnap(enabled)
    sprites.pixel_snap = (enabled == true)
end

local dust_shader = nil
local function getDustShader()
    if not dust_shader then
        dust_shader = SE.graphics.newShader("Scripts/Shaders/Dust.glsl")
    end
    return dust_shader
end

local temp_canvases = {}
local function createStencilCanvas(width, height)
    local ok, canvas = pcall(function()
        return SE.graphics.newCanvas(width, height, nil, {
            stencil = true,
            readable = true
        })
    end)

    if not ok then
        canvas = SE.graphics.newCanvas(width, height, nil, {
            format = "stencil",
            readable = true
        })
    end

    canvas:setFilter("nearest", "nearest")
    return canvas
end

local function getTempCanvas(width, height)
    local key = width .. "x" .. height
    if not temp_canvases[key] then
        temp_canvases[key] = createStencilCanvas(width, height)
    end
    return temp_canvases[key]
end

local function loadImageSafe(path)
    local success, result = pcall(function()
        return SE.graphics.newImage(path)
    end)

    if not success then
        print("[WARNING] Failed to load image: " .. path)
        print("  Error: " .. tostring(result))

        local fallback_data = SE.image.newImageData(1, 1)
        local placeholder = SE.graphics.newImage(fallback_data)
        placeholder:setFilter("nearest", "nearest")
        return placeholder, fallback_data, false
    end

    result:setFilter("nearest", "nearest")

    local imgData
    local ok, data = pcall(function()
        return SE.image.newImageData(path)
    end)
    if ok then
        imgData = data
    else
        imgData = nil
    end

    return result, imgData, true
end

-- Perfect-pixel collision. A sprite normally collides as its whole image
-- rectangle; PP replaces that with the rectangles tiling its own opaque
-- pixels, cached per IMAGE (several sprites may share one texture, and an LRU
-- release can drop the data). Rects are {x, y, w, h} in image pixel space,
-- origin top-left. Hits are decided by sprites.PPCollide, which answers nil
-- while NEITHER side opted in, so callers keep their own (cheaper) box answer.
local PP_LIB = "Scripts.Libraries.PerfectPixel"
local PP_LIB_PURE = "Scripts.Libraries.PerfectPixel.pure"

local pp_rects = setmetatable({}, {__mode = "k"})       -- image -> rect list (false = no usable data)
local pp_image_data = setmetatable({}, {__mode = "k"})  -- image -> the ImageData behind it
local pp_backend = nil                                   -- nil = unresolved, false = none, table = usable
local pp_is_pure = false                                 -- true once the pure-Lua twin is in charge

--- Remember which ImageData backs an image, so perfect-pixel collision can read
--- its pixels later. Both maps use weak keys, so an LRU release drops them too.
---@param image any LÖVE Image (or nil)
---@param image_data any LÖVE ImageData (or nil)
local function rememberImageData(image, image_data)
    if (image and image_data) then
        pp_image_data[image] = image_data
    end
end

--- Load one rectangulation backend by module name.
---@param name string
---@return table|nil
local function loadPPBackend(name)
    local ok, mod = pcall(require, name)
    if (ok and type(mod) == "table" and type(mod.rectangulate) == "function") then
        return mod
    end
    return nil
end

--- Resolve the backend once, C first, then the pure-Lua twin.
---@return table|nil
local function getPPBackend()
    if (pp_backend ~= nil) then
        return pp_backend or nil
    end

    if (not pp_is_pure) then
        pp_backend = loadPPBackend(PP_LIB)
    end
    if (not pp_backend) then
        pp_backend = loadPPBackend(PP_LIB_PURE)
        pp_is_pure = (pp_backend ~= nil)
    end
    if (not pp_backend) then
        pp_backend = false
        print("[Sprites] Perfect-pixel collision unavailable: neither '" ..
            PP_LIB .. "' nor '" .. PP_LIB_PURE .. "' could be loaded.")
    end
    return pp_backend or nil
end

--- Run a backend over one ImageData and normalise its answer.
---@param backend table
---@param image_data any
---@return table|nil rects Nil when the call failed or returned nothing usable.
local function runRectangulation(backend, image_data)
    local ok, rects = pcall(backend.rectangulate, image_data)
    if (not ok or type(rects) ~= "table") then
        return nil
    end

    local out = {}
    for i = 1, #rects do
        local r = rects[i]
        if (type(r) == "table" and type(r[1]) == "number" and type(r[2]) == "number" and
            type(r[3]) == "number" and type(r[4]) == "number" and r[3] > 0 and r[4] > 0) then
            out[#out + 1] = {r[1], r[2], r[3], r[4]}
        end
    end
    return out
end

--- Rectangulate (and cache) the opaque pixels of an image. An empty tiling is
--- NOT cached: a fully transparent frame falls back to the plain box instead.
---@param image any LÖVE Image
---@param path string|nil Sprite path, used as a second way to find the ImageData.
---@return table|nil rects List of {x, y, w, h}, or nil when there is no usable data.
local function rectsForImage(image, path)
    if (not image) then return nil end

    local cached = pp_rects[image]
    if (cached ~= nil) then
        if (cached == false) then return nil end
        return cached
    end

    local image_data = pp_image_data[image]
    if (not image_data and path and sprites.cache[path] and sprites.cache[path].img == image) then
        image_data = sprites.cache[path].imageData
    end
    if (not image_data) then
        pp_rects[image] = false
        return nil
    end

    local backend = getPPBackend()
    if (not backend) then
        pp_rects[image] = false
        return nil
    end

    local rects = runRectangulation(backend, image_data)

    -- The C backend can fail on its first real call; retry with the pure-Lua
    -- twin and keep using it from then on.
    if (not rects and not pp_is_pure) then
        local pure = loadPPBackend(PP_LIB_PURE)
        if (pure) then
            rects = runRectangulation(pure, image_data)
            if (rects) then
                pp_backend = pure
                pp_is_pure = true
                print("[Sprites] Perfect-pixel: the C backend failed, falling back to the pure-Lua one.")
            end
        end
    end

    if (not rects or #rects == 0) then
        pp_rects[image] = false
        return nil
    end

    pp_rects[image] = rects
    return rects
end

--- The raw rects of a sprite in IMAGE space (origin top-left, y down), before
--- scale / rotation / pivot are applied.
---@param sprite Sprite
---@return table|nil rects
function sprites.GetPPRects(sprite)
    if (not sprite) then return nil end
    return rectsForImage(sprite.image, sprite.path)
end

--- Map IMAGE-space rects to WORLD-space shapes ({x, y, w, h, angle}) through
--- the same pivot maths as Collisions.FollowShape, so a full-image rect
--- reproduces FollowShape's box and both paths agree.
---@param sprite Sprite
---@param rects table|nil List of {x, y, w, h}.
---@return table|nil shapes Nil when there is nothing to map.
local function imageRectsToWorld(sprite, rects)
    if (not rects or #rects == 0) then return nil end

    local angle = sprite.rotation or 0
    local rad = math.rad(angle)
    local cos_a, sin_a = math.cos(rad), math.sin(rad)
    local sx, sy = sprite.xscale or 1, sprite.yscale or 1

    -- Pivot offset in image pixels; image centre for a bare table without
    -- the prototype's GetPivotOffset.
    local ox, oy = (sprite.width or 0) * 0.5, (sprite.height or 0) * 0.5
    if (sprite.GetPivotOffset) then
        ox, oy = sprite:GetPivotOffset()
    end

    local shapes = {}
    for i = 1, #rects do
        local r = rects[i]
        local dx = ((r[1] + r[3] * 0.5) - ox) * sx
        local dy = ((r[2] + r[4] * 0.5) - oy) * sy
        shapes[i] = {
            x = sprite.x + dx * cos_a - dy * sin_a,
            y = sprite.y + dx * sin_a + dy * cos_a,
            w = math.abs(r[3] * sx),
            h = math.abs(r[4] * sy),
            angle = angle
        }
    end
    return shapes
end

--- The rectangulated shapes in WORLD space, shaped exactly like
--- Collisions.FollowShape so they go straight into RectangleWithRectangle.
--- Rects overlap rather than partition; their union is still the opaque pixels.
---@param sprite Sprite
---@return table|nil shapes Nil when the sprite has no usable tiling.
function sprites.GetPPShapes(sprite)
    if (not sprite) then return nil end
    return imageRectsToWorld(sprite, rectsForImage(sprite.image, sprite.path))
end

--- Choose the kind of shape this sprite collides as: `"ellipse"` or `"rect"`.
--- Synonyms accepted ("circle" / "oval" / "rectangle" / "box"). An unknown name
--- is refused and the sprite keeps the kind it already had.
---@param sprite Sprite
---@param kind string|nil "ellipse" / "rect" (or a synonym). nil = "rect".
---@return boolean ok False when `kind` is not a known shape name.
function sprites.SetHitboxShape(sprite, kind)
    if (type(sprite) ~= "table") then return false end

    local name = (kind == nil) and "rect" or (Collisions and Collisions.ShapeName(kind))
    if (not name) then
        print("[Sprites] SetHitboxShape: unknown shape '" .. tostring(kind) ..
            "' (use \"rect\" or \"ellipse\").")
        return false
    end

    sprite._hitbox_shape = name
    return true
end

--- The kind of shape this sprite collides as: `"ellipse"` or `"rect"`.
---@param sprite Sprite
---@return string "rect" when the sprite never chose one.
function sprites.GetHitboxShape(sprite)
    if (type(sprite) ~= "table") then return "rect" end
    return sprite._hitbox_shape or "rect"
end

--- The plain collision box in world space: the image rectangle with the
--- sprite's `_hitbox` ({width, height}) override applied. Same maths as
--- Collisions.FollowShape. Carries `shape` so Collisions.ShapeWithShape can
--- test it as an ellipse when the sprite asked for one.
---@param sprite Sprite
---@return table|nil {x, y, w, h, angle, shape}; nil only for an invalid sprite.
function sprites.GetHitbox(sprite)
    if (not sprite) then return nil end

    local shapes = imageRectsToWorld(sprite, {{0, 0, sprite.width or 0, sprite.height or 0}})
    local box = shapes[1]

    local hitbox = sprite._hitbox
    if (hitbox) then
        box.w = hitbox[1] or box.w
        box.h = hitbox[2] or box.h
    end
    box.shape = sprites.GetHitboxShape(sprite)
    return box
end

--- Axis-aligned half-extents of a (possibly rotated) rectangle, for the cheap
--- rejection pass in sprites.PPCollide.
---@param shape table {w, h, angle}
---@return number half_w
---@return number half_h
local function shapeHalfExtents(shape)
    local rad = math.rad(shape.angle or 0)
    local cos_a, sin_a = math.abs(math.cos(rad)), math.abs(math.sin(rad))
    local hw, hh = math.abs(shape.w) * 0.5, math.abs(shape.h) * 0.5
    return hw * cos_a + hh * sin_a, hw * sin_a + hh * cos_a
end

--- Perfect-pixel overlap test between two sprites.
--- Returns nil when NEITHER side opted in, so the caller keeps the plain-box
--- answer it already computed. A side without PP contributes its collision box.
--- An axis-aligned rejection runs first, so many-piece bullets stay cheap.
---@param a Sprite
---@param b Sprite
---@return boolean|nil
function sprites.PPCollide(a, b)
    local a_pp = (a ~= nil and a.pp_collision == true and a.image ~= nil)
    local b_pp = (b ~= nil and b.pp_collision == true and b.image ~= nil)
    if (not a_pp and not b_pp) then return nil end
    if (not Collisions) then return nil end

    -- No usable tiling: fall back to that side's box.
    local shapes_a = (a_pp and sprites.GetPPShapes(a)) or nil
    local shapes_b = (b_pp and sprites.GetPPShapes(b)) or nil
    if (not shapes_a) then shapes_a = {sprites.GetHitbox(a)} end
    if (not shapes_b) then shapes_b = {sprites.GetHitbox(b)} end

    local ext_a, ext_b = {}, {}
    for i = 1, #shapes_a do
        local hw, hh = shapeHalfExtents(shapes_a[i])
        ext_a[i] = {hw, hh}
    end
    for i = 1, #shapes_b do
        local hw, hh = shapeHalfExtents(shapes_b[i])
        ext_b[i] = {hw, hh}
    end

    for i = 1, #shapes_a do
        local ra = shapes_a[i]
        for j = 1, #shapes_b do
            local rb = shapes_b[j]
            if (math.abs(ra.x - rb.x) <= ext_a[i][1] + ext_b[j][1] and
                math.abs(ra.y - rb.y) <= ext_a[i][2] + ext_b[j][2]) then
                if (Collisions.RectangleWithRectangle(ra, rb)) then
                    return true
                end
            end
        end
    end

    return false
end

--- Drop every cached tiling and the resolved backend. Call after hot-reloading
--- PerfectPixel (F5 clears Scripts.Libraries) or changing art on disk.
function sprites.ClearPPCache()
    pp_rects = setmetatable({}, {__mode = "k"})
    pp_backend = nil
    pp_is_pure = false
end

-- Sprites are looked up in Game/Resources/Sprites/ first, then in the main
-- Resources/Sprites/ tree.
local SPRITE_ROOT = "Resources/Sprites/"
local GAME_SPRITE_ROOT = "Game/Resources/Sprites/"

--- Test whether a file exists on the LÖVE filesystem. LÖVE 11 returns a table
--- from getInfo, LÖVE 12 returns the info directly; both are tolerated.
---@param path string
---@return boolean
local function spriteFileExists(path)
    if (not path) then return false end

    local ok, info = pcall(function()
        return SE.filesystem.getInfo and SE.filesystem.getInfo(path)
    end)
    if (ok and info) then return true end

    local readable, data = pcall(function()
        return love.filesystem.read(path, 1)
    end)
    return (readable and data ~= nil)
end

--- Resolve a sprite path to the file that should actually be loaded.
--- Absolute and already-rooted Game paths are used as-is; otherwise the Game
--- copy wins over the main Resources/Sprites/ copy.
---@param path string
---@return string
local function resolveGameSpritePath(path)
    if (not path) or (path == "") then return nil end

    if (path:sub(1, 1) == "/") then
        return path
    end

    if (path:sub(1, #GAME_SPRITE_ROOT) == GAME_SPRITE_ROOT) then
        return path
    end

    if (path:sub(1, #SPRITE_ROOT) == SPRITE_ROOT) then
        local relative = path:sub(#SPRITE_ROOT + 1)
        local game_path = GAME_SPRITE_ROOT .. relative
        if (spriteFileExists(game_path)) then return game_path end
        return path
    end

    local game_path = GAME_SPRITE_ROOT .. path
    if (spriteFileExists(game_path)) then return game_path end

    return SPRITE_ROOT .. path
end

--- Normalise a sprite path into its final resolvable form.
---@param path string
---@param use_game boolean|nil When false the Game lookup is skipped entirely.
---@return string|nil
local function normalizeSpritePath(path, use_game)
    if not path or path == "" then
        return nil
    end

    path = path:gsub("\\", "/")

    if path:sub(1, 1) == "/" then
        return path
    end

    if (path:sub(1, #GAME_SPRITE_ROOT) == GAME_SPRITE_ROOT) then
        return path
    end

    if (path:sub(1, #SPRITE_ROOT) == SPRITE_ROOT) then
        if (use_game == false) then
            return path
        end
        local relative = path:sub(#SPRITE_ROOT + 1)
        local game_path = GAME_SPRITE_ROOT .. relative
        if (spriteFileExists(game_path)) then return game_path end
        return path
    end

    if (use_game == false) then
        return SPRITE_ROOT .. path
    end

    return resolveGameSpritePath(path)
end

local function findSpriteFromCache(path)
    local normalized_path = normalizeSpritePath(path)
    if not normalized_path then
        return nil, false
    end

    local entry = sprites.cache[normalized_path]
    if entry then
        return entry.img, entry.loaded
    end

    local img, imgData, loaded = loadImageSafe(normalized_path)
    rememberImageData(img, imgData)

    sprites.cache[normalized_path] = {
        img = img,
        imageData = imgData,
        loaded = loaded,
        last_used = os.time()
    }

    return img, loaded
end

-- Optional solidity: a sprite can opt into a real static Box2D fixture via
-- Sprite:Solid(...). All solid fixtures share ONE world, created lazily and
-- stepped once per frame at the end of sprites.Update.
local solid_world = nil

-- preSolve: "xy" (default) collides in every direction; "y" is a one-way
-- platform (only from above); "x" is a one-way wall (horizontal only).
local function solidPreSolve(fixtureA, fixtureB, contact)
    local dataA = fixtureA:getUserData() or {}
    local dataB = fixtureB:getUserData() or {}

    local solid, other
    if (dataA.type == "sprite.solid") then
        solid, other = dataA, fixtureB
    elseif (dataB.type == "sprite.solid") then
        solid, other = dataB, fixtureA
    else
        return
    end

    local axis = solid.axis or "xy"
    if (axis ~= "x" and axis ~= "y") then
        contact:setEnabled(true)
        return
    end

    if (not solid.body or solid.body:isDestroyed()) then return end
    local otherBody = (other and other.getBody) and other:getBody() or nil
    if (not otherBody or otherBody:isDestroyed()) then return end

    local sx, sy = solid.body:getPosition()
    local ox, oy = otherBody:getPosition()
    local _, ovy = otherBody:getLinearVelocity()
    local halfH = (solid.h or 0) * 0.5
    local halfW = (solid.w or 0) * 0.5

    local enabled = true
    if (axis == "y") then
        -- Above the top face, moving down or resting; jumping up passes through.
        enabled = (oy <= sy - halfH + 1) and (ovy >= 0)
    elseif (axis == "x") then
        -- Beside the wall's vertical band, so it can be jumped over.
        enabled = (math.abs(oy - sy) <= halfH + 4)
    end
    contact:setEnabled(enabled)
end

--- Get (and lazily create) the single Box2D world shared by solid sprites.
--- Sprite:Solid does this for you.
---@return userdata The Box2D world.
function sprites.GetSolidWorld()
    if (not solid_world or solid_world:isDestroyed()) then
        solid_world = SE.physics.newWorld(0, 0, true)
        solid_world:setCallbacks(
            function() end,  -- beginContact
            function() end,  -- endContact
            solidPreSolve,   -- preSolve (axis-aware solidity)
            function() end   -- postSolve
        )
    end
    return solid_world
end

function sprites.MultiDust(sprs, sound, remove, time)
    if not sprs or #sprs == 0 then return end
    time = time or 1.5

    local min_x, min_y = math.huge, math.huge
    local max_x, max_y = -math.huge, -math.huge

    for _, spr in ipairs(sprs) do
        local w = spr.width
        local h = spr.height
        local left = spr.x - spr.xpivot * w
        local top = spr.y - spr.ypivot * h
        local right = left + w
        local bottom = top + h
        if left < min_x then min_x = left end
        if top < min_y then min_y = top end
        if right > max_x then max_x = right end
        if bottom > max_y then max_y = bottom end
    end

    local canvas_w = math.max(1, math.ceil(max_x - min_x))
    local canvas_h = math.max(1, math.ceil(max_y - min_y))

    local dust_canvas = createStencilCanvas(canvas_w, canvas_h)
    local prev = SE.graphics.getCanvas()
    SE.graphics.setCanvas(dust_canvas)
    SE.graphics.clear(0, 0, 0, 0)
    for _, spr in ipairs(sprs) do
        if spr.image and spr.visible then
            local ox, oy = spr:GetPivotOffset()
            SE.graphics.setColor(spr.color[1], spr.color[2], spr.color[3], spr.alpha)
            applyFilter(spr.image, "nearest")
            SE.graphics.draw(
                spr.image,
                spr.x - min_x, spr.y - min_y,
                math.rad(spr.rotation),
                spr.xscale, spr.yscale,
                ox, oy
            )
        end
    end
    SE.graphics.setColor(1, 1, 1, 1)
    SE.graphics.setCanvas(prev)

    for _, spr in ipairs(sprs) do
        spr.visible = false
    end

    local dust_obj = {
        type = "object",
        layer = sprs[1].layer or 0,
        _dust = {
            use = true,
            time = time,
            duration = time,
            remove = remove or false,
            canvas = dust_canvas,
            sprs = sprs,
            x = min_x + canvas_w / 2,
            y = min_y + canvas_h / 2,
            w = canvas_w,
            h = canvas_h
        }
    }

    function dust_obj:Draw()
        if not self._dust.use then return end
        local shader = getDustShader()
        local progress = 1.0 - (self._dust.time / self._dust.duration)
        local eased = progress * progress * (3 - 2 * progress)
        shader:send("dt", self._dust.duration - self._dust.time)
        shader:send("scan_y", math.min(eased, 1.0))
        shader:send("screen_size_inv", {1/self._dust.w, 1/self._dust.h})
        shader:send("scale_factor", {1, 1})
        SE.graphics.setShader(shader)
        -- Baked at the sprites' real sub-pixel positions, so it gets the same
        -- whole-pixel snap when the switch is on.
        local dx, dy = self._dust.x, self._dust.y
        if (sprites.pixel_snap) then
            dx, dy = snapCoord(dx), snapCoord(dy)
        end
        SE.graphics.draw(
            self._dust.canvas,
            dx, dy, 0, 1, 1,
            self._dust.w / 2, self._dust.h / 2
        )
        SE.graphics.setShader()
    end

    function dust_obj:Update(dt)
        if not self._dust.use then return end
        self._dust.time = self._dust.time - dt
        if self._dust.time <= 0 then
            self._dust.use = false
            self._dust.canvas = nil
            if self._dust.remove then
                for _, spr in ipairs(self._dust.sprs) do
                    spr:Destroy()
                end
            else
                for _, spr in ipairs(self._dust.sprs) do
                    spr.visible = true
                end
            end
            Layers.remove(self)
            for i = #sprites.images, 1, -1 do
                if sprites.images[i] == self then
                    table.remove(sprites.images, i)
                    break
                end
            end
        end
    end

    Layers.add(dust_obj)
    table.insert(sprites.images, dust_obj)

    if (sound) then
        Audio.PlaySound("snd_dust.wav")
    end
end

--- Make a sprite shake in place for a short time.
--- The offset is applied ONLY at draw time, so the stored x / y (and therefore
--- Move / MoveTo / velocity / parents) is never disturbed.
---@param sprite   table          The sprite instance to shake.
---@param magnitude number|table  Max offset in pixels. A number shakes BOTH axes;
---                               a table {x = .., y = ..} shakes per axis (an
---                               omitted or 0 axis stays still).
---@param duration number|nil     Shake length in seconds. Default 0.5.
---@param speed    number|nil     Higher keeps near-full strength longer before
---                               settling; 1 fades across the whole duration.
function sprites.ShakeSprite(sprite, magnitude, duration, speed)
    if ((not sprite) or (not sprite.image)) then return end

    local mx, my
    if (type(magnitude) == "table") then
        mx = math.abs(magnitude.x or magnitude[1] or 0)
        my = math.abs(magnitude.y or magnitude[2] or 0)
    else
        mx = math.abs(magnitude or 0)
        my = mx
    end

    if (mx <= 0 and my <= 0) then return end

    local shake = sprite._shake
    if (not shake) then shake = {}; sprite._shake = shake end

    shake.use = true
    shake.duration = duration or 0.5
    shake.time = shake.duration
    shake.magnitude = {mx, my}
    shake.speed = speed or 1
    shake.dx = 0
    shake.dy = 0
end

--- Spawn a fading "shadow" copy of a sprite, like Player.AddParticle.
--- It starts on the source, follows it every frame, grows toward
--- `target_scale`, fades out over `duration`, then destroys itself.
---@param sprite       table        The sprite to copy.
---@param target_scale number|nil   Scale the shadow grows toward. Default 2.
---@param duration     number|nil   Lifetime in seconds. Default 0.5.
---@param speed        number|nil   Growth speed (higher = faster). Default 8.
---@return table|nil The spawned shadow sprite (nil if it could not be created).
function sprites.ShadowSprite(sprite, target_scale, duration, speed)
    if ((not sprite) or (not sprite.image)) then return nil end

    -- Draw just behind the source (only numeric layers can be offset).
    local layer = sprite.layer
    if (type(layer) == "number") then layer = layer - 0.1 end
    local shadow = sprites.CreateSprite(sprite.path, layer)
    if ((not shadow) or (not shadow.image)) then return nil end

    shadow:MoveTo(sprite:GetPosition())
    shadow.color = {sprite.color[1], sprite.color[2], sprite.color[3]}
    shadow.alpha = sprite.alpha or 1
    shadow.xscale = sprite.xscale or 1
    shadow.yscale = sprite.yscale or 1
    shadow.rotation = sprite.rotation or 0

    local life = duration or 0.5
    shadow._shadow = {
        use = true,
        source = sprite,
        target_scale = target_scale or 2,
        duration = life,
        time = life,
        speed = speed or 8,
        base_alpha = shadow.alpha
    }

    shadow.Step = function (self, dt)
        local st = self._shadow
        if ((not st) or (not st.use)) then return end

        if (st.source and st.source.image) then
            self:MoveTo(st.source:GetPosition())
        end

        local factor = math.min(1, (dt or 0) * st.speed)
        self:Scale(
            self.xscale + (st.target_scale - self.xscale) * factor,
            self.yscale + (st.target_scale - self.yscale) * factor
        )

        st.time = st.time - (dt or 0)
        if (st.time <= 0) then
            st.use = false
            self:Destroy()
        else
            self.alpha = st.base_alpha * (st.time / st.duration)
        end
    end

    return shadow
end

--- A Sprite instance created by sprites.CreateSprite / sprites.CreateSpriteQuad.
--- Methods live on `sprite_methods` and are reached through the metatable's
--- __index, so the language server sees them as real Sprite methods.
--- Instances are loose tables: extra gameplay fields can be attached freely.
---@class Sprite
---@field [string] any
---@field type string
---@field path string
---@field image any|nil
---@field quad table|nil
---@field width number
---@field height number
---@field x number
---@field y number
---@field xscale number
---@field yscale number
---@field rotation number
---@field move_speed number
---@field color table
---@field alpha number
---@field visible boolean
---@field layer number|string
---@field parent Sprite|nil
---@field children table
---@field Step? function
---@field velocity table
---@field speed table
local sprite_methods = {}

    function sprite_methods:Draw()
        if not self.visible then return end
        if not self.image then return end

        local ox, oy = self:GetPivotOffset()

        -- Shake and pixel snap are DRAW-ONLY: they are written into the
        -- "_x"/"_y" storage so every draw path picks them up, then restored.
        -- Stored x / y is never modified, so sub-pixel motion still accumulates.
        local base_x = rawget(self, "_x")
        local base_y = rawget(self, "_y")
        local draw_x, draw_y = base_x, base_y

        if (self._shake and self._shake.use) then
            draw_x = draw_x + (self._shake.dx or 0)
            draw_y = draw_y + (self._shake.dy or 0)
        end

        -- Snap the quad's EDGE, not its centre: parity-safe for odd-sized art.
        local snap = self.pixel_snap
        if (snap == nil) then snap = sprites.pixel_snap end
        if (snap) then
            draw_x = sprites.SnapEdge(draw_x, ox * (self.xscale or 1))
            draw_y = sprites.SnapEdge(draw_y, oy * (self.yscale or 1))
        end

        local shifted = (draw_x ~= base_x or draw_y ~= base_y)
        if (shifted) then
            rawset(self, "_x", draw_x)
            rawset(self, "_y", draw_y)
        end

        local stencil_active = (#self._stencils > 0)
        if stencil_active then
            Masks.Draw(self._stencils)  -- Write masks into stencil buffer
            Masks.Use()                 -- Activate stencil test
        end

        -- Dust overrides every other shader. It uses the baked canvas so the
        -- shader UV space stays axis-aligned regardless of rotation.
        if self._dust.use then
            local shader = getDustShader()
            local progress = 1.0 - (self._dust.time / self._dust.duration)
            local eased = progress * progress * (3 - 2 * progress)
            local elapsed = self._dust.duration - self._dust.time
            shader:send("dt", elapsed)
            shader:send("scan_y", math.min(eased, 1.0))
            shader:send("screen_size_inv", {1/self.width, 1/self.height})
            shader:send("scale_factor", {1, 1})
            SE.graphics.setShader(shader)
            SE.graphics.setColor(self.color[1], self.color[2], self.color[3], self.alpha)
            SE.graphics.draw(
                self._dust.canvas,
                self.x, self.y,
                math.rad(self.rotation),
                self.xscale, self.yscale,
                ox, oy
            )
            SE.graphics.setShader()
            SE.graphics.setColor(1, 1, 1, 1)
            if stencil_active then Masks.Clear() end
            if (shifted) then
                rawset(self, "_x", base_x)
                rawset(self, "_y", base_y)
            end
            return
        end

        if self.outline and not self._four_point.enabled then
            self:_drawOutline(ox, oy)
        end

        local shaders = self._shaders or {}

        if (#shaders > 0) then
            if (#shaders == 1) then
                SE.graphics.setShader(shaders[1])
                self:_drawImage(ox, oy)
                SE.graphics.setShader()
            else
                self:_drawWithShaderChain(ox, oy, shaders)
            end
        else
            self:_drawImage(ox, oy)
        end

        if stencil_active then Masks.Clear() end

        if (shifted) then
            rawset(self, "_x", base_x)
            rawset(self, "_y", base_y)
        end
    end

    function sprite_methods:_drawImage(ox, oy)
        if self._four_point.enabled then
            applyFilter(self.image, "nearest")
            self:_drawFourPointImage()
            return
        end

        local use_pixel_smooth = self.pixel_smooth and
                                #self._shaders == 0 and
                                math.abs(self.rotation) > 0.001

        if (use_pixel_smooth) then
            -- Linear filter + PixelSmooth shader keeps rotated pixel art crisp.
            -- Routed through applyFilter so the filter cache stays truthful.
            applyFilter(self.image, "linear")

            local shader = getPixelPerfectShader()
            SE.graphics.setShader(shader)
            shader:send("texture_pixel_size", {1/self.width, 1/self.height})

            SE.graphics.setColor(self.color[1], self.color[2], self.color[3], self.alpha)
            SE.graphics.draw(
                self.image,
                self.x, self.y,
                math.rad(self.rotation),
                self.xscale, self.yscale,
                ox, oy
            )
            SE.graphics.setShader()
            SE.graphics.setColor(1, 1, 1, 1)
        else
            applyFilter(self.image, "nearest")
            SE.graphics.setColor(self.color[1], self.color[2], self.color[3], self.alpha)
            SE.graphics.draw(
                self.image,
                self.x, self.y,
                math.rad(self.rotation),
                self.xscale, self.yscale,
                ox, oy
            )
            SE.graphics.setColor(1, 1, 1, 1)
        end
    end

    --- Draw an 8-directional outline behind the sprite: the 4 cardinal plus the
    --- 4 diagonal offsets, each exactly t pixels (square, not sqrt(2)-scaled).
    --- Always nearest-filtered and unshaded, so it stays crisp.
    function sprite_methods:_drawOutline(ox, oy)
        local outline = self.outline
        if not outline then return end

        local t = outline[5]
        if not t or t <= 0 then return end

        local a = outline[4]
        if not a or a <= 0 then return end

        applyFilter(self.image, "nearest")
        SE.graphics.setColor(outline[1] or 0, outline[2] or 0, outline[3] or 0, a)

        local rot = math.rad(self.rotation)
        SE.graphics.draw(self.image, self.x - t, self.y,      rot, self.xscale, self.yscale, ox, oy)
        SE.graphics.draw(self.image, self.x + t, self.y,      rot, self.xscale, self.yscale, ox, oy)
        SE.graphics.draw(self.image, self.x,      self.y - t, rot, self.xscale, self.yscale, ox, oy)
        SE.graphics.draw(self.image, self.x,      self.y + t, rot, self.xscale, self.yscale, ox, oy)
        SE.graphics.draw(self.image, self.x - t, self.y - t, rot, self.xscale, self.yscale, ox, oy)
        SE.graphics.draw(self.image, self.x - t, self.y + t, rot, self.xscale, self.yscale, ox, oy)
        SE.graphics.draw(self.image, self.x + t, self.y - t, rot, self.xscale, self.yscale, ox, oy)
        SE.graphics.draw(self.image, self.x + t, self.y + t, rot, self.xscale, self.yscale, ox, oy)

        SE.graphics.setColor(1, 1, 1, 1)
    end

    --- Internal: draw the sprite through the four-point deformation shader.
    --- Corner order: p1=top-left, p2=top-right, p3=bottom-left, p4=bottom-right.
    function sprite_methods:_drawFourPointImage()
        local fp = self._four_point

        if not sprites._four_point_shader then
            sprites._four_point_shader = SE.graphics.newShader("Scripts/Shaders/FourPoint.glsl")
        end
        local shader = sprites._four_point_shader

        local min_x = math.min(fp.p1[1], fp.p2[1], fp.p3[1], fp.p4[1])
        local min_y = math.min(fp.p1[2], fp.p2[2], fp.p3[2], fp.p4[2])
        local max_x = math.max(fp.p1[1], fp.p2[1], fp.p3[1], fp.p4[1])
        local max_y = math.max(fp.p1[2], fp.p2[2], fp.p3[2], fp.p4[2])
        local box_w = max_x - min_x
        local box_h = max_y - min_y

        if box_w <= 0 or box_h <= 0 then return end

        shader:send("p1", {fp.p1[1], fp.p1[2]})
        shader:send("p2", {fp.p2[1], fp.p2[2]})
        shader:send("p3", {fp.p3[1], fp.p3[2]})
        shader:send("p4", {fp.p4[1], fp.p4[2]})

        -- The quad is drawn stretched to the corners' bounding box; the shader
        -- computes the correct UV per pixel to produce the deformation.
        SE.graphics.setShader(shader)
        SE.graphics.setColor(self.color[1], self.color[2], self.color[3], self.alpha)
        applyFilter(self.image, "nearest")
        SE.graphics.draw(
            self.image,
            min_x, min_y,
            0,
            box_w / self.width, box_h / self.height,
            0, 0
        )
        SE.graphics.setShader()
        SE.graphics.setColor(1, 1, 1, 1)
    end

    function sprite_methods:_drawWithShaderChain(ox, oy, shaders)
        local prev_canvas = SE.graphics.getCanvas()
        local canvas1 = getTempCanvas(self.width, self.height)
        local canvas2 = getTempCanvas(self.width, self.height)

        SE.graphics.setCanvas(canvas1)
        SE.graphics.clear(0, 0, 0, 0)
        SE.graphics.setColor(self.color[1], self.color[2], self.color[3], self.alpha)
        SE.graphics.draw(self.image, 0, 0, 0, 1, 1, ox, oy)
        SE.graphics.setColor(1, 1, 1, 1)

        local source = canvas1
        local target = canvas2

        for _, shader in ipairs(shaders) do
            SE.graphics.setCanvas(target)
            SE.graphics.clear(0, 0, 0, 0)
            SE.graphics.setShader(shader)
            SE.graphics.draw(source)
            SE.graphics.setShader()
            source, target = target, source
        end

        SE.graphics.setCanvas(prev_canvas)
        SE.graphics.setColor(1, 1, 1, 1)
        SE.graphics.draw(
            source,
            self.x, self.y,
            math.rad(self.rotation),
            self.xscale, self.yscale,
            ox, oy
        )
        SE.graphics.setColor(1, 1, 1, 1)
    end

    function sprite_methods:Update(dt)
        -- Coordinate writes below are tracked by the metatable.
        self.speed.x = 0
        self.speed.y = 0
        self.is_moving = false

        -- Apply parent anchor first, then velocity on top: velocity always moves
        -- the sprite, even while it has a parent.
        if self.parent and self.parent.image then
            if self.follow_mode == "full" then
                local angle = math.rad(self.parent.rotation)
                local cos_a = math.cos(angle)
                local sin_a = math.sin(angle)
                self.x = self.parent.x + self.xanchor_px * cos_a - self.yanchor_px * sin_a
                self.y = self.parent.y + self.xanchor_px * sin_a + self.yanchor_px * cos_a
            else
                self.x = self.parent.x + self.xanchor_px
                self.y = self.parent.y + self.yanchor_px
            end
        end

        self.x = self.x + self.velocity.x * self.move_speed
        self.y = self.y + self.velocity.y * self.move_speed
        self.rotation = self.rotation + self.velocity.r

        if (self.Step) then
            self:Step(dt)
        end

        local anim = self.animation
        if (#anim.textures > 0) then
            anim.time = anim.time + dt
            if (anim.time >= anim.interval) then
                if (anim.mode == "loop") then
                    self:Set(anim.textures[anim.frame])
                    anim.frame = anim.frame % #anim.textures + 1
                elseif (anim.mode == "oneshot") then
                    self:Set(anim.textures[anim.frame])
                    anim.frame = anim.frame + 1

                    if (anim.frame > #anim.textures) then
                        anim.textures = {}
                    end
                elseif (anim.mode == "oneshot-empty" or anim.mode == "empty") then
                    if (anim.textures[anim.frame]) then
                        self:Set(anim.textures[anim.frame])
                    end
                    anim.frame = anim.frame + 1

                    if (anim.frame > #anim.textures + 1) then
                        anim.textures = {}
                        self.visible = false
                    end
                elseif (anim.mode == "looponce") then
                    -- Plays once, then holds the first frame until re-triggered.
                    if (not anim.done) then
                        self:Set(anim.textures[anim.frame])
                        anim.frame = anim.frame + 1

                        if (anim.frame > #anim.textures) then
                            anim.frame = 1
                            anim.done = true
                        end
                    end
                end
                anim.time = 0
            end
        end

        if (self._dust.use) then
            self._dust.time = self._dust.time - dt
            if self._dust.time <= 0 then
                self._dust.use = false
                self._dust.canvas = nil
                if self._dust.remove then
                    self:Destroy()
                end
            end
        end

        -- Shake is visual only: Draw() consumes the offset, x / y stay untouched.
        if (self._shake and self._shake.use) then
            local shake = self._shake
            shake.time = shake.time - dt
            if (shake.time <= 0) then
                shake.use = false
                shake.dx = 0
                shake.dy = 0
            else
                local life = math.max(0, shake.time / shake.duration)
                local amp_x = shake.magnitude[1] * math.min(1, life * shake.speed)
                local amp_y = shake.magnitude[2] * math.min(1, life * shake.speed)
                shake.dx = (amp_x > 0) and ((math.random() * 2 - 1) * amp_x) or 0
                shake.dy = (amp_y > 0) and ((math.random() * 2 - 1) * amp_y) or 0
            end
        end

        -- Keep the static fixture glued to the sprite's current centre.
        if (self._solid and self._solid.body and not self._solid.body:isDestroyed()) then
            self._solid.body:setPosition(self.x, self.y)
        end
    end

    function sprite_methods:GetPivotOffset()
        if (self.xpivot_px ~= 0 or self.ypivot_px ~= 0) then
            return self.xpivot_px, self.ypivot_px
        else
            return self.xpivot * self.width, self.ypivot * self.height
        end
    end

    function sprite_methods:GetFilter()
        return self.image:getFilter()
    end

    function sprite_methods:Dust(sound, remove, time)
        -- Bake the current image (whatever animation frame) so the dust shader
        -- works in local UV space regardless of rotation.
        local w = self.width
        local h = self.height
        local dust_canvas = createStencilCanvas(w, h)
        local prev = SE.graphics.getCanvas()
        SE.graphics.setCanvas(dust_canvas)
        SE.graphics.clear(0, 0, 0, 0)
        applyFilter(self.image, "nearest")
        SE.graphics.draw(self.image, 0, 0, 0, 1, 1, 0, 0)
        SE.graphics.setCanvas(prev)

        if (sound) then
            Audio.PlaySound("snd_dust.wav")
        end
        self._dust.canvas = dust_canvas
        self._dust.use = true
        self._dust.remove = remove or false
        self._dust.time = (time or 1)
        self._dust.duration = self._dust.time
    end

    --- Add or remove an outline. Calling without valid colours (or setting
    --- self.outline = nil) removes it.
    ---@param r number Red (0-1)
    ---@param g number Green (0-1)
    ---@param b number Blue (0-1)
    ---@param a number Alpha (0-1)
    ---@param t number Thickness in pixels
    function sprite_methods:Outline(r, g, b, a, t)
        if r == nil or g == nil or b == nil then
            self.outline = nil
            return
        end
        self.outline = {r, g, b, a or 1, t or 1}
    end

    --- Enable or disable four-point control mode: the texture is stretched so
    --- its corners land on the points from SetFourPoint / SetFourPointP, and
    --- x / y / rotation / xscale / yscale are NOT used.
    ---@param enabled boolean
    function sprite_methods:SetFourPointMode(enabled)
        self._four_point.enabled = enabled
    end

    --- Set all four corner points at once.
    --- Order: p1=top-left, p2=top-right, p3=bottom-left, p4=bottom-right.
    ---@param p1x number Top-left X
    ---@param p1y number Top-left Y
    ---@param p2x number Top-right X
    ---@param p2y number Top-right Y
    ---@param p3x number Bottom-left X
    ---@param p3y number Bottom-left Y
    ---@param p4x number Bottom-right X
    ---@param p4y number Bottom-right Y
    function sprite_methods:SetFourPoint(p1x, p1y, p2x, p2y, p3x, p3y, p4x, p4y)
        self._four_point.p1 = {p1x, p1y}
        self._four_point.p2 = {p2x, p2y}
        self._four_point.p3 = {p3x, p3y}
        self._four_point.p4 = {p4x, p4y}
    end

    --- Set a single corner point for four-point control.
    ---@param index integer Point index (1=top-left, 2=top-right, 3=bottom-left, 4=bottom-right)
    ---@param x     number X coordinate
    ---@param y     number Y coordinate
    function sprite_methods:SetFourPointP(index, x, y)
        local key = "p" .. index
        if self._four_point[key] then
            self._four_point[key][1] = x
            self._four_point[key][2] = y
        end
    end

    function sprite_methods:Move(x, y)
        self.x = self.x + x
        self.y = self.y + y
        -- Recalculate anchor_px so parent tracking stays correct
        if self.parent and self.parent.image then
            local dx = self.x - self.parent.x
            local dy = self.y - self.parent.y
            if self.follow_mode == "full" then
                local angle = math.rad(self.parent.rotation)
                local cos_a = math.cos(angle)
                local sin_a = math.sin(angle)
                self.xanchor_px = dx * cos_a + dy * sin_a
                self.yanchor_px = -dx * sin_a + dy * cos_a
            else
                self.xanchor_px = dx
                self.yanchor_px = dy
            end
        end
    end

    function sprite_methods:MoveTo(x, y)
        self.x = x
        self.y = y
        -- Recalculate anchor_px so parent tracking stays correct
        if self.parent and self.parent.image then
            local dx = self.x - self.parent.x
            local dy = self.y - self.parent.y
            if self.follow_mode == "full" then
                local angle = math.rad(self.parent.rotation)
                local cos_a = math.cos(angle)
                local sin_a = math.sin(angle)
                self.xanchor_px = dx * cos_a + dy * sin_a
                self.yanchor_px = -dx * sin_a + dy * cos_a
            else
                self.xanchor_px = dx
                self.yanchor_px = dy
            end
        end
    end

    function sprite_methods:Set(p)
        -- Store the fully resolved path, so path comparisons and repeat Set
        -- calls with the already-resolved value behave identically.
        local resolved_p = normalizeSpritePath(p) or p
        self.path = resolved_p
        self.image = findSpriteFromCache(resolved_p)
        if self.image then
            self.width = self.image:getWidth()
            self.height = self.image:getHeight()
        end

        -- A Set outside the animation force-replaces any active SetAnimation.
        -- Frame advances from the animation loop pass a frame already in the
        -- texture list, so those leave the animation intact.
        local anim = self.animation
        if (anim and #anim.textures > 0) then
            local p_norm = normalizeSpritePath(p)
            local is_anim_frame = false
            for i = 1, #anim.textures do
                if (normalizeSpritePath(anim.textures[i]) == p_norm) then
                    is_anim_frame = true
                    break
                end
            end
            if (not is_anim_frame) then
                self.animation = {
                    textures = {},
                    interval = 1 / 10,
                    mode = "loop",
                    time = 0,
                    frame = 1,
                    done = false
                }
            end
        end
    end

    --- The file actually displayed by this sprite.
    ---@return string|nil The resolved path ("Resources/Sprites/..." or "Game/Resources/Sprites/...").
    function sprite_methods:GetImagePath()
        return self.path
    end

    --- Whether this sprite is currently driven by an animation. Returns the
    --- frame list, not a path (despite the name).
    ---@return boolean
    function sprite_methods:GetAnimationPath()
        local anim = self.animation
        if (anim and anim.textures and #anim.textures > 0) then
            return anim.textures
        end
        return nil
    end

    function sprite_methods:SetAnimation(frames, interval, mode)
        self:Set(frames[1])
        self.animation = {
            textures = (frames or {}),
            interval = interval,
            mode = (mode or "loop"),
            time = 0,
            frame = 2,
            done = false
        }
    end

    function sprite_methods:Scale(x, y)
        self.xscale = x
        self.yscale = y
    end

    function sprite_methods:Pivot(x, y)
        self.xpivot = x
        self.ypivot = y
    end

    function sprite_methods:PivotPixel(x, y)
        self.xpivot_px = x
        self.ypivot_px = y
    end

    function sprite_methods:Anchor(x, y)
        self.xanchor = x
        self.yanchor = y
        -- Convert proportional anchor to pixel offset using parent dimensions
        if self.parent and self.parent.image then
            self.xanchor_px = x * self.parent.width
            self.yanchor_px = y * self.parent.height
        end
    end

    function sprite_methods:AnchorPixel(x, y)
        self.xanchor_px = x
        self.yanchor_px = y
    end

    function sprite_methods:SetParent(spr)
        self.parent = spr
    end

    function sprite_methods:SetChildren(children)
        self.children = children
    end

    function sprite_methods:AddChild(child)
        table.insert(self.children, child)
        child.parent = self
    end

    function sprite_methods:RemoveChild(child)
        for i = #self.children, 1, -1 do
            if (self.children[i] == child) then
                table.remove(self.children, i)
                child.parent = nil
                return true
            end
        end
        return false
    end

    function sprite_methods:GetPosition()
        return self.x, self.y
    end

    function sprite_methods:GetPositionParent()
        if self.parent and self.parent.image then
            return self.xanchor_px, self.yanchor_px
        else
            return self.x, self.y
        end
    end

    function sprite_methods:SetStencils(stencils)
        self._stencils = {}

        if not stencils then
            return
        end

        local list = type(stencils) == "table" and stencils or {stencils}

        for _, mask in ipairs(list) do
            if mask and type(mask) == "table" and mask.shape then
                table.insert(self._stencils, mask)
            elseif mask then
                print("[WARNING] sprite:SetStencils - Invalid mask object")
            end
        end
    end

    function sprite_methods:SetShaders(shaders)
        self._shaders = {}

        if not shaders then
            return
        end

        local shader_list = type(shaders) == "table" and shaders or {shaders}

        for _, shader in ipairs(shader_list) do
            if shader and type(shader) == "userdata" then
                table.insert(self._shaders, shader)
            elseif shader then
                print("[WARNING] sprite:SetShaders - Invalid shader object")
            end
        end
    end

    function sprite_methods:GetShaders()
        return self._shaders
    end

    function sprite_methods:ClearShaders()
        self._shaders = {}
    end

    function sprite_methods:AddShader(shader)
        if (not shader) then return end
        table.insert(self._shaders, shader)
    end

    function sprite_methods:InsertShader(index, shader)
        if (not shader) then return end
        table.insert(self._shaders, index, shader)
    end

    function sprite_methods:RemoveShader(shader)
        for i = #self._shaders, 1, -1 do
            if (self._shaders[i] == shader) then
                table.remove(self._shaders, i)
                return true
            end
        end
        return false
    end

    function sprite_methods:Destroy()
        -- Drop any solid collision body before removing the sprite.
        self:UnSolid()
        Layers.remove(self)
        for i = #sprites.images, 1, -1 do
            if (sprites.images[i] == self) then
                table.remove(sprites.images, i)
                break
            end
        end
    end

    function sprite_methods:Remove()
        self:Destroy()
    end

    --- Turn this sprite into a solid obstacle backed by a static Box2D body.
    --- The box is centred on the sprite and kept in sync every frame; all solid
    --- sprites share one world (see sprites.GetSolidWorld).
    ---@param axis string|nil "x" = solid horizontally only (one-way wall, can be
    ---                        jumped over / walked under); "y" = solid vertically
    ---                        only from the top (one-way platform); "xy" / nil =
    ---                        fully solid in every direction.
    ---@param box table|nil Optional {width = .., height = ..}; defaults to the
    ---                      sprite image size.
    function sprite_methods:Solid(axis, box)
        -- Also accept Sprite:Solid({width = .., height = ..}).
        if (type(axis) == "table") then
            box = axis
            axis = nil
        end
        if (type(axis) == "boolean") then
            axis = axis and "xy" or nil
        end
        axis = axis or "xy"
        if (axis ~= "x" and axis ~= "y") then axis = "xy" end

        -- Re-calling Solid replaces any previous collider.
        self:UnSolid()

        local w = (box and box.width) or self.width or 1
        local h = (box and box.height) or self.height or 1
        if (w <= 0) then w = 1 end
        if (h <= 0) then h = 1 end

        local world = sprites.GetSolidWorld()
        local body = SE.physics.newBody(world, self.x, self.y, "static")
        body:setFixedRotation(true)
        local shape = SE.physics.newRectangleShape(body, w, h)
        shape:setDensity(1)
        shape:setRestitution(0)
        shape:setFriction(0.1)
        shape:setUserData({
            type = "sprite.solid",
            sprite = self,
            body = body,
            axis = axis,
            w = w,
            h = h
        })

        self._solid = { body = body, shape = shape, axis = axis, w = w, h = h }
        return self
    end

    --- Remove the solid collision body from this sprite (if any).
    function sprite_methods:UnSolid()
        local solid = self._solid
        if (solid and solid.body and not solid.body:isDestroyed()) then
            solid.body:destroy()
        end
        self._solid = nil
        return self
    end

    --- Query whether this sprite is currently solid.
    ---@return string|false The active axis ("x", "y" or "xy"), or false when not solid.
    function sprite_methods:IsSolid()
        local solid = self._solid
        if (solid and solid.body and not solid.body:isDestroyed()) then
            return solid.axis or "xy"
        end
        return false
    end

    --- Turn perfect-pixel collision on or off. When on, the sprite collides as
    --- the rects tiling its opaque pixels; decide hits with sprites.PPCollide.
    --- `_hitbox` only applies while PP is off -- PP uses the art's real pixels.
    ---@param enabled boolean
    ---@return boolean ok Whether a usable tiling was found (false = PP stays off).
    ---@return integer count How many rectangles the tiling has.
    function sprite_methods:SetPPCollision(enabled)
        if (enabled ~= true) then
            self.pp_collision = false
            return false, 0
        end

        -- Resolve now, so a failure is visible at the call site rather than
        -- silently swallowing every hit later on.
        local shapes = sprites.GetPPShapes(self)
        if (not shapes) then
            self.pp_collision = false
            print("[Sprites] SetPPCollision: no rectangulation data for '" ..
                tostring(self.path) .. "' (image data or backend missing).")
            return false, 0
        end

        self.pp_collision = true
        return true, #shapes
    end

    --- Whether this sprite uses perfect-pixel collision.
    ---@return boolean
    function sprite_methods:IsPPCollision()
        return self.pp_collision == true
    end

    --- Collide as an ellipse inscribed in the same box (`_hitbox` / image size),
    --- so it only removes corners and never grows the hit area. Perfect-pixel
    --- collision, when on, replaces this shape entirely.
    ---@param kind string|nil "ellipse" (or "circle" / "oval"), "rect" (or
    ---                       "rectangle" / "box"); nil means "rect".
    ---@return boolean ok False when `kind` is not a known shape name.
    function sprite_methods:SetHitboxShape(kind)
        return sprites.SetHitboxShape(self, kind)
    end

    --- The kind of shape this sprite collides as: "ellipse" or "rect".
    ---@return string
    function sprite_methods:GetHitboxShape()
        return sprites.GetHitboxShape(self)
    end

---@param path string Sprite path relative to Resources/Sprites/ (no prefix); a
---                     Game/Resources/Sprites/ copy wins when it exists.
---@param layer number|string|nil Layer to place the sprite on.
---@return Sprite
function sprites.CreateSprite(path, layer)
    if (Global.GetVariable("SE_MEMORY_SAFETY")) then
        if (#sprites.images >= 2 * Global.GetVariable("OPT_COUNT_SPRITES")) then
            print("[Too many sprites warning] The number of sprite instances has reached 4000. Further generation has been disabled. To continue generating, set the SE_MEMORY_SAFETY variable to false, or increase the OPT_COUNT_SPRITES value.")
            return {}
        elseif (#sprites.images >= Global.GetVariable("OPT_COUNT_SPRITES")) then
            print("[Too many sprites warning] The number of sprite instances has reached 2000. Please check for any uncleared sprites.")
        end
    end

    ---@type Sprite
    local sprite = {}

    -- Intercept `layer` (mark Layers dirty) and `x` / `y` (track speed) writes.
    setmetatable(sprite, {
        __index = function(t, k)
            if k == "layer" then
                return rawget(t, "_layer_value")
            elseif k == "x" or k == "y" then
                return rawget(t, "_" .. k)
            end
            local v = rawget(t, k)
            if (v ~= nil) then return v end
            return sprite_methods[k]
        end,
        __newindex = function(t, k, v)
            if k == "layer" then
                rawset(t, "_layer_value", v)
                Layers.mark_dirty()
            elseif (k == "x" or k == "y") then
                local prev = rawget(t, "_" .. k)
                if (prev ~= v and t.speed) then
                    local d = v - prev
                    if (k == "x") then
                        t.speed.x = t.speed.x + d
                    else
                        t.speed.y = t.speed.y + d
                    end
                    rawset(t, "is_moving", true)
                end
                rawset(t, "_" .. k, v)
            else
                rawset(t, k, v)
            end
        end
    })

    sprite.type = "object"
    sprite.HurtMode = "normal"
    sprite._id = nil
    sprite._layer_id = nil
    sprite._layer_value = layer or 0
    sprite.is_moving = false
    sprite.pixel_smooth = false
    -- Perfect-pixel collision is opt-in: see sprite:SetPPCollision.
    sprite.pp_collision = false
    -- Resolve first (Game copy wins) so sprite.path names the file really loaded.
    local full_path = resolveGameSpritePath(path)
    sprite.path = full_path
    sprite.image, sprite._loaded = findSpriteFromCache(full_path)

    sprite.width = sprite.image:getWidth()
    sprite.height = sprite.image:getHeight()

    sprite.x = 320
    sprite.y = 240
    sprite.xscale = 1
    sprite.yscale = 1
    sprite.rotation = 0
    sprite.move_speed = 1

    sprite.velocity = {
        x = 0,
        y = 0,
        r = 0
    }

    sprite.speed = {
        x = 0,
        y = 0
    }

    sprite.xpivot = 0.5
    sprite.ypivot = 0.5
    sprite.xpivot_px = 0
    sprite.ypivot_px = 0
    sprite.xanchor = 0
    sprite.yanchor = 0
    sprite.xanchor_px = 0
    sprite.yanchor_px = 0

    sprite.color = {1, 1, 1}
    sprite.alpha = 1
    sprite.visible = true
    -- Optional outline: {r, g, b, a, thickness}. nil removes it.
    sprite.outline = nil

    sprite.parent = nil
    sprite.children = {}
    sprite.follow_mode = "position"

    sprite._has_move_to = false
    sprite._move_to_x = 0
    sprite._move_to_y = 0

    sprite._shaders = {}
    sprite._stencils = {}
    sprite._dust = {
        use = false,
        time = 0,
        duration = 0,
        remove = false
    }

    -- Shake state (see sprites.ShakeSprite). Visual only: the offset is applied
    -- at draw time and never written into x / y.
    sprite._shake = {
        use = false,
        time = 0,
        duration = 0,
        speed = 1,
        magnitude = {0, 0},
        dx = 0,
        dy = 0
    }

    sprite._four_point = {
        enabled = false,
        p1 = {0, 0},  -- top-left
        p2 = {0, 0},  -- top-right
        p3 = {0, 0},  -- bottom-left
        p4 = {0, 0},  -- bottom-right
    }

    sprite.animation = {
        textures = {},
        interval = 1 / 10,
        mode = "loop",
        time = 0,
        frame = 1,
        done = false
    }


    Layers.add(sprite)
    table.insert(sprites.images, sprite)
    return sprite
end

--- Create a sprite showing only a rectangular region ("quad") of a sheet. The
--- region is baked into a cropped image cached per region, so every sprite
--- feature (pivot, outline, dust, scaling, four-point) uses the region's size.
---@param path  string              Sheet path (same format as CreateSprite).
---@param quad  table               Region: {x = .., y = .., width = .., height = ..}
---@param layer number|string|nil   Layer for the sprite (same as CreateSprite).
---@return Sprite The new sprite (an empty table {} when it could not be created).
function sprites.CreateSpriteQuad(path, quad, layer)
    if ((not path) or (not quad)) then return {} end

    local qx = math.floor(quad.x or 0)
    local qy = math.floor(quad.y or 0)
    local qw = math.floor(quad.width or 0)
    local qh = math.floor(quad.height or 0)
    if (qw <= 0 or qh <= 0) then return {} end

    ---@type Sprite
    local sprite = sprites.CreateSprite(path, layer)
    if ((not sprite) or (not sprite.image)) then return sprite end

    -- Swap in a cropped copy so width / height match the region, not the sheet.
    local full_path = resolveGameSpritePath(path)
    local sheet_w = sprite.image:getWidth()
    local sheet_h = sprite.image:getHeight()

    if (qx + qw > sheet_w) then qw = sheet_w - qx end
    if (qy + qh > sheet_h) then qh = sheet_h - qy end
    if (qw <= 0 or qh <= 0) then return sprite end

    local crop_key = full_path .. "#" .. qx .. "," .. qy .. "," .. qw .. "," .. qh
    local entry = sprites.cache[crop_key]
    if (not entry) then
        local ok, crop_img, crop_data = pcall(function()
            local data = SE.image.newImageData(qw, qh)
            local source_entry = sprites.cache[full_path]
            local src_data = (source_entry and source_entry.imageData) or sprite.image:getImageData()
            if (src_data) then
                data:paste(src_data, 0, 0, qx, qy, qw, qh)
            end
            local img = SE.graphics.newImage(data)
            img:setFilter("nearest", "nearest")
            return img, data
        end)
        if (ok and crop_img) then
            entry = {
                img = crop_img,
                imageData = crop_data,
                loaded = true,
                last_used = os.time()
            }
            sprites.cache[crop_key] = entry
        end
    end

    if (entry) then
        sprite.image = entry.img
        rememberImageData(entry.img, entry.imageData)
        sprite.width = qw
        sprite.height = qh
        sprite.quad = {x = qx, y = qy, width = qw, height = qh}
    end
    -- On any crop failure the sprite keeps the full sheet image, so it still works.

    return sprite
end

function sprites.Update(dt)
    local now = os.time()

    if (Global.GetVariable("OPT_LRU_SPRITES")[1]) then
        if now - last_cache_cleanup >= CACHE_CLEAN_INTERVAL then
            local threshold = getLRUThreshold()

            -- Built FIRST so `last_used` reflects real rendering activity, not
            -- cache-access timestamps.
            local in_use_images = {}
            for _, spr in ipairs(sprites.images) do
                if spr.image then
                    in_use_images[spr.image] = true
                end
            end

            for k, entry in pairs(sprites.cache) do
                if entry and entry.last_used then
                    if in_use_images[entry.img] then
                        entry.last_used = now
                    elseif (now - entry.last_used) >= threshold then
                        pcall(function()
                            if entry.img and type(entry.img.release) == "function" then
                                entry.img:release()
                            end
                        end)
                        sprites.cache[k] = nil
                    end
                else
                    sprites.cache[k] = nil
                end
            end
            last_cache_cleanup = now
        end
    end

    for i = #sprites.images, 1, -1 do
        local sprite = sprites.images[i]
        if sprite then
            sprite:Update(dt)
        end
    end

    -- Step the shared solidity world once per frame. Sprites synced their own
    -- solid bodies in Update; any dynamic body is resolved here.
    if (solid_world and not solid_world:isDestroyed()) then
        solid_world:update(dt)
    end
end

function sprites.CleanupCache()
    local now = os.time()
    local threshold = getLRUThreshold()

    local in_use_images = {}
    for _, spr in ipairs(sprites.images) do
        if spr.image then
            in_use_images[spr.image] = true
        end
    end

    for k, entry in pairs(sprites.cache) do
        if entry and entry.last_used then
            if in_use_images[entry.img] then
                entry.last_used = now
            elseif (now - entry.last_used) >= threshold then
                pcall(function()
                    if entry.img and type(entry.img.release) == "function" then
                        entry.img:release()
                    end
                end)
                sprites.cache[k] = nil
            end
        else
            sprites.cache[k] = nil
        end
    end
end

--- Return debug information about the image cache.
---@return integer count Number of unique images cached.
---@return table details A list of cached paths with their last_used timestamps.
function sprites.GetCacheInfo()
    local count = 0
    local details = {}
    for k, entry in pairs(sprites.cache) do
        count = count + 1
        details[#details + 1] = {
            path = k,
            last_used = entry.last_used
        }
    end
    return count, details
end

--- Preload an image into the sprite cache without creating a sprite. The path
--- is normalised like CreateSprite does, so a later CreateSprite hits the cache;
--- re-entering an existing path just refreshes its timestamp.
---@param full_path string Full love-fs image path.
---@return boolean loaded Whether the image actually loaded (false = placeholder).
function sprites.PreloadFile(full_path)
    if (not full_path) then return false end
    local normalized = normalizeSpritePath(full_path)
    if (not normalized) then return false end
    local existing = sprites.cache[normalized]
    if (existing) then
        existing.last_used = os.time()
        return existing.loaded
    end
    local img, imgData, loaded = loadImageSafe(normalized)
    rememberImageData(img, imgData)
    sprites.cache[normalized] = {
        img = img,
        imageData = imgData,
        loaded = loaded,
        last_used = os.time()
    }
    return loaded
end

return sprites
