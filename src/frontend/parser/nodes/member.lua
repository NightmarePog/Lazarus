--- AST node for field access (`object.field`), e.g. `self.x`, `p.name`.

---@class MemberExpr: Expr
---@field type   "MemberExpr"
---@field object Expr          Expression that evaluates to the table/instance
---@field field  string        The field name accessed after `.`
---@field line   integer | nil 1-based source line of the `.`
---@field col    integer | nil 1-based source column of the `.`
local MemberExpr = {}
MemberExpr.__index = MemberExpr

---@param object Expr
---@param field  string
---@param line?  integer
---@param col?   integer
---@return MemberExpr
function MemberExpr.new(object, field, line, col)
    return setmetatable(
        { type = "MemberExpr", object = object, field = field, line = line, col = col },
        MemberExpr
    )
end

---@return string
function MemberExpr:__tostring()
    return ("MemberExpr(%s.%s)"):format(tostring(self.object), self.field)
end

return MemberExpr
