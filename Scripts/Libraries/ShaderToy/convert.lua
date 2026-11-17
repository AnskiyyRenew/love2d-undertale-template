local convert = {}

local function has(str, pattern)
    return str:find(pattern) ~= nil
end

function convert.detectUniforms(code, rules)
    local externs = {}
    local runtime = {}
    local textures = {}
    local audio = {}

    local function add(line)
        table.insert(externs, line)
    end

    for _, rule in ipairs(rules.UNIFORM_RULES) do
        if has(code, rule.token) then
            add(rule.extern)
            runtime[rule.flag] = true
        end
    end

    for _, rule in ipairs(rules.CHANNEL_RULES) do
        local name = rule.name
        if has(code, name) then
            if has(code, "texelFetch%s*%(" .. name) then
                add("extern Image " .. name .. ";")
                audio[name] = true
            else
                add("extern Image " .. name .. ";")
                textures[name] = true
            end
        end
    end

    return table.concat(externs, "\n"), runtime, textures, audio
end

function convert.wrapMainImage(code)
    return code:gsub("void%s+mainImage%s*%b()%s*%b{}", function(func)
        local body = func:match("%b{}"):sub(2, -2)
        return [[
    vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
    {
        vec2 fragCoord = vec2(texture_coords.x * iResolution.x, iResolution.y - texture_coords.y * iResolution.y);
        vec4 fragColor = vec4(0.0);
    ]] .. body .. [[
        fragColor *= vec4(1.0, 1.0, 1.0, Texel(texture, texture_coords).a);
        return fragColor;
    }
    ]]
    end)
end

function convert.safeTexel(code)
    return code:gsub("texture%s*%((.-)%)", function(args)
        local parts = {}
        local depth = 0
        local current = ""

        for i = 1, #args do
            local c = args:sub(i, i)

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

        if #parts >= 2 then
            return "Texel(" .. parts[1] .. "," .. parts[2] .. ")"
        else
            return "Texel(" .. args .. ")"
        end
    end)
end

--- Normalize the optional host-channel setting: a host channel reads the
--- sprite's own main texture instead of an external image.
---@param options table|number|nil
---@param rules table
---@return table hostChannels Set of channel ids bound to the main texture
---@return boolean flipY Whether the sampled UV needs its y component flipped
local function parseHostOptions(options, rules)
    local set = {}
    local flipY = true

    if type(options) == "number" then
        set[options] = true
    elseif type(options) == "table" then
        if type(options.hostChannel) == "number" then
            set[options.hostChannel] = true
        end
        if type(options.hostChannels) == "table" then
            for _, id in ipairs(options.hostChannels) do
                if type(id) == "number" then set[id] = true end
            end
        end
        if options.hostFlipY == false then flipY = false end
    end

    -- Drop out-of-range ids: they can never map to a real extern.
    for id in pairs(set) do
        if id < 0 or id >= rules.CHANNEL_COUNT or id ~= math.floor(id) then
            set[id] = nil
        end
    end

    return set, flipY
end

--- Rewrite texture(iChannelN, uv) into a read of the sprite's main texture.
--- Only the sampler is swapped, the UV expression is kept. ShaderToy's
--- fragCoord has y up, LÖVE's texture_coords has y down: the UV y is flipped
--- unless hostFlipY is disabled.
---@param code string
---@param name string Channel name, for example "iChannel0"
---@param flipY boolean
---@return string
function convert.redirectHostChannel(code, name, flipY)
    local out, from = {}, 1

    while true do
        local callStart, commaPos = code:find("%f[%w_]texture%s*%(%s*" .. name .. "%s*,", from)
        if not callStart then
            out[#out + 1] = code:sub(from)
            break
        end
        out[#out + 1] = code:sub(from, callStart - 1)

        -- Scan to the matching ')'; only the first argument (the UV) is kept,
        -- extra arguments are dropped (not GLSL ES 1.0).
        local depth, p = 0, commaPos + 1
        local uvEnd, callEnd = nil, nil
        while p <= #code do
            local c = code:sub(p, p)
            if c == "(" then
                depth = depth + 1
            elseif c == ")" then
                if depth == 0 then
                    callEnd = p
                    break
                end
                depth = depth - 1
            elseif c == "," and depth == 0 and not uvEnd then
                uvEnd = p - 1
            end
            p = p + 1
        end

        if not callEnd then
            -- Unbalanced call: keep the text instead of emitting broken GLSL.
            out[#out + 1] = code:sub(callStart)
            break
        end

        local uv = code:sub(commaPos + 1, uvEnd or callEnd - 1):match("^%s*(.-)%s*$")
        if flipY then
            out[#out + 1] = "Texel(texture, vec2((" .. uv .. ").x, 1.0 - (" .. uv .. ").y))"
        else
            out[#out + 1] = "Texel(texture, " .. uv .. ")"
        end
        from = callEnd + 1
    end

    return table.concat(out)
end

function convert.applyReplacementRules(code, rules, options)
    local hostChannels, flipY = parseHostOptions(options, rules)

    code = convert.wrapMainImage(code)

    for id = 0, rules.CHANNEL_COUNT - 1 do
        if hostChannels[id] then
            code = convert.redirectHostChannel(code, "iChannel" .. id, flipY)
        end
    end

    for _, rule in ipairs(rules.REPLACEMENT_RULES) do
        code = code:gsub(rule.pattern, rule.replacement)
    end

    code = convert.safeTexel(code)

    return code, hostChannels
end

function convert.convert(shadercode, rules, options)
    local result = {
        code = "",
        externs = "",
        runtimeFlags = {},
        textures = {},
        audio = {},
        hostChannels = {},
    }

    local externCode, runtime, textures, audio = convert.detectUniforms(shadercode, rules)
    result.externs = externCode
    result.runtimeFlags = runtime
    result.textures = textures
    result.audio = audio

    local converted, hostChannels = convert.applyReplacementRules(shadercode, rules, options)
    result.hostChannels = hostChannels

    -- A host channel samples the main texture, so drop its extern declaration
    -- if the original code has no other reference to that channel.
    for id in pairs(hostChannels) do
        local name = "iChannel" .. id
        local stripped = shadercode:gsub("texture%s*%(%s*" .. name .. "%s*,", "")
        if not stripped:find(name, 1, true) then
            externCode = externCode:gsub("extern Image " .. name .. ";", "")
        end
    end

    result.externs = externCode
    result.code = externCode .. "\n" .. converted

    return result
end

return convert
