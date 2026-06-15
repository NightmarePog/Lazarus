--- AST node for a `constant` declaration (`constant name = expr`).
--- Unlike `VariableDecl`, the initialiser is always required.

---@class ConstantDecl: Stmt
---@field type  "ConstantDecl"
---@field name  string        Identifier name
---@field value Expr          Initialiser expression (always present)
---@field line  integer | nil 1-based source line of the name
---@field col   integer | nil 1-based source column of the name
local ConstantDecl = {}
ConstantDecl.__index = ConstantDecl

---@param name  string
---@param value Expr
---@param line? integer
---@param col?  integer
---@return ConstantDecl
function ConstantDecl.new(name, value, line, col)
    return setmetatable({ type = "ConstantDecl", name = name, value = value, line = line, col = col }, ConstantDecl)
end

---@return string
function ConstantDecl:__tostring()
    return ("ConstantDecl(%s = %s)"):format(self.name, tostring(self.value))
end

return ConstantDecl
