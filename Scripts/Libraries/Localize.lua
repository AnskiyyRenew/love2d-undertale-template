local localize = {}
local dkjson = ImportFile("Utils.dkjson")
localize.currentLanguage = nil

-- Localization lookup layers, highest priority first. A translation file placed
-- in the Game area (Game/Localization/) is merged ON TOP OF the engine default
-- (Localization/): keys missing from a higher layer fall back to a lower one,
-- so the Game copy only needs the entries it actually changes.
local ROOT_LOCALIZATION = "Localization/"
local GAME_LOCALIZATION = "Game/Localization/"
local LAYER_PATHS = { GAME_LOCALIZATION, ROOT_LOCALIZATION }

local function languageFileName(language)
    return tostring(language) .. ".json"
end

--- Read a file, tolerating a missing one (returns nil) and reporting real IO errors.
local function readFileOrNil(path)
    local ok, content = pcall(love.filesystem.read, path)
    if (not ok) then
        print("[L10N WARNING] Failed reading " .. path .. ": " .. tostring(content))
        return nil
    end
    return content
end

--- True for tables that should be merged key-by-key instead of overwritten
--- (anything holding at least one non-numeric key). Arrays are replaced whole.
local function isMergeableMap(value)
    if (type(value) ~= "table") then return false end
    for k in pairs(value) do
        if (type(k) ~= "number") then return true end
    end
    return false
end

--- Overlay `patch` onto `base` (mutates and returns `base`).
local function mergeInto(base, patch)
    for k, v in pairs(patch) do
        if (isMergeableMap(v) and isMergeableMap(base[k])) then
            mergeInto(base[k], v)
        else
            base[k] = v
        end
    end
    return base
end

--- Load every existing layer of a language and merge them, Game side winning.
---@param language string Language code, e.g. "en" or "zh_CN".
---@return table|nil file The merged translation table (a layer the Game copy overlaid on the engine one).
---@return string|nil primary Path of the highest priority layer that was used.
---@return table|nil sources Every layer path that contributed, highest priority first.
local function loadLanguage(language)
    if (type(language) ~= "string") or (language == "") then
        return nil, nil, nil
    end

    local file_name = languageFileName(language)
    local layers = {}

    -- Collected highest priority first, so index 1 wins the `primary` slot.
    for i = 1, #LAYER_PATHS do
        local path = LAYER_PATHS[i] .. file_name
        local content = readFileOrNil(path)
        if (content) then
            local decoded, pos, parseErr = dkjson.decode(content)
            if (type(decoded) == "table") then
                layers[#layers + 1] = { table = decoded, path = path }
            else
                print("[L10N WARNING] JSON parse error at position " .. tostring(pos) ..
                      " in " .. path .. ": " .. tostring(parseErr) .. " (layer skipped)")
            end
        end
    end

    if (#layers == 0) then
        return nil, nil, nil
    end

    -- Start from the lowest priority layer and let the higher ones overwrite it.
    local merged = layers[#layers].table
    for i = #layers - 1, 1, -1 do
        mergeInto(merged, layers[i].table)
    end

    local sources = {}
    for i = 1, #layers do
        sources[i] = layers[i].path
    end

    return merged, sources[1], sources
end


--- Path of the highest priority existing layer, hinting where a language comes from.
--- Exposed mainly for debugging / tooling.
---@param language string
---@return string
function localize.GetLanguagePath(language)
    local _, primary = loadLanguage(language)
    return primary or (ROOT_LOCALIZATION .. languageFileName(language))
end

--- Every layer that contributes to the currently loaded language, highest priority first.
---@return table paths Possibly empty when nothing is loaded.
function localize.GetSources()
    return localize.sources or {}
end

--- Merge every layer of `language` into `localize.file`.
---@return boolean ok True when at least one usable layer was found.
local function applyLanguage(language)
    local file, primary, sources = loadLanguage(language)
    if (not file) then return false end
    localize.file = file
    localize.currentFile = primary
    localize.sources = sources
    return true
end

function localize.setFile(language)
    if (type(language) ~= "string") then
        print("[L10N WARNING] Invalid language file.")
        return
    end

    localize.currentLanguage = language

    if (applyLanguage(language)) then
        print("[L10N] L10n has started successfully, using language: " .. language ..
              " (" .. table.concat(localize.sources, " > ") .. ")")
    else
        local err = "Could not read " .. languageFileName(language) ..
                    " (no usable layer in " .. GAME_LOCALIZATION .. " or " .. ROOT_LOCALIZATION .. ")"
        print("[L10N WARNING] Invalid language file.\n               Using default language. (en)\n[L10N Error]   " .. err)
        if (applyLanguage("en")) then
            print("[L10N] Fallback language loaded: en (" .. table.concat(localize.sources, " > ") .. ")")
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
        if applyLanguage("en") then
            file = localize.file
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
