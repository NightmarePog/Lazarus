--- AST node for a literal value (number or string constant).

---@class LiteralExpr: Expr
---@field type    "LiteralExpr"
---@field kind    "number" | "string" | "boolean"  Distinguishes literal kinds for codegen
---@field value   any                  The converted value (number, string, or boolean)
---@field numeric "int" | "float" | nil Numeric subtype for `number` literals (nil otherwise); used by the type checker, erased before codegen
---@field line    integer | nil        1-based source line
---@field col     integer | nil        1-based source column
local LiteralExpr = {}
LiteralExpr.__index = LiteralExpr

---@param kind     "number" | "string" | "boolean"
---@param value    any
---@param line?    integer
---@param col?     integer
---@param numeric? "int" | "float"
---@return LiteralExpr
function LiteralExpr.new(kind, value, line, col, numeric)
    return setmetatable({
        type = "LiteralExpr", kind = kind, value = value,
        numeric = numeric, line = line, col = col,
    }, LiteralExpr)
end

---@return string
function LiteralExpr:__tostring()
    return ("LiteralExpr(%s, %s)"):format(self.kind, tostring(self.value))
end

return LiteralExpr
