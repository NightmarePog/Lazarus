--- Optimizer pass: applies constant folding and constant propagation to the AST.
---
--- The rules themselves live next to this file, one module per node type:
---   • `statements/` — a `FoldStatement` per statement (variable, function, …)
---   • `expressions/` — a `FoldExpression` per expression (identifier, binary, …)
---
--- This module is just the driver. It builds a shared `FoldContext` carrying the
--- constants table and walks each block, dispatching every statement to its
--- registered rule. The cross-cutting helpers a rule might need — expression
--- folding, constant recording, child-scope creation, recursion into nested
--- blocks — live on the context so the individual rules stay small and focused.

local statement_registry = require("frontend.optimizer.statements")
local fold_expr          = require("frontend.optimizer.expressions")

---@class FoldContext
---@field constants table<string, LiteralExpr>
local FoldContext = {}
FoldContext.__index = FoldContext

---@param constants table<string, LiteralExpr>
---@return FoldContext
function FoldContext.new(constants)
    return setmetatable({ constants = constants }, FoldContext)
end

--- Fold an expression against the constants visible in this context, returning
--- the possibly-replaced node.
---@param node Expr
---@return Expr
function FoldContext:fold_expr(node)
    return fold_expr(node, self.constants)
end

--- Record an immutable binding whose value folded to a literal, so later
--- statements in the block can substitute it inline.
---@param name    string
---@param literal LiteralExpr
function FoldContext:record_constant(name, literal)
    self.constants[name] = literal
end

--- Create a child context for a function body: it inherits the enclosing
--- constants, but a parameter shadowing a constant drops that entry so the
--- parameter's runtime value is never substituted away.
---@param params string[]
---@return FoldContext
function FoldContext:child(params)
    local inner = {}
    for name, lit in pairs(self.constants) do inner[name] = lit end
    for _, param in ipairs(params) do inner[param] = nil end
    return FoldContext.new(inner)
end

--- Walk a block in source order, dispatching each statement to its fold rule.
--- Statement types with no registered rule are left untouched.
---@param stmts Stmt[]
function FoldContext:fold_block(stmts)
    for idx, stmt in ipairs(stmts) do
        local rule = statement_registry[stmt.type]
        if rule then
            rule.fold(self, { stmt = stmt, idx = idx, stmts = stmts })
        end
    end
end

---@param ast AST
---@return AST
local function optimize(ast)
    FoldContext.new({}):fold_block(ast.body)
    return ast
end

return { optimize = optimize }
