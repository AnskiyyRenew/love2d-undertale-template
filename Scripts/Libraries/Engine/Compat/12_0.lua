--- se_12_compat.lua - LOVE 11.x -> 12.x compatibility patch.

local compat = {}

compat.moduleFunctionAliases = {
    ["love.audio.getSourceCount"]      = "love.audio.getActiveSourceCount",
    ["love.filesystem.isDirectory"]    = nil,
    ["love.filesystem.isFile"]         = nil,
    ["love.filesystem.isSymlink"]      = nil,
    ["love.filesystem.getLastModified"]= nil,
    ["love.filesystem.getSize"]        = nil,
    ["love.math.compress"]             = "love.data.compress",
    ["love.math.decompress"]           = "love.data.decompress",
}

compat.deprecatedModuleFunctions = {
    ["love.filesystem.newFile"] = function(...)
        return love.filesystem.openFile(...)
    end,
    ["love.math.noise"] = function(...)
        return love.math.perlinNoise(...)
    end,
    ["love.graphics.setNewFont"] = function(...)
        local font = love.graphics.newFont(...)
        love.graphics.setFont(font)
        return font
    end,
    ["love.graphics.newText"] = function(...)
        return love.graphics.newTextBatch(...)
    end,
}

compat.specialCases = {
    ["love.filesystem.isDirectory"] = function(path)
        local info = love.filesystem.getInfo(path, "directory")
        return info ~= nil
    end,
    ["love.filesystem.isFile"] = function(path)
        local info = love.filesystem.getInfo(path, "file")
        return info ~= nil
    end,
    ["love.filesystem.isSymlink"] = function(path)
        local info = love.filesystem.getInfo(path)
        return info ~= nil and info.type == "symlink"
    end,
    ["love.filesystem.getLastModified"] = function(path)
        local info = love.filesystem.getInfo(path)
        return info and info.modtime
    end,
    ["love.filesystem.getSize"] = function(path)
        local info = love.filesystem.getInfo(path)
        return info and info.size
    end,
}

compat.methodAliases = {
    Source  = { getChannels = "getChannelCount" },
    Decoder = { getChannels = "getChannelCount" },
    ParticleSystem = {
        setAreaSpread = "setEmissionArea",
        getAreaSpread = "getEmissionArea",
    },
    World = {
        getBodyList    = "getBodies",
        getJointList   = "getJoints",
        getContactList = "getContacts",
    },
    Body = {
        getFixtureList = "getFixtures",
        getJointList   = "getJoints",
        getContactList = "getContacts",
    },
    PrismaticJoint = { hasLimitsEnabled = "areLimitsEnabled" },
    RevoluteJoint  = { hasLimitsEnabled = "areLimitsEnabled" },
}

local patchedTypes = {}
function compat.patchObjectMethods(obj)
    if not obj or type(obj) ~= "userdata" or not obj.type then return obj end
    local typeName = obj:type()
    local aliasMap = compat.methodAliases[typeName]
    if not aliasMap or patchedTypes[typeName] then return obj end

    local mt = debug.getmetatable(obj)
    if not mt or not mt.__index then return obj end

    for oldName, newName in pairs(aliasMap) do
        if mt.__index[oldName] == nil and mt.__index[newName] ~= nil then
            mt.__index[oldName] = mt.__index[newName]
        end
    end
    patchedTypes[typeName] = true
    return obj
end

--- Hook the common constructors so a new object is patched right away.
function compat.hookConstructors()
    local hooks = {
        { love.audio,    "newSource" },
        { love.physics,  "newWorld" },
        { love.physics,  "newBody" },
        { love.graphics, "newParticleSystem" },
    }
    for _, h in ipairs(hooks) do
        local mod, fname = h[1], h[2]
        local original = mod[fname]
        if original then
            mod[fname] = function(...)
                local result = { original(...) }
                for _, v in ipairs(result) do
                    compat.patchObjectMethods(v)
                end
                return unpack(result)
            end
        end
    end
end

function compat.apply()
    for oldFull, newFull in pairs(compat.moduleFunctionAliases) do
        if newFull then
            local modName, fnName = oldFull:match("^love%.([%w_]+)%.([%w_]+)$")
            local newModName, newFnName = newFull:match("^love%.([%w_]+)%.([%w_]+)$")
            if modName and love[modName] and love[modName][fnName] == nil
               and love[newModName] and love[newModName][newFnName] then
                love[modName][fnName] = love[newModName][newFnName]
            end
        end
    end

    for oldFull, impl in pairs(compat.specialCases) do
        local modName, fnName = oldFull:match("^love%.([%w_]+)%.([%w_]+)$")
        if modName and love[modName] and love[modName][fnName] == nil then
            love[modName][fnName] = impl
        end
    end

    for oldFull, impl in pairs(compat.deprecatedModuleFunctions) do
        local modName, fnName = oldFull:match("^love%.([%w_]+)%.([%w_]+)$")
        if modName and love[modName] and love[modName][fnName] == nil then
            love[modName][fnName] = impl
        end
    end

    compat.hookConstructors()
end

return compat
