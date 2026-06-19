--- AST node for a literal value (number or string constant).

---@class LiteralExpr: Expr
---@field type  "LiteralExpr"
---@field kind  "number" | "string" | "boolean"  Distinguishes literal kinds for codegen
---@field value any                  The converted value (number, string, or boolean)
---@field line  integer | nil        1-based source line
---@field col   integer | nil        1-based source column
local LiteralExpr = {}
LiteralExpr.__index = LiteralExpr

---@param kind  "number" | "string" | "boolean"
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
