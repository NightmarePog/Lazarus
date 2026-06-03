---@class BinaryExpr: Expr
---@field type  "BinaryExpr"
---@field op    string
---@field left  Expr
---@field right Expr

local BinaryExpr = {}

function BinaryExpr.new(op, left, right)
    return { type = "BinaryExpr", op = op, left = left, right = right }
end

return BinaryExpr
