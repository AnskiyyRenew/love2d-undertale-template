---This function localizes text based on the provided language and element.
---It supports both string and table elements, allowing for formatted strings with arguments.
---@param language string
---@param element string|table
---@param args table|nil
---@return string|table
function localizetext(language, element, args)
    local lang = require("Localization." .. language)

    local res
    if (type(element) == "string") then
        res = lang[element]
    elseif (type(element) == "table") then
        res = lang
        for _, key in ipairs(element) do
            if (type(key) == "string") then
                res = res[key]
            else
                error("Localization error: Invalid key type: " .. type(key))
            end
        end
    end

    if (type(res) == "table") then
        local formattedTable = {}
        for i, str in ipairs(res) do
            if (type(str) == "string" and args) then
                local success, formatted = pcall(string.format, str, unpack(args))
                if success then
                    formattedTable[i] = formatted
                else
                    formattedTable[i] = str
                    print("Localization format error:", formatted)
                end
            else
                formattedTable[i] = str
            end
        end
        res = formattedTable

        for i, str in ipairs(res) do
            print(str)
        end
    elseif (args) then
        if (type(res) == "string" and type(args) == "table") then
            local success, formatted = pcall(string.format, res, unpack(args))
            if success then
                res = formatted
            else
                print("Localization format error:", formatted)
            end
        end
    end

    return res
end

--[[

examples:
-- Example 1: Simple string localization
-- Assuming en.lua contains: { greeting = "Hello, %s!" }
print(localizetext("en", "greeting", {"World"})) -- Output: Hello, World!

-- Example 2: Nested table localization
-- Assuming zh.lua contains: { menu = { start = "开始游戏", quit = "退出" } }
print(localizetext("zh", {"menu", "start"})) -- Output: 开始游戏

-- Example 3: Table of strings with formatting
-- Assuming en.lua contains: { tips = { "Tip 1: %s", "Tip 2: %s" } }
for _, tip in ipairs(localizetext("en", "tips", {"Be careful!"})) do
    print(tip)
end
-- Output:
-- Tip 1: Be careful!
-- Tip 2: Be careful!

-- Example 4: No formatting arguments
-- Assuming en.lua contains: { about = "This is a game." }
print(localizetext("en", "about")) -- Output: This is a game.

]]