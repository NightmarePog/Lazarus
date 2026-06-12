--- AST node that wraps a bare expression used as a statement.

---@class ExpressionStmt: Stmt
---@field type       "ExpressionStmt"
---@field expression Expr
local ExpressionStmt = {}
ExpressionStmt.__index = ExpressionStmt

---@param expression Expr
---@return ExpressionStmt
function ExpressionStmt.new(expression)
    return setmetatable({ type = "ExpressionStmt", expression = expression }, ExpressionStmt)
end

---@return string
function ExpressionStmt:__tostring()
    return ("ExpressionStmt(%s)"):format(tostring(self.expression))
end

return ExpressionStmt
