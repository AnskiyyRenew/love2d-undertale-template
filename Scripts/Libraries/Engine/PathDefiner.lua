local function findkeys(t)
    local keys = {}
    for k, _ in pairs(t) do
        table.insert(keys, k)
    end
    return keys
end

local function get_lib_extension()
    local os_name = love.system.getOS()
    if os_name == "Windows" then
        return ".dll"
    elseif os_name == "Linux" or os_name == "Android" then
        return ".so"
    elseif os_name == "macOS" or os_name == "iOS" then
        return ".dylib"
    else
        return ".so"
    end
end

local function load_dynamic_library(path)
    local ext = get_lib_extension()
    local ffi = require("ffi")

    local possible_paths = {
        path .. ext,
        "Resources/Libs/" .. path .. ext,
        "./" .. path .. ext,
        "./Resources/Libs/" .. path .. ext,
    }

    if ext == ".so" or ext == ".dylib" then
        table.insert(possible_paths, "Resources/Libs/lib" .. path .. ext)
        table.insert(possible_paths, "./lib" .. path .. ext)
    end

    local last_error = nil
    for _, full_path in ipairs(possible_paths) do
        local success, result = pcall(ffi.load, full_path)
        if success then
            return result, full_path
        else
            last_error = result
        end
    end

    error(string.format("Failed to load dynamic library '%s'\nTried paths: %s\nLast error: %s",
        path, table.concat(possible_paths, ", "), last_error or "unknown"), 2)
end

local function normalize_path(path)
    return path:gsub("[/\\]", ".")
end

---Import file from the specified path. Supports Lua scripts, shaders, and dynamic libraries. 
---@param path string The path to the file to import. Should be relative to the project root and use dot notation for Lua scripts.
---@param type? string The type of the file. Can be "default", "shader",
---@return any The loaded module, shader, or dynamic library.
---@return any The loaded module, shader, or dynamic library.
function ImportFile(path, type)
    if (not path) then
        error("ImportFile: path must be a non-empty string", 2)
    end
    if (path:match("^%s*$")) then
        error("ImportFile: path cannot be empty or whitespace", 2)
    end

    if (path:find("[/\\]")) then
        print("find slash in path, " .. path)
        path = normalize_path(path)
        print("normalize path to " .. path)
    end

    if (path:match("%.dll$") or path:match("%.so$") or path:match("%.dylib$")) then
        return load_dynamic_library(path:gsub("%.[^%.]+$", ""))
    end

    local path_type = {
        ["default"] = "Scripts.Libraries.",
        ["shader"] = "Scripts.Shaders.",
        ["dll"] = "Resources.Libs.",
        ["lua"] = "Scripts.Libraries.",
    }

    local respath
    if (not type or type == "") then
        respath = "Scripts.Libraries." .. path
    else
        local prefix = path_type[type:lower()]
        if (not prefix) then
            error(string.format("ImportFile: unsupported type '%s'. Supported: %s",
                type, table.concat(findkeys(path_type), ", ")), 2)
        end
        respath = prefix .. path
    end

    if (type and type:lower() == "shader") then
        local normalized_path = path:gsub("%.", "/")
        local shader_paths = {
            normalized_path .. ".glsl",
            "Scripts/Shaders/" .. normalized_path .. ".glsl",
            "Scripts/Shaders/" .. normalized_path .. ".lua",
        }

        local shader_code = nil
        for _, shader_path in ipairs(shader_paths) do
            local file = love.filesystem.read(shader_path)
            if (file) then
                shader_code = file
                break
            end
        end

        if (not shader_code) then
            error(string.format("ImportFile: shader file not found for '%s'\nTried: %s",
                path, table.concat(shader_paths, ", ")), 2)
        end

        local success, result = pcall(love.graphics.newShader, shader_code)
        if (not success) then
            error(string.format("ImportFile: failed to compile shader '%s'\nError: %s",
                path, result), 2)
        end
        return result
    end

    if (type and type:lower() == "dll") then
        return load_dynamic_library(respath)
    end

    local success, result = pcall(require, respath)
    if (not success) then
        error(string.format("ImportFile: failed to load '%s' (type: %s)\nError: %s",
            path, type or "default", result), 2)
    end

    return result
end