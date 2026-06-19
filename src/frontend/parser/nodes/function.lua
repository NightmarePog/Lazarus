--- AST node for a function declaration (`fn name(params) { body }`).

---@class FunctionDecl: Stmt
---@field type        "FunctionDecl"
---@field name        string                 Function name
---@field params      string[]               Parameter names, in declaration order
---@field param_types (TypeRef | nil)[]      Per-parameter type annotation (parallel to `params`; entries may be nil)
---@field return_type TypeRef | nil          Declared return type (`fn f(): T`), or nil
---@field body        Stmt[]                 Statements forming the function body
---@field line        integer | nil          1-based source line of the name
---@field col         integer | nil          1-based source column of the name
local FunctionDecl = {}
FunctionDecl.__index = FunctionDecl

---@param name         string
---@param params       string[]
---@param body         Stmt[]
---@param line?        integer
---@param col?         integer
---@param param_types? (TypeRef | nil)[]
---@param return_type? TypeRef
---@return FunctionDecl
function FunctionDecl.new(name, params, body, line, col, param_types, return_type)
    return setmetatable({
        type        = "FunctionDecl",
        name        = name,
        params      = params,
        param_types = param_types or {},
        return_type = return_type,
        body        = body,
        line        = line,
        col         = col,
    }, FunctionDecl)
end

---@return string
function FunctionDecl:__tostring()
    return ("FunctionDecl(%s(%s), %d stmts)"):format(
        self.name, table.concat(self.params, ", "), #self.body
    )
end

return FunctionDecl
