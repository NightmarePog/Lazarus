--- AST node for assigning to a field (`object.field = value`), e.g.
--- `self.x = 3`. Distinct from `VariableDecl` (which targets a bare name).

---@class FieldAssign: Stmt
---@field type   "FieldAssign"
---@field target MemberExpr    The field being assigned (`object.field`)
---@field value  Expr          The value expression
---@field line   integer | nil 1-based source line
---@field col    integer | nil 1-based source column
local FieldAssign = {}
FieldAssign.__index = FieldAssign

---@param target MemberExpr
---@param value  Expr
---@param line?  integer
---@param col?   integer
---@return FieldAssign
function FieldAssign.new(target, value, line, col)
    return setmetatable(
        { type = "FieldAssign", target = target, value = value, line = line, col = col },
        FieldAssign
    )
end

---@return string
function FieldAssign:__tostring()
    return ("FieldAssign(%s = %s)"):format(tostring(self.target), tostring(self.value))
end

return FieldAssign
