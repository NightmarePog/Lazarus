--- AST node for a binary infix operation (e.g. `a + b`, `x * y`).

---@class BinaryExpr: Expr
---@field type  "BinaryExpr"
---@field op    string   Token type of the operator (e.g. `"PLUS"`, `"MULTIPLY"`)
---@field left  Expr
---@field right Expr
---@field line  integer | nil 1-based source line of the operator
---@field col   integer | nil 1-based source column of the operator
local BinaryExpr = {}
BinaryExpr.__index = BinaryExpr

---@param op    string
---@param left  Expr
---@param right Expr
---@param line? integer
---@param col?  integer
---@return BinaryExpr
function BinaryExpr.new(op, left, right, line, col)
    return setmetatable({ type = "BinaryExpr", op = op, left = left, right = right, line = line, col = col }, BinaryExpr)
end

---@return string
function BinaryExpr:__tostring()
    return ("BinaryExpr(%s, %s, %s)"):format(self.op, tostring(self.left), tostring(self.right))
end

return BinaryExpr
