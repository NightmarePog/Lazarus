-- src/frontend/codegen/codegen.lua
local codegen = {}

-- utility: indent string
local function indentStr(level)
    return string.rep("    ", level or 0)
end

-- hlavní funkce generující Lua kód z AST
function codegen.generate(node, level)
    level = level or 0
    local lua = ""

    if node.type == "BLOCK" then
        for _, stmt in ipairs(node.body) do
            lua = lua .. codegen.generate(stmt, level) .. "\n"
        end
    elseif node.type == "EXTENDS" then
        lua = indentStr(level) .. "-- EXTENDS " .. node.value
    elseif node.type == "FUNC_DECL" then
        local params = table.concat(node.params or {}, ", ")
        lua = indentStr(level) .. string.format("function %s(%s)\n", node.name, params)
        for _, stmt in ipairs(node.body or {}) do
            lua = lua .. codegen.generate(stmt, level + 1) .. "\n"
        end
        lua = lua .. indentStr(level) .. "end"
    elseif node.type == "CALL" then
        local args = {}
        for _, a in ipairs(node.args or {}) do
            table.insert(args, codegen.generate(a, 0))
        end
        lua = indentStr(level) .. string.format("%s(%s)", node.name, table.concat(args, ", "))
    elseif node.type == "LUA_BLOCK" then
        local lines = {}
        for line in node.value:gmatch("[^\n]+") do
            table.insert(lines, indentStr(level) .. line)
        end
        lua = table.concat(lines, "\n")
    elseif node.type == "VARIABLE" then
        -- zjednodušeně jako local
        lua = indentStr(level) .. "local " .. (node.name or "var")
        if node.body and #node.body > 0 then
            for _, stmt in ipairs(node.body) do
                lua = lua .. "\n" .. codegen.generate(stmt, level + 1)
            end
        end
    elseif node.type == "STRING" then
        lua = string.format("%q", node.value)
    elseif node.type == "NUMBER" then
        lua = tostring(node.value)
    else
        -- fallback: print hodnotu
        lua = tostring(node.value or node.type)
    end

    return lua
end

return codegen
