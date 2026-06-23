--- AST node for the implicit receiver of an instance member access.
---
--- There is no `self` keyword in the language; instance fields are written with
--- a leading dot (`.x`), which the parser lowers to a `MemberExpr` whose object
--- is this `SelfExpr`. It carries no data — codegen emits the receiver name
--- (`self`) for it, and Schematic uses it to recognise `.field` access.

---@class SelfExpr: Expr
---@field type "SelfExpr"
---@field line integer | nil 1-based source line of the `.`
---@field col  integer | nil 1-based source column of the `.`
local SelfExpr = {}
SelfExpr.__index = SelfExpr

---@param line? integer
---@param col?  integer
---@return SelfExpr
function SelfExpr.new(line, col)
    return setmetatable({ type = "SelfExpr", line = line, col = col }, SelfExpr)
end

---@return string
function SelfExpr.__tostring() return "SelfExpr(.)" end

return SelfExpr
