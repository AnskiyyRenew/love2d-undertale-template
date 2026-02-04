local luaextended = {}

-- Function to remove a value from a table.
---@param t table
---@param value any
---@param func function|nil A function to call before removing the value.
function luaextended.rmVarTable(t, value, func)
    for i = #t, 1, -1 do
        if t[i] == value then
            table.remove(t, i)
        end
    end
    if (func and type(func) == "function") then
        func()
    end
end

---Print a table completely.
---@param t table
---@param indent number|nil
function luaextended.printTable(t, indent)
    indent = indent or 0
    local seen = {}

    local function pad(n)
        return string.rep("    ", n)
    end

    local function recurse(tbl, depth)
        if type(tbl) ~= "table" then
            print(pad(depth) .. tostring(tbl))
            return
        end
        if seen[tbl] then
            print(pad(depth) .. "<recursive reference>")
            return
        end
        seen[tbl] = true

        local count = 0
        for _ in pairs(tbl) do count = count + 1 end

        print(pad(depth) .. string.format("table (rows=%d) {", count))
        for k, v in pairs(tbl) do
            local keyStr = tostring(k)
            if type(v) == "table" then
                print(pad(depth + 1) .. keyStr .. " =")
                recurse(v, depth + 2)
            else
                print(pad(depth + 1) .. keyStr .. " = " .. tostring(v))
            end
        end
        print(pad(depth) .. "}")
    end

    recurse(t, indent)
end

---Find an accurate value from a table.
---@param t table
---@param value any
---@return boolean
function luaextended.findTableValue(t, value)
    local seen = {}
    local function recurse(tbl)
        if tbl == value then return true end
        if type(tbl) ~= "table" or seen[tbl] then return false end
        seen[tbl] = true
        for _, v in pairs(tbl) do
            if v == value then
                return true
            end
            if type(v) == "table" and recurse(v) then
                return true
            end
        end
        return false
    end
    return recurse(t)
end

return luaextended