--- AST node for a literal value (number or string constant).

---@class LiteralExpr: Expr
---@field type  "LiteralExpr"
---@field kind  "number" | "string"  Distinguishes numeric and string literals for the evaluator
---@field value any                  The converted value (`tonumber` result for numbers)
---@field line  integer | nil        1-based source line
---@field col   integer | nil        1-based source column
local LiteralExpr = {}
LiteralExpr.__index = LiteralExpr

---@param kind  "number" | "string"
---@param value any
---@param line? integer
---@param col?  integer
---@return LiteralExpr
function LiteralExpr.new(kind, value, line, col)
    return setmetatable({ type = "LiteralExpr", kind = kind, value = value, line = line, col = col }, LiteralExpr)
end

---@return string
function LiteralExpr:__tostring()
    return ("LiteralExpr(%s, %s)"):format(self.kind, tostring(self.value))
end

return LiteralExpr
