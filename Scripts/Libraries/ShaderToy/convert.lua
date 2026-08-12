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
        vec2 fragCoord = vec2(screen_coords.x, iResolution.y - screen_coords.y);
    ]] .. body .. [[
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

function convert.applyReplacementRules(code, rules)
    code = convert.wrapMainImage(code)

    for _, rule in ipairs(rules.REPLACEMENT_RULES) do
        code = code:gsub(rule.pattern, rule.replacement)
    end

    code = convert.safeTexel(code)

    return code
end

function convert.convert(shadercode, rules)
    local result = {
        code = "",
        externs = "",
        runtimeFlags = {},
        textures = {},
        audio = {},
    }

    local externCode, runtime, textures, audio = convert.detectUniforms(shadercode, rules)
    result.externs = externCode
    result.runtimeFlags = runtime
    result.textures = textures
    result.audio = audio

    local converted = convert.applyReplacementRules(shadercode, rules)
    result.code = externCode .. "\n" .. converted

    return result
end

return convert
