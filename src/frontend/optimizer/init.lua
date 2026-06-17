--- Optimizer pass: applies expression folding and constant propagation to the AST.

local fold_expr = require("frontend.optimizer.expr")

---@type fun(node: Stmt, constants: table<string, LiteralExpr>): Stmt
local fold_stmt

--- Fold every statement in a block, threading the constant table so later
--- statements can substitute constants declared earlier in the same block.
---@param stmts     Stmt[]
---@param constants table<string, LiteralExpr>
local function fold_block(stmts, constants)
    for i, stmt in ipairs(stmts) do
        stmts[i] = fold_stmt(stmt, constants)

        -- After folding, record *immutable* bindings whose value collapsed to a
        -- literal so subsequent statements can substitute them inline. Mutable
        -- bindings and reassignments are skipped — their value can change.
        if stmt.type == "VariableDecl" and not stmt.mutable and not stmt.reassign then
            ---@cast stmt VariableDecl
            local val = stmt.value
            if val and val.type == "LiteralExpr" then
                ---@cast val LiteralExpr
                constants[stmt.name] = val
            end
        end
    end
end

---@param node      Stmt
---@param constants table<string, LiteralExpr>
---@return Stmt
function fold_stmt(node, constants)
    if node.type == "VariableDecl" or node.type == "ReturnStmt" then
        ---@cast node VariableDecl | ReturnStmt
        -- Both carry an optional `value` expression (an absent initialiser or a
        -- bare `return`), so they fold identically.
        if node.value then node.value = fold_expr(node.value, constants) end
    elseif node.type == "ExpressionStmt" then
        ---@cast node ExpressionStmt
        node.expression = fold_expr(node.expression, constants)
    elseif node.type == "FunctionDecl" then
        ---@cast node FunctionDecl
        -- Constants visible from the enclosing scope still propagate into the
        -- body, but a parameter of the same name shadows them, so drop those
        -- entries from the body's copy of the table.
        local inner = {}
        for name, lit in pairs(constants) do inner[name] = lit end
        for _, param in ipairs(node.params) do inner[param] = nil end
        fold_block(node.body, inner)
    end
    return node
end

---@param ast AST
---@return AST
local function optimize(ast)
    ---@type table<string, LiteralExpr>
    local constants = {}
    fold_block(ast.body, constants)
    return ast
end

return { optimize = optimize }
