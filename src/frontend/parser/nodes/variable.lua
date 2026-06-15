--- AST node for a `private` variable declaration (`private name = expr`).

---@class VariableDecl: Stmt
---@field type  "VariableDecl"
---@field name  string        Identifier name
---@field value Expr | nil    Initialiser expression, or `nil` when omitted
---@field line  integer | nil 1-based source line of the name
---@field col   integer | nil 1-based source column of the name
local VariableDecl = {}
VariableDecl.__index = VariableDecl

---@param name  string
---@param value Expr | nil
---@param line? integer
---@param col?  integer
---@return VariableDecl
function VariableDecl.new(name, value, line, col)
    return setmetatable({ type = "VariableDecl", name = name, value = value, line = line, col = col }, VariableDecl)
end

---@return string
function VariableDecl:__tostring()
    if self.value then
        return ("VariableDecl(%s = %s)"):format(self.name, tostring(self.value))
    end
    return ("VariableDecl(%s)"):format(self.name)
end

return VariableDecl
