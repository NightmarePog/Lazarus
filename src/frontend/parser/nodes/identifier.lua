--- AST node for a bare identifier reference (e.g. `foo`, `my_var`).

---@class IdentifierExpr: Expr
---@field type "IdentifierExpr"
---@field name string   Raw identifier text from the source
local IdentifierExpr = {}

---@param name string
---@return IdentifierExpr
function IdentifierExpr.new(name)
    return { type = "IdentifierExpr", name = name } --[[@as IdentifierExpr]]
end

return IdentifierExpr
