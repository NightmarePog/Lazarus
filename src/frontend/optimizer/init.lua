--- Optimizer pass: applies expression folding and constant propagation to the AST.

local fold_expr = require("frontend.optimizer.expr")

---@param node      Stmt
---@param constants table<string, LiteralExpr>
---@return Stmt
local function fold_stmt(node, constants)
    if node.type == "VariableDecl" then
        ---@cast node VariableDecl
        if node.value then node.value = fold_expr(node.value, constants) end
    elseif node.type == "ConstantDecl" then
        ---@cast node ConstantDecl
        node.value = fold_expr(node.value, constants)
    elseif node.type == "ExpressionStmt" then
        ---@cast node ExpressionStmt
        node.expression = fold_expr(node.expression, constants)
    end
    return node
end

---@param ast AST
---@return AST
local function optimize(ast)
    ---@type table<string, LiteralExpr>
    local constants = {}

    for i, stmt in ipairs(ast.body) do
        ast.body[i] = fold_stmt(stmt, constants)

        -- After folding, record constants whose value collapsed to a literal
        -- so subsequent statements can substitute them inline.
        if stmt.type == "ConstantDecl" then
            ---@cast stmt ConstantDecl
            local val = stmt.value
            if val.type == "LiteralExpr" then
                ---@cast val LiteralExpr
                constants[stmt.name] = val
            end
        end
    end

    return ast
end

return { optimize = optimize }
