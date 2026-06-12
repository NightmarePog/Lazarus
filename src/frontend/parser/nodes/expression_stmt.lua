--- AST node that wraps a bare expression used as a statement.

---@class ExpressionStmt: Stmt
---@field type       "ExpressionStmt"
---@field expression Expr
local ExpressionStmt = {}

---@param expression Expr
---@return ExpressionStmt
function ExpressionStmt.new(expression)
    return { type = "ExpressionStmt", expression = expression } --[[@as ExpressionStmt]]
end

return ExpressionStmt
