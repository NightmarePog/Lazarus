--- AST node for a unary prefix operation (e.g. `not done`).

---@class UnaryExpr: Expr
---@field type    "UnaryExpr"
---@field op      string   Token type of the operator (e.g. `"NOT"`)
---@field operand Expr
---@field line    integer | nil 1-based source line of the operator
---@field col     integer | nil 1-based source column of the operator
local UnaryExpr = {}
UnaryExpr.__index = UnaryExpr

---@param op       string
---@param operand  Expr
---@param line?    integer
---@param col?     integer
---@return UnaryExpr
function UnaryExpr.new(op, operand, line, col)
    return setmetatable({ type = "UnaryExpr", op = op, operand = operand, line = line, col = col }, UnaryExpr)
end

---@return string
function UnaryExpr:__tostring()
    return ("UnaryExpr(%s, %s)"):format(self.op, tostring(self.operand))
end

return UnaryExpr
