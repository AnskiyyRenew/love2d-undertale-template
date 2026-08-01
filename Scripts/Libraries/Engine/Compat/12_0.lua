--[[
    se_12_compat.lua
    LOVE 11.x -> 12.x 兼容补丁
    数据来源: https://github.com/love2d/love/blob/main/changes.txt (12.0 段落)

    用法:
        require("12_0").apply()
    在 main.lua 的最顶部、任何 love.xxx 调用之前执行。

    注意: 12.0 还在 nightly 阶段，以此文件为准但建议你跑一遍游戏后对照
    实际报错信息修正，因为 nightly build 之间可能还有细节变动。
]]

local compat = {}

-- ============================================================
-- 第一类: love.<module>.<func> 这种模块级函数改名/替换
-- 在 11.x 里调用旧名字, 12.0 里旧名字已被彻底删除 (Removed)
-- 这些是 1:1 直接转发，可以安全自动 patch
-- ============================================================
compat.moduleFunctionAliases = {
    -- old_full_name = new_full_name
    ["love.audio.getSourceCount"]      = "love.audio.getActiveSourceCount",
    ["love.filesystem.isDirectory"]    = nil, -- 特殊: 改用 getInfo, 见下方 specialCases
    ["love.filesystem.isFile"]         = nil,
    ["love.filesystem.isSymlink"]      = nil,
    ["love.filesystem.getLastModified"]= nil,
    ["love.filesystem.getSize"]        = nil,
    ["love.math.compress"]             = "love.data.compress",
    ["love.math.decompress"]           = "love.data.decompress",
}

-- ============================================================
-- 第二类: 还在用但已 Deprecated 的模块级函数 (12.0 里旧名字还能跑,
-- 但官方建议换新名字; 如果你的代码用的是老API, 这里做兼容转发)
-- ============================================================
compat.deprecatedModuleFunctions = {
    ["love.filesystem.newFile"] = function(...)
        -- newFile 被 openFile 取代，但参数/返回值有差异，需要你确认具体用法后再放开
        return love.filesystem.openFile(...)
    end,
    ["love.math.noise"] = function(...)
        -- 旧 noise() 等价于 perlinNoise()
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
-- 第三类: love.filesystem 的 isXxx 系列，全部改用 getInfo 判断
-- 这几个不是简单转发，需要包一层逻辑
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
-- 第四类: 对象方法 (Type:method) 改名。这些无法直接挂在 love 表上，
-- 必须 hook 到具体类型的 metatable 上。LOVE 对象的 metatable 可以
-- 通过 debug.getmetatable(obj) 拿到，同一类型的所有实例共享同一个
-- metatable，所以只需要 patch 一次。
-- 下面提供一个通用 helper，你在创建对象后调用一次即可（或者 hook
-- 构造函数自动处理，见 compat.hookConstructors）
-- ============================================================
compat.methodAliases = {
    -- 这些是 12.0 中彻底删除的旧方法名 (Removed)
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

-- 给单个对象实例打补丁（在 metatable 层面，所以只需对每种类型调用一次）
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

-- 自动 hook 常见构造函数，创建对象后立刻打补丁
function compat.hookConstructors()
    local hooks = {
        { love.audio,    "newSource" },
        { love.physics,  "newWorld" },
        { love.physics,  "newBody" },
        { love.graphics, "newParticleSystem" },
        -- Joint 是通过 World:newXxxJoint 创建的，World 也已被上面 hook，
        -- 但如果你直接用 love.physics.newXxxJoint 也要在这里加
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
-- 总入口
-- ============================================================
function compat.apply()
    -- 第一类: 简单 1:1 转发
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

    -- 第三类: 特殊逻辑 (getInfo 系列)
    for oldFull, impl in pairs(compat.specialCases) do
        local modName, fnName = oldFull:match("^love%.([%w_]+)%.([%w_]+)$")
        if modName and love[modName] and love[modName][fnName] == nil then
            love[modName][fnName] = impl
        end
    end

    -- 第二类: deprecated 但还能转发的
    for oldFull, impl in pairs(compat.deprecatedModuleFunctions) do
        local modName, fnName = oldFull:match("^love%.([%w_]+)%.([%w_]+)$")
        if modName and love[modName] and love[modName][fnName] == nil then
            love[modName][fnName] = impl
        end
    end

    -- 第四类: 对象方法，hook 构造函数
    compat.hookConstructors()
end

return compat
