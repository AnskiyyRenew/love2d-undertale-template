local shadertoy = {
    functions = {},
    project = {}
}

shadertoy.functions.__index = shadertoy.functions

-- 工具函数：检测字符串存在
local function has(str, pattern)
    return str:find(pattern) ~= nil
end

local externs = [[
extern number iTime;
extern number iTimeDelta;
extern number iFrame;

extern vec3 iResolution;
extern vec4 iMouse;

extern Image iChannel0;
extern Image iChannel1;
extern Image iChannel2;
extern Image iChannel3;

extern vec3 iChannelResolution[4];
]]

local function detectUniforms(code)

    local externs = {}
    local runtime = {}
    local textures = {}
    local audio = {}

    local function add(line)
        table.insert(externs, line)
    end
    if code:find("iTime") then
        add("extern number iTime;")
        runtime.iTime = true
    end
    if code:find("iResolution") then
        add("extern vec3 iResolution;")
        runtime.iResolution = true
    end
    if code:find("iMouse") then
        add("extern vec4 iMouse;")
        runtime.iMouse = true
    end
    if code:find("iFrame") then
        add("extern int iFrame;")
        runtime.iFrame = true
    end
    if code:find("iChannelResolution") then
        add("extern vec3 iChannelResolution0;")
        add("extern vec3 iChannelResolution1;")
        add("extern vec3 iChannelResolution2;")
        add("extern vec3 iChannelResolution3;")
        runtime.iChannelResolution = true
    end
    for i = 0, 3 do
        local name = "iChannel" .. i

        if code:find(name) then
            -- 判断是否是音频
            if code:find("texelFetch%s*%(" .. name) then
                -- 音频模式
                add("extern Image " .. name .. ";")
                audio[name] = true
            else
                -- 普通纹理
                add("extern Image " .. name .. ";")
                textures[name] = true
            end
        end
    end

    return table.concat(externs, "\n"), runtime, textures, audio
end


-- 生成噪声纹理
function shadertoy.functions:generateNoiseTexture(size)
    size = size or 256
    local imageData = love.image.newImageData(size, size)

    for x = 0, size-1 do
        for y = 0, size-1 do
            local r = love.math.random()
            local g = love.math.random()
            local b = love.math.random()
            imageData:setPixel(x, y, r, g, b, 1)
        end
    end

    local img = love.graphics.newImage(imageData)
    img:setWrap("repeat", "repeat")
    img:setFilter("nearest", "nearest")
    return img
end

-- 转换 ShaderToy 代码为 LÖVE 格式
function shadertoy.convert(code)
    local shader = {
        original = code,
        code = "",
        runtimeFlags = {},
        time = 0,
        frame = 0,
        textures = {}
    }

    setmetatable(shader, shadertoy.functions)

    -- 转换 mainImage 函数为 LÖVE 的 effect 函数
    code = code:gsub("void%s+mainImage%s*%b()%s*%b{}", function(func)
        local body = func:match("%b{}"):sub(2,-2)
        return [[
    vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
    {
        vec2 fragCoord = vec2(screen_coords.x, iResolution.y - screen_coords.y);
    ]] .. body .. [[
    }
    ]]
    end)

    -- 替换关键字和语法
    code = code:gsub("iChannelResolution%[(%d)%]", "iChannelResolution%1")
    code = code:gsub("fragColor%s*=", "return ")
    code = code:gsub("texture%s*%(", "Texel(")
    code = code:gsub("gl_FragCoord", "screen_coords")
    code = code:gsub("precision%s+%w+%s+float%s*;", "")
    -- 安全替换 texture(a,b,c) → Texel(a,b)
    code = code:gsub("texture%s*%((.-)%)", function(args)

        local parts = {}
        local depth = 0
        local current = ""

        for i = 1, #args do
            local c = args:sub(i,i)

            if c == "(" then depth = depth + 1 end
            if c == ")" then depth = depth - 1 end

            if c == "," and depth == 0 then
                table.insert(parts, current)
                current = ""
            else
                current = current .. c
            end
        end

        table.insert(parts, current)

        -- 只取前两个参数
        if #parts >= 2 then
            return "Texel(" .. parts[1] .. "," .. parts[2] .. ")"
        else
            return "Texel(" .. args .. ")"
        end
    end)


    -- 检测并设置 uniform 变量
    local externCode, runtime, textures, audio = detectUniforms(shader.original)
    shader.runtimeFlags = runtime
    shader.externs = externCode
    shader.code = externCode .. "\n" .. code


    -- 生成默认噪声纹理
    for i=0,3 do
        if shader.runtimeFlags["iChannel"..i] and not shader.textures[i] then
            shader.textures[i] = shader:generateNoiseTexture(256)
        end
    end

    --sshader:printCode()
    shader.shader = love.graphics.newShader(shader.code)
    return shader
end

-- 项目管理相关函数
function shadertoy.newProject()
    local proj = {
        passes = {},
        time = 0,
        frame = 0
    }
    setmetatable(proj, shadertoy.project)
    return proj
end

function shadertoy.project:addPass(name, code)
    local shaderObj = shadertoy.convert(code)
    local w, h = love.graphics.getDimensions()

    local pass = {
        name = name,
        shaderObj = shaderObj,
        canvasA = love.graphics.newCanvas(w, h),
        canvasB = love.graphics.newCanvas(w, h),
        ping = true
    }

    table.insert(self.passes, pass)
end

function shadertoy.project:update(dt)
    self.time = self.time + dt
    self.frame = self.frame + 1
    for _,pass in ipairs(self.passes) do
        pass.shaderObj:update(dt)
    end
end

function shadertoy.project:draw()
    for i,pass in ipairs(self.passes) do
        local writeCanvas = pass.ping and pass.canvasA or pass.canvasB
        local readCanvas = pass.ping and pass.canvasB or pass.canvasA

        love.graphics.setCanvas(writeCanvas)
        love.graphics.clear()

        -- 设置前序通道纹理
        for j,prev in ipairs(self.passes) do
            if j < i then
                pass.shaderObj.shader:send("iChannel"..(j-1), 
                    prev.ping and prev.canvasA or prev.canvasB)
            end
        end

        pass.shaderObj:apply()
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
        pass.shaderObj:clear()
        love.graphics.setCanvas()
        pass.ping = not pass.ping
    end

    -- 输出最终结果到屏幕
    local finalPass = self.passes[#self.passes]
    local finalCanvas = finalPass.ping and finalPass.canvasB or finalPass.canvasA
    love.graphics.draw(finalCanvas)
end

-- 音频处理相关函数
function shadertoy.functions:setAudioChannel(id, filepath)
    local source = love.audio.newSource(filepath, "stream")
    source:setLooping(true)
    source:play()

    local soundData = love.sound.newSoundData(filepath)
    self.audio = {
        source = source,
        data = soundData,
        imageData = love.image.newImageData(512, 2),
        id = id
    }

    self.audio.image = love.graphics.newImage(self.audio.imageData)
    self.textures[id] = self.audio.image
end

function shadertoy.functions:printCode(mode, savePath)
    -- mode:
    -- nil / "final"     -> 打印转换后的最终代码
    -- "original"        -> 打印原始 shadertoy 代码
    -- "extern"          -> 只打印 extern 区域

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

    -- 如果指定保存路径
    if savePath then
        love.filesystem.write(savePath, target)
        print("[ShaderToy] Code saved to: " .. savePath)
    end

    return target
end


-- 简单 FFT 实现
local function simpleFFT(samples)
    local N = #samples
    local result = {}

    for k = 1, N do
        local re, im = 0, 0
        for n = 1, N do
            local angle = 2 * math.pi * (k-1)*(n-1)/N
            re = re + samples[n] * math.cos(angle)
            im = im - samples[n] * math.sin(angle)
        end
        result[k] = math.sqrt(re*re + im*im)
    end

    return result
end

-- 运行时更新函数
function shadertoy.functions:update(dt)
    self.time = self.time + dt
    self.frame = self.frame + 1
    local s = self.shader

    -- 更新 uniform 变量
    if self.runtimeFlags.iTime then
        self._time = (self._time or 0) + dt
        self:send("iTime", self._time)
    end

    if self.runtimeFlags.iResolution then
        local w, h = love.graphics.getDimensions()
        self:send("iResolution", {w, h, 1})
    end

    if self.runtimeFlags.iFrame then
        self._frame = (self._frame or 0) + 1
        self:send("iFrame", self._frame)
    end

    if self.runtimeFlags.iMouse then
        local mx, my = keyboard.GetMousePosition()
        self:send("iMouse", {mx, my, 0, 0})
    end

    -- 音频数据处理
    if self.audio then
        local pos = self.audio.source:tell()
        local rate = self.audio.data:getSampleRate()
        local startSample = math.floor(pos * rate)
        local samples = {}

        for i=0,511 do
            samples[i+1] = self.audio.data:getSample(startSample + i) or 0
        end

        local fft = simpleFFT(samples)
        for x=0,511 do
            local v = math.abs(fft[x+1] or 0)
            local wave = samples[x+1] or 0
            self.audio.imageData:setPixel(x, 0, v, v, v, 1)
            self.audio.imageData:setPixel(x, 1, wave*0.5+0.5, 0, 0, 1)
        end

        self.audio.image:replacePixels(self.audio.imageData)
    end

    -- 更新纹理分辨率信息
    if self.runtimeFlags.iChannelResolution then
        for i=0,3 do
            local tex = self.textures[i]
            if tex then
                local w, h = tex:getDimensions()
                s:send("iChannelResolution"..i, {w, h, 0})
            end
        end
    end

    -- 设置纹理通道
    for i=0,3 do
        if self.textures[i] then
            s:send("iChannel"..i, self.textures[i])
        end
    end
end

-- 工具函数
function shadertoy.functions:setChannel(id, texture)
    self.textures[id] = texture
end

function shadertoy.functions:apply()
    love.graphics.setShader(self.shader)
end

function shadertoy.functions:clear()
    love.graphics.setShader()
end

return shadertoy