--- AST node for a bare identifier reference (e.g. `foo`, `my_var`).

---@class IdentifierExpr: Expr
---@field type "IdentifierExpr"
---@field name string        Raw identifier text from the source
---@field line integer | nil 1-based source line of the identifier
---@field col  integer | nil 1-based source column of the identifier
local IdentifierExpr = {}
IdentifierExpr.__index = IdentifierExpr

---@param name  string
---@param line? integer
---@param col?  integer
---@return IdentifierExpr
function IdentifierExpr.new(name, line, col)
    return setmetatable({ type = "IdentifierExpr", name = name, line = line, col = col }, IdentifierExpr)
end

---@return string
function IdentifierExpr:__tostring()
    return ("IdentifierExpr(%s)"):format(self.name)
end

return IdentifierExpr
