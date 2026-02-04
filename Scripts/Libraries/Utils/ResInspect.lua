-- Usage:
-- local resinspect = require("resinspect")
-- resinspect.printGPUStats()
-- local tracker = resinspect.newTracker()
-- local img = tracker:loadImage("assets/sprite.png")
-- local snd = tracker:loadSound("assets/sfx.wav", {decode=true}) -- decode=true 会用 love.sound.newSoundData 来估算内存
-- tracker:printReport()

local resinspect = {}

-- pretty helper
local function mb(bytes) return string.format("%.2f MB", (bytes or 0) / 1024 / 1024) end

-- =========================
-- 直接打印 GPU / LÖVE 统计（最快）
-- =========================
function resinspect.printGPUStats()
    if not love or not love.graphics or not love.graphics.getStats then
        print("love.graphics.getStats() not available in this environment.")
        return
    end

    local stats = love.graphics.getStats()

    --print("=== LÖVE Graphics Stats ===")
    -- texturememory: estimated bytes used by Images / Canvases / Fonts in video memory
    --print(string.format("Texture memory (Images/Canvases/Fonts): %s (%d bytes)", mb(stats.texturememory), stats.texturememory or 0))
    print(string.format("Images loaded: %d", stats.images or 0))
    --print(string.format("Canvases: %d", stats.canvases or 0))
    print(string.format("Fonts: %d", stats.fonts or 0))
    -- draw call etc can be useful
    if stats.drawcalls then print("Draw calls (this frame): " .. stats.drawcalls) end
    if stats.canvasswitches then print("Canvas switches (this frame): " .. stats.canvasswitches) end
    --print("============================")

    --print("Note: 'texturememory' is an estimate of video memory used by Images/Canvases/Fonts (reported by love.graphics.getStats()).")
end

-- =========================
-- Resource tracker: 封装加载以便统计每个资源的估算占用（可选集成）
-- =========================
-- Example: tracker = resinspect.newTracker(); tracker:loadImage(path); tracker:loadFont(path,size); tracker:loadSound(path,{decode=true}); tracker:printReport()

local function safeExists(fn)
    return type(fn) == "function"
end

function resinspect.newTracker()
    local self = {
        images = {},   -- { path = {obj=image, w=..., h=..., estimate=bytes} }
        fonts = {},    -- { path = {obj=font, info=..., estimate=nil} } -- fonts often included in texturememory
        sounds = {},   -- { path = {obj=source, estimate=bytes, decoded=true/false} }
        videos = {},   -- optional
        others = {}
    }

    -- estimate bytes for Image: width * height * 4 (RGBA8) -- common approximation
    local function estimateImageBytes(img)
        if not img or not safeExists(img.getWidth) or not safeExists(img.getHeight) then return 0 end
        local w, h = img:getWidth(), img:getHeight()
        if not w or not h then return 0 end
        -- assume 4 bytes per pixel (RGBA8). Real driver compression or format may change this.
        return w * h * 4
    end

    -- loadImage wrapper
    function self:loadImage(path, ...)
        local img = love.graphics.newImage(path, ...)
        local estimate = estimateImageBytes(img)
        self.images[path] = {obj = img, w = img:getWidth(), h = img:getHeight(), estimate = estimate}
        return img
    end

    -- loadFont wrapper
    function self:loadFont(path_or_size, size)
        -- Two modes:
        -- 1) bitmap/font file path + size: love.graphics.newFont(path, size)
        -- 2) integer only -> love.graphics.newFont(size)
        local font
        local key
        if type(path_or_size) == "number" and not size then
            font = love.graphics.newFont(path_or_size)
            key = "system:" .. tostring(path_or_size)
        else
            font = love.graphics.newFont(path_or_size, size)
            key = tostring(path_or_size) .. ":" .. tostring(size)
        end
        -- We do not try to estimate texture bytes for font here: fonts are included in love.graphics.getStats().texturememory.
        self.fonts[key] = {obj = font, info = {name = tostring(path_or_size), size = size}}
        return font
    end

    -- loadSound wrapper (optional decode). If decode=true, we call love.sound.newSoundData(path)
    -- which fully decodes audio to RAM (useful to estimate raw memory). Decoding large music tracks will use memory.
    function self:loadSound(path, opts)
        opts = opts or {}
        local mode = opts.mode or "static" -- static or stream
        local decoded = false
        local estimate = 0
        local source
        -- If user asked to decode (and love.sound.newSoundData exists), decode to SoundData and get sample info:
        if opts.decode and love.sound and love.sound.newSoundData then
            local ok, sd = pcall(love.sound.newSoundData, path)
            if ok and sd then
                decoded = true
                -- SoundData methods: getSampleCount, getChannels, getBitDepth
                local samples = 0
                if safeExists(sd.getSampleCount) then samples = sd:getSampleCount() end
                local channels = 1
                if safeExists(sd.getChannels) then channels = sd:getChannels() end
                local bits = 16
                if safeExists(sd.getBitDepth) then bits = sd:getBitDepth() end
                -- bytes = samples * channels * (bits / 8)
                estimate = samples * channels * (bits / 8)
                -- create a Source from SoundData so it can be played
                source = love.audio.newSource(sd, mode)
            else
                -- fallback: create source directly (stream/static) without decoding full SoundData
                source = love.audio.newSource(path, mode)
            end
        else
            -- default: create a Source (may stream or keep in memory depending on mode and backend)
            source = love.audio.newSource(path, mode)
            -- we can't reliably estimate memory without decoding; leave estimate 0 and mark decoded=false
            estimate = 0
            decoded = false
        end

        self.sounds[path] = {obj = source, estimate = estimate, decoded = decoded, mode = mode}
        return source
    end

    -- loadVideo wrapper (basic)
    function self:loadVideo(path, opts)
        if not love.graphics.newVideo then
            return nil, "newVideo not available"
        end
        local vid = love.graphics.newVideo(path, opts)
        self.videos[path] = {obj = vid}
        return vid
    end

    -- filesystem-scan (aggregate disk sizes under a folder)
    function self:scanFilesystem(root, recursive)
        root = root or ""
        recursive = recursive == nil and true or recursive
        local totalsize = 0
        local function scan(dir)
            local items = love.filesystem.getDirectoryItems(dir)
            for _, name in ipairs(items) do
                local fp = (dir == "" and name) or (dir .. "/" .. name)
                local info = love.filesystem.getInfo(fp)
                if info then
                    if info.size then totalsize = totalsize + info.size end
                    if recursive and info.type == "directory" then scan(fp) end
                end
            end
        end
        if love and love.filesystem and love.filesystem.getDirectoryItems then
            pcall(scan, root)
        end
        return totalsize
    end

    -- produce report table
    function self:getReport()
        local rep = {
            gpu = {},
            images = {},
            fonts = {},
            sounds = {},
            totals = {estimated_ram = 0}
        }

        -- GPU totals using love.graphics.getStats
        if love and love.graphics and love.graphics.getStats then
            rep.gpu.stats = love.graphics.getStats()
        end

        -- images
        local img_total = 0
        for path, data in pairs(self.images) do
            img_total = img_total + (data.estimate or 0)
            rep.images[#rep.images + 1] = {path = path, w = data.w, h = data.h, estimate = data.estimate}
        end

        -- sounds
        local snd_total = 0
        for path, data in pairs(self.sounds) do
            snd_total = snd_total + (data.estimate or 0)
            rep.sounds[#rep.sounds + 1] = {path = path, decoded = data.decoded, mode = data.mode, estimate = data.estimate}
        end

        -- fonts (we don't estimate bytes here)
        for key, data in pairs(self.fonts) do
            rep.fonts[#rep.fonts + 1] = {key = key, info = data.info}
        end

        rep.totals.estimated_ram = img_total + snd_total
        rep.totals.images = img_total
        rep.totals.sounds = snd_total

        return rep
    end

    function self:printReport()
        local rep = self:getReport()
        print("==== Resource Tracker Report ====")
        if rep.gpu.stats then
            local s = rep.gpu.stats
            print(string.format("GPU texturememory (Images/Canvases/Fonts): %s (%d bytes)", mb(s.texturememory), s.texturememory or 0))
            print(string.format("GPU Images: %d, Canvases: %d, Fonts: %d", s.images or 0, s.canvases or 0, s.fonts or 0))
        end

        print("--- Images (estimates) ---")
        for _, info in ipairs(rep.images) do
            print(string.format("%s : %dx%d -> %s", info.path, info.w, info.h, mb(info.estimate)))
        end
        print("Images total estimate: " .. mb(rep.totals.images))

        print("--- Sounds (estimates) ---")
        for _, info in ipairs(rep.sounds) do
            local dec = info.decoded and "(decoded)" or "(not decoded)"
            print(string.format("%s %s -> %s", info.path, dec, mb(info.estimate)))
        end
        print("Sounds total estimate (decoded only): " .. mb(rep.totals.sounds))

        print("---- Fonts ----")
        for _, f in ipairs(rep.fonts) do
            print(string.format("%s (info: %s)", f.key, tostring(f.info.name or f.key)))
        end

        print("=== Estimated RAM used by tracked items (images + decoded sounds): " .. mb(rep.totals.estimated_ram) .. " ===")
        print("Note: This is an estimate. GPU texture usage shown above is the authoritative estimate for textures (love.graphics.getStats()).")
        print("====================================")
    end

    return self
end

-- Return module
return resinspect
