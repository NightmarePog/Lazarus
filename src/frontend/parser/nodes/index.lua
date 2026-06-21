--- AST node for an index access: `object[index]` (list element by 0-based
--- position, or map value by key). The read form is an expression; the write
--- form (`object[index] = value`) is an `IndexAssign` statement.

---@class IndexExpr: Expr
---@field type   "IndexExpr"
---@field object Expr          Expression evaluating to the list/map
---@field index  Expr          The index/key expression
---@field line   integer | nil 1-based source line of the `[`
---@field col    integer | nil 1-based source column of the `[`
local IndexExpr = {}
IndexExpr.__index = IndexExpr

---@param object Expr
---@param index  Expr
---@param line?  integer
---@param col?   integer
---@return IndexExpr
function IndexExpr.new(object, index, line, col)
    return setmetatable(
        { type = "IndexExpr", object = object, index = index, line = line, col = col },
        IndexExpr
    )
end

---@return string
function IndexExpr:__tostring()
    return ("IndexExpr(%s[%s])"):format(tostring(self.object), tostring(self.index))
end

return IndexExpr
