--- AST node that wraps a bare expression used as a statement.

---@class ExpressionStmt: Stmt
---@field type       "ExpressionStmt"
---@field expression Expr
---@field line       integer | nil 1-based source line of the expression's first token
---@field col        integer | nil 1-based source column of the expression's first token
local ExpressionStmt = {}
ExpressionStmt.__index = ExpressionStmt

---@param expression Expr
---@param line?      integer
---@param col?       integer
---@return ExpressionStmt
function ExpressionStmt.new(expression, line, col)
    return setmetatable({ type = "ExpressionStmt", expression = expression, line = line, col = col }, ExpressionStmt)
end

---@return string
function ExpressionStmt:__tostring()
    return ("ExpressionStmt(%s)"):format(tostring(self.expression))
end

return ExpressionStmt
