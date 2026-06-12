--- AST node for a binary infix operation (e.g. `a + b`, `x * y`).

---@class BinaryExpr: Expr
---@field type  "BinaryExpr"
---@field op    string   Token type of the operator (e.g. `"PLUS"`, `"MULTIPLY"`)
---@field left  Expr
---@field right Expr
local BinaryExpr = {}

---@param op    string
---@param left  Expr
---@param right Expr
---@return BinaryExpr
function BinaryExpr.new(op, left, right)
    return { type = "BinaryExpr", op = op, left = left, right = right } --[[@as BinaryExpr]]
end

return BinaryExpr
