local global = {}
local json = ImportFile("Utils.dkjson")

local save_file_name = "global_save.json"

local function is_supported_value(value)
    local value_type = type(value)
    return value_type == "number" or value_type == "string" or value_type == "table"
end

local function warn(message)
    print("[WARNING] " .. message)
end

local function get_save_path()
    if love and love.filesystem and love.filesystem.getSaveDirectory then
        local dir = love.filesystem.getSaveDirectory()
        if dir and dir ~= "" then
            return dir .. "/" .. save_file_name
        end
    end

    return save_file_name
end

local function load_save_data()
    local data = {}
    local path = get_save_path()
    local contents

    if love and love.filesystem and love.filesystem.read then
        contents = love.filesystem.read(path)
    elseif io then
        local file = io.open(path, "r")
        if file then
            contents = file:read("*a")
            file:close()
        end
    end

    if not contents or contents == "" then
        return data
    end

    local decoded, _, err = json.decode(contents)
    if not decoded then
        warn("Failed to decode save data from " .. path .. ": " .. tostring(err))
        return data
    end

    if type(decoded) ~= "table" then
        warn("Save data must be stored as a table.")
        return data
    end

    for name, value in pairs(decoded) do
        if not is_supported_value(value) then
            warn("Ignored invalid save value for '" .. tostring(name) .. "'.")
        else
            data[name] = value
        end
    end

    return data
end

local function save_save_data()
    local path = get_save_path()
    local encoded = json.encode(global._saveData or {})

    if type(encoded) ~= "string" then
        warn("Failed to encode save data.")
        return false
    end

    if (love and love.filesystem and love.filesystem.write) then
        local ok = love.filesystem.write(path, encoded)
        if ok then
            return true
        end

        warn("Failed to write save data to " .. path)
        return false
    elseif io then
        local file = io.open(path, "w")
        if not file then
            warn("Failed to open save file for writing: " .. path)
            return false
        end

        file:write(encoded)
        file:close()
        return true
    end

    warn("Filesystem is not available for save data.")
    return false
end

global._saveData = load_save_data()

function global.SetVariable(name, value)
    global[name] = value
    return true
end

function global.GetVariable(name)
    return global[name]
end

function global.EnsureVariable(name, value)
    if (not global[name]) then
        global[name] = value
    else
        return global[name]
    end
end

function global.SetSaveVariable(name, value)
    if not is_supported_value(value) then
        warn("SetSaveVariable only supports number, string, and table values.")
        return false
    end

    global._saveData[name] = value
    global[name] = value
    save_save_data()
    return true
end

function global.GetSaveVariable(name)
    if global._saveData and global._saveData[name] ~= nil then
        return global._saveData[name]
    end

    return global[name]
end

function global.EnsureSaveVariable(name, value)
    if global._saveData and global._saveData[name] ~= nil then
        return global._saveData[name]
    end

    if global[name] ~= nil then
        return global[name]
    end

    if not is_supported_value(value) then
        warn("EnsureSaveVariable only supports number, string, and table values.")
        return false
    end

    global._saveData[name] = value
    global[name] = value
    save_save_data()
    return value
end

return global