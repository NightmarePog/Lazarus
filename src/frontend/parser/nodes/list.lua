--- AST node for a list literal: `[e0, e1, …]` (an ordered, 0-based sequence).

---@class ListExpr: Expr
---@field type     "ListExpr"
---@field elements Expr[]        Element expressions, in order
---@field line     integer | nil 1-based source line of the `[`
---@field col      integer | nil 1-based source column of the `[`
local ListExpr = {}
ListExpr.__index = ListExpr

---@param elements Expr[]
---@param line?    integer
---@param col?     integer
---@return ListExpr
function ListExpr.new(elements, line, col)
    return setmetatable({ type = "ListExpr", elements = elements, line = line, col = col }, ListExpr)
end

---@return string
function ListExpr:__tostring()
    return ("ListExpr(%d elems)"):format(#self.elements)
end

return ListExpr
