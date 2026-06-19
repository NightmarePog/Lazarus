--- AST node for a class constructor (`constructor(params) { body }`).
---
--- A class has at most one constructor. It lowers to a static `C.new(params)`
--- that builds a fresh `self` table, runs the body, and returns it. Construction
--- at a call site is written `C(args)` and lowers to `C.new(args)`.

---@class ConstructorDecl: Stmt
---@field type        "ConstructorDecl"
---@field params      string[]               Parameter names, in declaration order
---@field param_types (TypeRef | nil)[]      Per-parameter type annotation (parallel to `params`)
---@field body        Stmt[]                 Statements forming the constructor body
---@field line        integer | nil          1-based source line of the `constructor` keyword
---@field col         integer | nil          1-based source column
local ConstructorDecl = {}
ConstructorDecl.__index = ConstructorDecl

---@param params       string[]
---@param body         Stmt[]
---@param line?        integer
---@param col?         integer
---@param param_types? (TypeRef | nil)[]
---@return ConstructorDecl
function ConstructorDecl.new(params, body, line, col, param_types)
    return setmetatable({
        type        = "ConstructorDecl",
        params      = params,
        param_types = param_types or {},
        body        = body,
        line        = line,
        col         = col,
    }, ConstructorDecl)
end

---@return string
function ConstructorDecl:__tostring()
    return ("ConstructorDecl(%s, %d stmts)"):format(table.concat(self.params, ", "), #self.body)
end

return ConstructorDecl
