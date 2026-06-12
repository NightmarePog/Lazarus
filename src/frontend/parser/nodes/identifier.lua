--- AST node for a bare identifier reference (e.g. `foo`, `my_var`).

---@class IdentifierExpr: Expr
---@field type "IdentifierExpr"
---@field name string   Raw identifier text from the source
local IdentifierExpr = {}
IdentifierExpr.__index = IdentifierExpr

---@param name string
---@return IdentifierExpr
function IdentifierExpr.new(name)
    return setmetatable({ type = "IdentifierExpr", name = name }, IdentifierExpr)
end

---@return string
function IdentifierExpr:__tostring()
    return ("IdentifierExpr(%s)"):format(self.name)
end

return IdentifierExpr
