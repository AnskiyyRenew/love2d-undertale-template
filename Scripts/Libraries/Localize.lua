local localize = {}
local dkjson = ImportFile("Utils.dkjson")
localize.currentLanguage = nil

-- Localization lookup roots, tried in order. A translation file placed in the
-- Game area (Game/Localization/) overrides the engine default
-- (Localization/); when no Game copy exists the root file is used as before.
local ROOT_LOCALIZATION = "Localization/"
local GAME_LOCALIZATION = "Game/Localization/"

--- Read a localization JSON file, preferring the Game copy.
---@param language string Language code, e.g. "en" or "zh_CN".
---@return string|nil content The decoded-able JSON text.
---@return string|nil path The path that was actually read.
local function readLocalizationFile(language)
    if (type(language) ~= "string") or (language == "") then
        return nil, nil
    end

    local file_name = language .. ".json"
    local candidate_paths = {
        GAME_LOCALIZATION .. file_name,
        ROOT_LOCALIZATION .. file_name
    }

    local last_error
    for _, path in ipairs(candidate_paths) do
        local ok, content = pcall(love.filesystem.read, path)
        if (not ok) then
            last_error = content
        elseif (content) then
            return content, path
        end
    end

    if (last_error) then
        print("[L10N WARNING] Failed reading " .. file_name .. ": " .. tostring(last_error))
    end
    return nil, nil
end

--- Path that would be used for a language, preferring the Game copy.
--- Exposed mainly for debugging / tooling.
---@param language string
---@return string
function localize.GetLanguagePath(language)
    local _, path = readLocalizationFile(language)
    return path or (ROOT_LOCALIZATION .. tostring(language) .. ".json")
end

function localize.setFile(language)
    if (type(language) ~= "string") then
        print("[L10N WARNING] Invalid language file.")
        return
    end

    localize.currentLanguage = language

    local ok, err = pcall(function ()
        local content, path = readLocalizationFile(language)
        if not content then
            error("Could not read Localization/" .. language .. ".json (Game override or root)")
        end
        local decoded, pos, parseErr = dkjson.decode(content)
        if not decoded then
            error("JSON parse error at position " .. tostring(pos) .. " in " .. tostring(path) .. ": " .. tostring(parseErr))
        end
        localize.file = decoded
        localize.currentFile = path
    end)

    if (ok) then
        print("[L10N] L10n has started successfully, using language: " .. language .. " (" .. tostring(localize.currentFile) .. ")")
    else
        print("[L10N WARNING] Invalid language file.\n               Using default language. (en)\n[L10N Error]   " .. err)
        local content, path = readLocalizationFile("en")
        if content then
            local decoded = dkjson.decode(content)
            localize.file = decoded
            localize.currentFile = path
        end
    end
end

function localize.reload()
    if localize.currentLanguage then
        print("[L10N] Reloading localization: " .. localize.currentLanguage)
        localize.setFile(localize.currentLanguage)
    else
        print("[L10N WARNING] No language loaded to reload.")
    end
end

function localize.localizeText(elements, formats)
    local file = localize.file
    if not file then
        -- Load default
        local content, path = readLocalizationFile("en")
        if content then
            file = dkjson.decode(content)
            localize.file = file
            localize.currentFile = path
        else
            print("[L10N WARNING] Could not load default localization.")
            return nil
        end
    end
    if (not file) then return end

    -- Build the dot-separated key from elements
    local key
    if type(elements) == "string" then
        key = elements
    elseif type(elements) == "table" then
        local parts = {}
        for i = 1, #elements do
            if type(elements[i]) == "string" then
                table.insert(parts, elements[i])
            end
        end
        if #parts > 0 then
            key = table.concat(parts, ".")
        else
            print("[L10N WARNING] Invalid localization key table.")
            return nil
        end
    else
        print("[L10N WARNING] Invalid localization key.")
        return nil
    end

    -- Direct lookup using the flat dot-notation key
    local current = file[key]

    if current == nil then
        print("[L10N WARNING] Missing localization key: " .. tostring(elements))
        return nil
    end

    -- Apply real string.format substitutions to a single string
    -- (supports %s, %d, %f, %x, ...)
    local function applyFormats(text)
        if formats == nil then
            return text
        end
        if type(formats) ~= "table" then
            formats = { formats }
        end

        local ok, result = pcall(string.format, text, unpack(formats))
        if ok then
            return result
        else
            print("[L10N WARNING] string.format failed for key: " .. tostring(elements) .. " (" .. tostring(result) .. ")")
            return text
        end
    end

    if type(current) == "string" then
        return applyFormats(current)

    elseif type(current) == "table" then
        -- Apply format substitutions to every string element (e.g. GameoverText array)
        if formats ~= nil then
            local result = {}
            for i = 1, #current do
                if type(current[i]) == "string" then
                    result[i] = applyFormats(current[i])
                else
                    result[i] = current[i]
                end
            end
            return result
        end

        -- Return the array as-is (e.g. a list of actions)
        return current

    else
        print("[L10N WARNING] Invalid localization value for key: " .. tostring(elements))
        return nil
    end
end

return localize
