---@class IdentifierExpr: Expr
---@field type "IdentifierExpr"
---@field name string

local IdentifierExpr = {}

function IdentifierExpr.new(name)
    return { type = "IdentifierExpr", name = name }
end

return IdentifierExpr
