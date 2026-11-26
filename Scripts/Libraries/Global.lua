local global = {}
local json = ImportFile("Utils.dkjson")

local save_file_name = "global_save.json"

--- Checks whether a value is one of the types allowed to be persisted.
---@param value any
---@return boolean
local function is_supported_value(value)
    local value_type = type(value)
    return value_type == "number" or value_type == "string" or value_type == "table"
end

--- Prints a prefixed warning message to the console.
---@param message string
local function warn(message)
    print("[Global WARNING] " .. message)
end

--- Resolves the full path of the save file, falling back to a relative name.
---@return string
local function get_save_path()
    if SE and SE.filesystem and SE.filesystem.getSaveDirectory then
        local dir = SE.filesystem.getSaveDirectory()
        if dir and dir ~= "" then
            return dir .. "/" .. save_file_name
        end
    end

    return save_file_name
end

--- Reads the save file from disk and returns the sanitized table of stored values.
---@return table
local function load_save_data()
    local data = {}
    local path = get_save_path()
    local contents

    if SE and SE.filesystem and SE.filesystem.read then
        contents = SE.filesystem.read(save_file_name)
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

--- Serializes the current save table and writes it to disk.
---@return boolean
local function save_save_data()
    local path = get_save_path()
    local encoded = json.encode(global._saveData or {})

    if type(encoded) ~= "string" then
        warn("Failed to encode save data.")
        return false
    end

    if (SE and SE.filesystem and SE.filesystem.write) then
        local ok = SE.filesystem.write(save_file_name, encoded)
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

--- Stores a non-persistent global value under the given name.
---@param name string
---@param value any
---@return any
function global.SetVariable(name, value)
    global[name] = value
    return value
end

--- Returns the global value stored under the given name.
---@param name string
---@return any
function global.GetVariable(name)
    return global[name]
end

--- Assigns a default value only when the global is currently unset.
---@param name string
---@param value any
---@return any
function global.EnsureVariable(name, value)
    if (not global[name]) then
        global[name] = value
    else
        return global[name]
    end
end

--- Stores a value and immediately persists it to the save file.
---@param name string
---@param value any
---@return boolean
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

--- Removes a saved value from memory and from the save file.
---@param name string
---@return boolean
function global.DeleteSaveVariable(name)
    if type(name) ~= "string" or name == "" then
        warn("DeleteSaveVariable requires a non-empty name.")
        return false
    end

    global._saveData[name] = nil
    global[name] = nil
    return save_save_data()
end

--- Reads a saved value straight from disk without caching it.
---@param name string
---@return any
function global.GetSaveVariable(name)
    local save_data = load_save_data()
    return save_data[name]
end

--- Returns the saved value for a name, creating and persisting a default when absent.
---@param name string
---@param value any
---@return any
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
