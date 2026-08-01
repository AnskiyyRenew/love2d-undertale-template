local template = ImportFile("Engine._FuncList")

local function generate_adapter()
    local code = "local se = {\n"

    for module_name, funcs in pairs(template)
    do
        if (type(funcs) == "table") then
            code = code .. "    " .. module_name .. " = {\n"
            for func_name, _ in pairs(funcs)
            do
                code = code .. "        " .. func_name .. " = function(...)\n"
                code = code .. "            -- TODO: Implement adaptation logic\n"
                code = code .. "            return love." .. module_name .. "." .. func_name .. "(...)\n"
                code = code .. "        end,\n"
            end
            code = code .. "    },\n"
        end
    end

    code = code .. "}\n"
    return code
end

local f = io.open("adapter_skeleton.lua", "w")
--f:write(generate_adapter())
--f:close()