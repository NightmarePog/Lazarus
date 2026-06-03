---@class LiteralExpr: Expr
---@field type  "LiteralExpr"
---@field value any

local LiteralExpr = {}

function LiteralExpr.new(value)
    return { type = "LiteralExpr", value = value }
end

return LiteralExpr
