-- init.lua
-- ShaderToy main entry module.
-- Responsible for creating Shader / Project, and providing interfaces such as
-- use, unload, and update.
-- Conversion operations are handled by the convert module, and the conversion
-- rules are provided by the rules module.

local _p = (...):match("(.-)[^%.]+$")
local path = _p .. "ShaderToy."

local convert = require(path .. "convert")
local rules = require(path .. "rules")

---@class ShaderToyAudio
---@field source table
---@field data table
---@field imageData table
---@field image table?
---@field id integer

---@class ShaderToyShader
---@field original string
---@field code string
---@field externs string
---@field runtimeFlags table
---@field textures table
---@field audio ShaderToyAudio?
---@field time number
---@field frame integer
---@field _time number?
---@field _frame integer?
---@field shader table

---@class ShaderToyPass
---@field name string
---@field shaderObj ShaderToyShader
---@field canvasA table
---@field canvasB table
---@field ping boolean

---@class ShaderToyProject
---@field passes table
---@field time number
---@field frame integer

---@class ShaderToyModule
---@field functions table
---@field project table
local shadertoy = {
    functions = {},
    project = {}
}

shadertoy.functions.__index = shadertoy.functions

-- ==================== Shader Creation ====================

--- Generate a procedural noise texture with random RGB pixels.
--- Used to provide default data for shader channels that have no assigned texture.
---@param self ShaderToyShader
---@param size? integer Texture size (width and height). Defaults to rules.DEFAULT_NOISE_SIZE.
---@return table The generated noise image.
function shadertoy.functions:generateNoiseTexture(size)
    size = size or rules.DEFAULT_NOISE_SIZE
    local imageData = SE.image.newImageData(size, size)

    for x = 0, size - 1 do
        for y = 0, size - 1 do
            local r = SE.math.random()
            local g = SE.math.random()
            local b = SE.math.random()
            imageData:setPixel(x, y, r, g, b, 1)
        end
    end

    local img = SE.graphics.newImage(imageData)
    img:setWrap("repeat", "repeat")
    img:setFilter("nearest", "nearest")
    return img
end

--- Convert ShaderToy code into a LÖVE Shader instance.
--- The conversion is executed by the convert module, limited by the rules module.
---@param code string The original ShaderToy GLSL code.
---@return ShaderToyShader The created shader wrapper with conversion metadata.
function shadertoy.convert(code)
    local converted = convert.convert(code, rules)

    local shader = {
        original = code,
        code = converted.code,
        externs = converted.externs,
        runtimeFlags = converted.runtimeFlags,
        -- textures / audio are NOT taken from the detection result:
        -- the detection tables only hold flag names ("iChannel0" = true).
        -- Real textures are assigned via setChannel / setAudioChannel,
        -- and default noise textures are generated below.
        textures = {},
        time = 0,
        frame = 0,
        shader = nil,
    }

    setmetatable(shader, shadertoy.functions)

    for i = 0, rules.CHANNEL_COUNT - 1 do
        if shader.runtimeFlags["iChannel" .. i] and not shader.textures[i] then
            shader.textures[i] = shader:generateNoiseTexture(rules.DEFAULT_NOISE_SIZE)
        end
    end

    shader.shader = SE.graphics.newShader(shader.code)
    return shader
end

-- ==================== Project Management ====================

--- Create a new ShaderToy project, which manages multiple render passes.
---@return ShaderToyProject The newly created project instance.
function shadertoy.newProject()
    local proj = {
        passes = {},
        time = 0,
        frame = 0
    }
    setmetatable(proj, shadertoy.project)
    return proj
end

--- Add a render pass to the project.
---@param self ShaderToyProject
---@param name string The pass name.
---@param code string ShaderToy GLSL code for this pass.
function shadertoy.project:addPass(name, code)
    local shaderObj = shadertoy.convert(code)
    local w = CANVAS_WIDTH or SE.graphics.getWidth()
    local h = CANVAS_HEIGHT or SE.graphics.getHeight()

    local pass = {
        name = name,
        shaderObj = shaderObj,
        canvasA = SE.graphics.newCanvas(w, h),
        canvasB = SE.graphics.newCanvas(w, h),
        ping = true
    }

    table.insert(self.passes, pass)
end

--- Update the project and all its passes.
---@param self ShaderToyProject
---@param dt number Delta time since the last frame.
function shadertoy.project:update(dt)
    self.time = self.time + dt
    self.frame = self.frame + 1
    for _, pass in ipairs(self.passes) do
        pass.shaderObj:update(dt)
    end
end

--- Render all passes to canvases and draw the final result to the screen.
---@param self ShaderToyProject
function shadertoy.project:draw()
    for i, pass in ipairs(self.passes) do
        local writeCanvas = pass.ping and pass.canvasA or pass.canvasB
        local readCanvas = pass.ping and pass.canvasB or pass.canvasA

        SE.graphics.setCanvas(writeCanvas)
        SE.graphics.clear()

        -- 设置前序通道纹理
        for j, prev in ipairs(self.passes) do
            if j < i then
                pass.shaderObj.shader:send("iChannel" .. (j - 1),
                    prev.ping and prev.canvasA or prev.canvasB)
            end
        end

        pass.shaderObj:apply()
        SE.graphics.rectangle("fill", 0, 0, CANVAS_WIDTH or SE.graphics.getWidth(), CANVAS_HEIGHT or SE.graphics.getHeight())
        pass.shaderObj:clear()
        SE.graphics.setCanvas()
        pass.ping = not pass.ping
    end

    local finalPass = self.passes[#self.passes]
    local finalCanvas = finalPass.ping and finalPass.canvasB or finalPass.canvasA
    SE.graphics.draw(finalCanvas)
end

--- Unload the project, releasing all canvases and shader resources.
---@param self ShaderToyProject
function shadertoy.project:unload()
    for _, pass in ipairs(self.passes) do
        pass.canvasA:release()
        pass.canvasB:release()
        pass.shaderObj:unload()
    end
    self.passes = {}
end

-- ==================== Audio Handling ====================

--- Assign an audio channel to a shader texture slot and start playback.
--- The audio is converted into an FFT / waveform texture for the shader.
---@param self ShaderToyShader
---@param id integer The texture channel index (0-3).
---@param filepath string Path to the audio file.
function shadertoy.functions:setAudioChannel(id, filepath)
    local source = SE.audio.newSource(filepath, "stream")
    source:setLooping(true)
    source:play()

    local soundData = SE.sound.newSoundData(filepath)
    self.audio = {
        source = source,
        data = soundData,
        imageData = SE.image.newImageData(rules.AUDIO_IMAGE_WIDTH, rules.AUDIO_IMAGE_HEIGHT),
        id = id
    }

    self.audio.image = SE.graphics.newImage(self.audio.imageData)
    self.textures[id] = self.audio.image
end

-- Simple FFT implementation used for audio visualization.
---@param samples table Array of audio samples.
---@return table Magnitude spectrum of the samples.
local function simpleFFT(samples)
    local N = #samples
    local result = {}

    for k = 1, N do
        local re, im = 0, 0
        for n = 1, N do
            local angle = 2 * math.pi * (k - 1) * (n - 1) / N
            re = re + samples[n] * math.cos(angle)
            im = im - samples[n] * math.sin(angle)
        end
        result[k] = math.sqrt(re * re + im * im)
    end

    return result
end

-- ==================== Runtime Update ====================

--- Update the shader uniforms, audio data and textures at runtime.
--- Call this every frame while the shader is in use.
---@param self ShaderToyShader
---@param dt number Delta time since the last frame.
function shadertoy.functions:update(dt)
    self.time = self.time + dt
    self.frame = self.frame + 1
    local s = self.shader

    if self.runtimeFlags.iTime then
        self._time = (self._time or 0) + dt
        self.shader:send("iTime", self._time)
    end

    if self.runtimeFlags.iResolution then
        local w = CANVAS_WIDTH or SE.graphics.getWidth()
        local h = CANVAS_HEIGHT or SE.graphics.getHeight()
        self.shader:send("iResolution", {w, h, 1})
    end

    if self.runtimeFlags.iFrame then
        self._frame = (self._frame or 0) + 1
        self.shader:send("iFrame", self._frame)
    end

    if self.runtimeFlags.iMouse then
        local mx, my = Keyboard.GetMousePosition()
        self.shader:send("iMouse", {mx, my, 0, 0})
    end

    if self.audio then
        local pos = self.audio.source:tell()
        local rate = self.audio.data:getSampleRate()
        local startSample = math.floor(pos * rate)
        local samples = {}

        for i = 0, rules.AUDIO_IMAGE_WIDTH - 1 do
            samples[i + 1] = self.audio.data:getSample(startSample + i) or 0
        end

        local fft = simpleFFT(samples)
        for x = 0, rules.AUDIO_IMAGE_WIDTH - 1 do
            local v = math.abs(fft[x + 1] or 0)
            local wave = samples[x + 1] or 0
            self.audio.imageData:setPixel(x, 0, v, v, v, 1)
            self.audio.imageData:setPixel(x, 1, wave * 0.5 + 0.5, 0, 0, 1)
        end

        self.audio.image:replacePixels(self.audio.imageData)
    end

    if self.runtimeFlags.iChannelResolution then
        for i = 0, rules.CHANNEL_COUNT - 1 do
            local tex = self.textures[i]
            if tex then
                local w, h = tex:getDimensions()
                s:send("iChannelResolution" .. i, {w, h, 0})
            end
        end
    end

    for i = 0, rules.CHANNEL_COUNT - 1 do
        if self.textures[i] then
            s:send("iChannel" .. i, self.textures[i])
        end
    end
end

-- ==================== Utility Functions ====================

--- Set a texture for a shader channel.
---@param self ShaderToyShader
---@param id integer The texture channel index (0-3).
---@param texture table The texture to assign to the channel.
function shadertoy.functions:setChannel(id, texture)
    self.textures[id] = texture
end

--- Apply the shader (activate it for the current draw operations).
---@param self ShaderToyShader
function shadertoy.functions:apply()
    SE.graphics.setShader(self.shader)
end

--- Apply the shader (alias for apply).
shadertoy.functions.use = shadertoy.functions.apply

--- Clear the shader (deactivate it for the current draw operations).
---@param self ShaderToyShader
function shadertoy.functions:clear()
    SE.graphics.setShader()
end

--- Unload the shader, releasing its GPU resource.
---@param self ShaderToyShader
function shadertoy.functions:unload()
    if self.shader then
        self.shader:release()
        self.shader = nil
    end
end

--- Print and/or save the converted code.
---@param self ShaderToyShader
---@param mode? string Which code to output:
---  - nil / "final":   converted final code
---  - "original":      original ShaderToy code
---  - "extern":        extern declarations only
---@param savePath? string If provided, saves the code to this path.
---@return string? The selected code string (or nil if unavailable).
function shadertoy.functions:printCode(mode, savePath)
    -- mode:
    -- nil / "final"
    -- "original"   
    -- "extern"     

    local target = ""

    if mode == "original" then
        target = self.original or ""
    elseif mode == "extern" then
        target = self.externs or ""
    else
        target = self.code or ""
    end

    if type(target) ~= "string" then
        print("[ShaderToy] No code available.")
        return
    end

    local lines = {}
    for line in target:gmatch("[^\r\n]+") do
        table.insert(lines, line)
    end

    local total = #lines
    local digits = tostring(total):len()

    print("==================================================")
    print(" ShaderToy Converted Code (" .. (mode or "final") .. ")")
    print(" Total Lines: " .. total)
    print("==================================================")

    for i, line in ipairs(lines) do
        local num = tostring(i)
        local padding = string.rep(" ", digits - #num)
        print(padding .. num .. " | " .. line)
    end

    print("==================================================")

    if savePath then
        SE.filesystem.write(savePath, target)
        print("[ShaderToy] Code saved to: " .. savePath)
    end

    return target
end

return shadertoy
