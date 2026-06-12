--- AST node for a literal value (number or string constant).

---@class LiteralExpr: Expr
---@field type  "LiteralExpr"
---@field kind  "number" | "string"  Distinguishes numeric and string literals for the evaluator
---@field value any                  The converted value (`tonumber` result for numbers)
local LiteralExpr = {}
LiteralExpr.__index = LiteralExpr

---@param kind  "number" | "string"
---@param value any
---@return LiteralExpr
function LiteralExpr.new(kind, value)
    return setmetatable({ type = "LiteralExpr", kind = kind, value = value }, LiteralExpr)
end

---@return string
function LiteralExpr:__tostring()
    return ("LiteralExpr(%s, %s)"):format(self.kind, tostring(self.value))
end

return LiteralExpr
