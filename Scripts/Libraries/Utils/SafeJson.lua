local safejson = {}
safejson.json = ImportFile("Utils.dkjson")

safejson.config = {
    badwords = {
        ["__index"] = true,
        ["coroutine"] = true,
        ["getmetatable"] = true,
        ["eval"] = true,
        ["exec"] = true,
        ["execscript"] = true,
        ["function"] = true,
        ["__proto__"] = true,
        ["constructor"] = true,
        ["prototype"] = true,
        ["settimeout"] = true,
        ["setinterval"] = true,
        ["window"] = true,
        ["document"] = true,
        ["global"] = true,
        ["process"] = true,
        ["import"] = true,
        ["require"] = true,
        ["XMLHttpRequest"] = true,
        ["fetch"] = true,
        ["WebSocket"] = true,
        ["localStorage"] = true,
        ["sessionStorage"] = true,
        ["alert"] = true,
        ["confirm"] = true,
        ["prompt"] = true,
        ["evalscript"] = true,

        ["script"] = true,
        ["iframe"] = true,
        ["onload"] = true,
        ["onerror"] = true,
        ["javascript:"] = true,
        ["os.execute"] = true,
        ["io.popen"] = true,
        ["\x00"] = true,
        ["\\u0000"] = true
    },
    max_depth = 100,
    max_items = 12000,
    max_string_length = 1e6,
    enable_precheck = true,
}

local error_types = {
    MALFORMED = 1,
    UNSAFE_KEY = 2,
    CIRCULAR = 3,
    OVER_LIMIT = 4
}

--- Decodes escaped unicode sequences in a string into lowercase UTF-8 characters.
---@param str string
---@return string
local function normalize_unicode(str)
    return str:gsub("\\u([%da-fA-F][%da-fA-F][%da-fA-F][%da-fA-F])", function(u)
        return utf8.char(tonumber(u, 16)):lower()
    end)
end

--- Rejects payloads containing suspicious escape sequences or injection patterns.
---@param str string
---@return boolean
---@return string|nil
local function precheck_json(str)
    if str:find("\\u[0-9a-fA-F][0-9a-fA-F]00") then
        return false, "Suspicious Unicode escape sequence"
    end
    if str:find("\\x[0-9a-fA-F][0-9a-fA-F]") and str:find("\\u[0-9a-fA-F]") then
        return false, "Mixed encoding detected"
    end
    if str:find("%[.-%].-:%[") then
        return false, "Array injection pattern detected"
    end
    if str:find("\\u?0+0") or str:find("\\x0 * 0") then
        return false, "Null byte bypass attempt"
    end
    return true
end

--- Detects a leading UTF-8 byte order mark in the payload.
---@param str string
---@return boolean
---@return string|nil
local function check_bom(str)
    if str:sub(1,3) == "\xEF\xBB\xBF" then
        return false, "BOM header detected"
    end
    return true
end

--- Verifies that no debug hook is installed, which would indicate tampering.
---@return boolean
---@return string|nil
local function anti_tamper_check()
    if debug and debug.gethook then
        local hook = debug.gethook()
        if hook ~= nil then
            return false, "Debug hook detected"
        end
    end
    return true
end

--- Checks that current memory usage stays below the configured cap.
---@return boolean
---@return string|nil
local function check_resource_limits()
    local max_mem = 100 * 1024 * 1024
    if collectgarbage("count") * 1024 > max_mem then
        return false, "Memory limit exceeded"
    end
    return true
end

--- Recursively validates a decoded value against depth, size, cycle and keyword limits.
---@param obj any
---@param path string|nil
---@param visited table|nil
---@param item_count number|nil
---@param depth number|nil
---@param config table
---@return boolean
---@return string|nil
local function check_object_safety(obj, path, visited, item_count, depth, config)
    path = path or ""
    visited = visited or {}
    item_count = item_count or 0
    depth = depth or 0

    if (visited[obj]) then
        return false, path .. " contains circular reference"
    end
    visited[obj] = true

    if (depth > config.max_depth) then
        return false, path .. " exceeds maximum depth"
    end
    if (item_count > config.max_items) then
        return false, path .. " exceeds maximum item count"
    end

    if (type(obj) == "number" and (obj ~= obj or math.abs(obj) == math.huge)) then
        return false, path .. " contains invalid number"
    end

    if (type(obj) == "table") then
        for k, v in pairs(obj) do
            item_count = item_count + 1
            if (item_count > config.max_items) then
                return false, path .. " exceeds maximum item count"
            end

            if (type(k) == "string" and config.badwords[k:lower()]) then
                return false, path .. " contains dangerous key: " .. k
            end

            if (type(v) == "string") then
                if (#v > config.max_string_length) then
                    return false, path .. " string too long"
                end
                local lower_v = v:lower()
                for word in pairs(config.badwords) do
                    if (lower_v:find(word, 1, true)) then
                        return false, path .. " contains dangerous value: " .. word
                    end
                end
            end

            local ok, err = check_object_safety(
                v,
                path .. (path == "" and "" or ".") .. tostring(k),
                visited,
                item_count,
                depth + 1,
                config
            )
            if (not ok) then return false, err end
        end
    end

    return true
end

--- Decodes a JSON string after running all safety checks, returning an error and code on failure.
---@param jsonString string
---@param options table|nil
---@return table|nil
---@return string|nil
---@return number|nil
function safejson.parse(jsonString, options)
    if type(jsonString) == "string" then
        jsonString = normalize_unicode(jsonString)
    end

    local ok, err = check_bom(jsonString)
    if not ok then return nil, err, error_types.MALFORMED end

    ok, err = anti_tamper_check()
    if not ok then return nil, err, error_types.UNSAFE_KEY end

    local config = setmetatable(options or {}, { __index = safejson.config })

    if config.enable_precheck and type(jsonString) == "string" then
        ok, err = precheck_json(jsonString)
        if not ok then return nil, err, error_types.MALFORMED end

        local max_precheck_length = math.min(#jsonString, config.max_string_length)
        local precheck_str = jsonString:sub(1, max_precheck_length):lower()
        for word in pairs(config.badwords) do
            if precheck_str:find(word, 1, true) then
                return nil, "Unsafe JSON detected (pre-check): " .. word, error_types.UNSAFE_KEY
            end
        end
    end

    local jsonData, _, err = safejson.json.decode(jsonString, 1, nil)
    if err then return nil, "JSON parsing error: " .. err, error_types.MALFORMED end

    ok, err = check_resource_limits()
    if not ok then return nil, err, error_types.OVER_LIMIT end

    local ok, safety_err = check_object_safety(jsonData, "", nil, 0, 0, config)
    if (not ok) and safety_err then
        return nil, "Unsafe JSON structure: " .. safety_err,
               (safety_err:find("exceeds") and error_types.OVER_LIMIT or error_types.UNSAFE_KEY)
    end

    return jsonData
end

--- Serializes a Lua value into a JSON string.
---@param value any
---@return string
function safejson.encode(value)
    return safejson.json.encode(value)
end

return safejson
