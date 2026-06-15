--- Statement emitter: converts a `Stmt` AST node to a Lua source string.

---@type fun(node: Expr): string
local emit_expr = require("backend.lua50.expr")

---@param node Stmt
---@return string
local function emit_stmt(node)
    if node.type == "VariableDecl" then
        ---@cast node VariableDecl
        if node.value then
            return "local " .. node.name .. " = " .. emit_expr(node.value)
        end
        return "local " .. node.name
    end

    if node.type == "ConstantDecl" then
        ---@cast node ConstantDecl
        return "local " .. node.name .. " = " .. emit_expr(node.value)
    end

    if node.type == "ExpressionStmt" then
        ---@cast node ExpressionStmt
        return emit_expr(node.expression)
    end

    error("emit_stmt: unknown node type: " .. tostring(node.type))
end

return emit_stmt
