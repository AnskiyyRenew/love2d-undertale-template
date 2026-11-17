--[[
    se_12_compat.lua - LOVE 11.x -> 12.x compatibility patch.
    Call `require("12_0").apply()` at the very top of main.lua, before any love.xxx.
    Patching is metatable/table-level and idempotent.
]]

local compat = {}

-- Module-level love.<module>.<func> names removed in 12.0; safe 1:1 forwards.
compat.moduleFunctionAliases = {
    ["love.audio.getSourceCount"]      = "love.audio.getActiveSourceCount",
    ["love.filesystem.isDirectory"]    = nil, -- Special: uses getInfo, see specialCases below
    ["love.filesystem.isFile"]         = nil,
    ["love.filesystem.isSymlink"]      = nil,
    ["love.filesystem.getLastModified"]= nil,
    ["love.filesystem.getSize"]        = nil,
    ["love.math.compress"]             = "love.data.compress",
    ["love.math.decompress"]           = "love.data.decompress",
}

-- Still work in 12.0 but deprecated; these shims forward them.
compat.deprecatedModuleFunctions = {
    ["love.filesystem.newFile"] = function(...)
        -- openFile has different arguments/return values than newFile.
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

-- The love.filesystem isXxx family, rewritten on top of getInfo.
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

-- Object methods (Type:method) removed in 12.0. They must be patched on the
-- type's metatable; every instance of a type shares one, so once per type is
-- enough (see compat.patchObjectMethods / hookConstructors below).
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

-- Patch one instance at the metatable level, so once per type is enough.
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

-- Hook the common constructors so a new object is patched right away.
function compat.hookConstructors()
    local hooks = {
        { love.audio,    "newSource" },
        { love.physics,  "newWorld" },
        { love.physics,  "newBody" },
        { love.graphics, "newParticleSystem" },
        -- Joints come through World:newXxxJoint (World is hooked above); add
        -- love.physics.newXxxJoint here if you call it directly.
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

    -- getInfo family (needs a wrapper, not a 1:1 forward)
    for oldFull, impl in pairs(compat.specialCases) do
        local modName, fnName = oldFull:match("^love%.([%w_]+)%.([%w_]+)$")
        if modName and love[modName] and love[modName][fnName] == nil then
            love[modName][fnName] = impl
        end
    end

    -- deprecated shims
    for oldFull, impl in pairs(compat.deprecatedModuleFunctions) do
        local modName, fnName = oldFull:match("^love%.([%w_]+)%.([%w_]+)$")
        if modName and love[modName] and love[modName][fnName] == nil then
            love[modName][fnName] = impl
        end
    end

    -- object methods via constructor hooks
    compat.hookConstructors()
end

return compat
