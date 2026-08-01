local localize = {}
local dkjson = ImportFile("Utils.dkjson")
localize.currentLanguage = nil

function localize.setFile(language)
    if (type(language) ~= "string") then
        print("[L10N WARNING] Invalid language file.")
        return
    end

    localize.currentLanguage = language

    local ok, err = pcall(function ()
        local content = love.filesystem.read("Localization/" .. language .. ".json")
        if not content then
            error("Could not read Localization/" .. language .. ".json")
        end
        local decoded, pos, parseErr = dkjson.decode(content)
        if not decoded then
            error("JSON parse error at position " .. tostring(pos) .. ": " .. tostring(parseErr))
        end
        localize.file = decoded
    end)

    if (ok) then
        print("[L10N] L10n has started successfully, using language: " .. language)
    else
        print("[L10N WARNING] Invalid language file.\n               Using default language. (en)\n[L10N Error]   " .. err)
        local content = love.filesystem.read("Localization/en.json")
        if content then
            local decoded = dkjson.decode(content)
            localize.file = decoded
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
        local content = love.filesystem.read("Localization/en.json")
        if content then
            file = dkjson.decode(content)
            localize.file = file
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
