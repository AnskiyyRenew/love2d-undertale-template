--[[
    se_12_compat.lua
    LOVE 11.x -> 12.x compatibility patch
    Source: https://github.com/love2d/love/blob/main/changes.txt (12.0 section)

    Usage:
        require("12_0").apply()
    Run it at the very top of main.lua, before any love.xxx call.

    NOTE: 12.0 is still at the nightly stage. Use this file as the baseline,
    but run the game once and fix it against the actual error messages -
    details may still shift between nightly builds.
]]

local compat = {}

-- ============================================================
-- Category 1: renamed/replaced module-level functions of the form
-- love.<module>.<func>
-- Called by their old names in 11.x; in 12.0 the old names have been
-- removed entirely (Removed)
-- These are plain 1:1 forwards and can be patched automatically and safely
-- ============================================================
compat.moduleFunctionAliases = {
    -- old_full_name = new_full_name
    ["love.audio.getSourceCount"]      = "love.audio.getActiveSourceCount",
    ["love.filesystem.isDirectory"]    = nil, -- Special: uses getInfo, see specialCases below
    ["love.filesystem.isFile"]         = nil,
    ["love.filesystem.isSymlink"]      = nil,
    ["love.filesystem.getLastModified"]= nil,
    ["love.filesystem.getSize"]        = nil,
    ["love.math.compress"]             = "love.data.compress",
    ["love.math.decompress"]           = "love.data.decompress",
}

-- ============================================================
-- Category 2: module-level functions that still work but are deprecated
-- (in 12.0 the old names still run, but the official recommendation is to
-- use the new names; if your code uses the old API, these shims forward it)
-- ============================================================
compat.deprecatedModuleFunctions = {
    ["love.filesystem.newFile"] = function(...)
        -- newFile is superseded by openFile, but the arguments and return
        -- values differ - confirm the exact usage before enabling this one
        return love.filesystem.openFile(...)
    end,
    ["love.math.noise"] = function(...)
        -- the old noise() is equivalent to perlinNoise()
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

-- ============================================================
-- Category 3: the love.filesystem isXxx family, all rewritten to test with
-- getInfo. These are not simple forwards, they need a wrapper around them.
-- ============================================================
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

-- ============================================================
-- Category 4: object method (Type:method) renames. These cannot be attached
-- to the love table directly, they must be hooked into the metatable of the
-- concrete type. A LOVE object's metatable can be fetched with
-- debug.getmetatable(obj); every instance of the same type shares one
-- metatable, so patching it once is enough.
-- A generic helper is provided below - call it once after creating an object
-- (or hook the constructors to handle it automatically, see
-- compat.hookConstructors)
-- ============================================================
compat.methodAliases = {
    -- These are old method names removed entirely in 12.0 (Removed)
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

-- Patch a single object instance (at the metatable level, so calling it once
-- per type is enough)
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

-- Automatically hook the common constructors so an object is patched right
-- after it is created
function compat.hookConstructors()
    local hooks = {
        { love.audio,    "newSource" },
        { love.physics,  "newWorld" },
        { love.physics,  "newBody" },
        { love.graphics, "newParticleSystem" },
        -- Joints are created through World:newXxxJoint and World is already
        -- hooked above, but if you call love.physics.newXxxJoint directly you
        -- need to add it here as well
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

-- ============================================================
-- Main entry point
-- ============================================================
function compat.apply()
    -- Category 1: simple 1:1 forwards
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

    -- Category 3: special logic (the getInfo family)
    for oldFull, impl in pairs(compat.specialCases) do
        local modName, fnName = oldFull:match("^love%.([%w_]+)%.([%w_]+)$")
        if modName and love[modName] and love[modName][fnName] == nil then
            love[modName][fnName] = impl
        end
    end

    -- Category 2: deprecated but still forwardable
    for oldFull, impl in pairs(compat.deprecatedModuleFunctions) do
        local modName, fnName = oldFull:match("^love%.([%w_]+)%.([%w_]+)$")
        if modName and love[modName] and love[modName][fnName] == nil then
            love[modName][fnName] = impl
        end
    end

    -- Category 4: object methods, hook the constructors
    compat.hookConstructors()
end

return compat
