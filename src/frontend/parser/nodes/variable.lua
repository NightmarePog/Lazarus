--- AST node for a `let` variable declaration (`let name = expr`).

---@class VariableDecl: Stmt
---@field type  "VariableDecl"
---@field name  string     Identifier name
---@field value Expr | nil Initialiser expression, or `nil` when omitted
local VariableDecl = {}

---@param name  string
---@param value Expr | nil
---@return VariableDecl
function VariableDecl.new(name, value)
    return { type = "VariableDecl", name = name, value = value } --[[@as VariableDecl]]
end

return VariableDecl
