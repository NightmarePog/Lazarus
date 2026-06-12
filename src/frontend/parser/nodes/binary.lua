--- AST node for a binary infix operation (e.g. `a + b`, `x * y`).

---@class BinaryExpr: Expr
---@field type  "BinaryExpr"
---@field op    string   Token type of the operator (e.g. `"PLUS"`, `"MULTIPLY"`)
---@field left  Expr
---@field right Expr
local BinaryExpr = {}
BinaryExpr.__index = BinaryExpr

---@param op    string
---@param left  Expr
---@param right Expr
---@return BinaryExpr
function BinaryExpr.new(op, left, right)
    return setmetatable({ type = "BinaryExpr", op = op, left = left, right = right }, BinaryExpr)
end

---@return string
function BinaryExpr:__tostring()
    return ("BinaryExpr(%s, %s, %s)"):format(self.op, tostring(self.left), tostring(self.right))
end

return BinaryExpr
