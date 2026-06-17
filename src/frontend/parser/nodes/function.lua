--- AST node for a function declaration (`fn name(params) { body }`).

---@class FunctionDecl: Stmt
---@field type   "FunctionDecl"
---@field name   string        Function name
---@field params string[]      Parameter names, in declaration order
---@field body   Stmt[]        Statements forming the function body
---@field line   integer | nil 1-based source line of the name
---@field col    integer | nil 1-based source column of the name
local FunctionDecl = {}
FunctionDecl.__index = FunctionDecl

---@param name   string
---@param params string[]
---@param body   Stmt[]
---@param line?  integer
---@param col?   integer
---@return FunctionDecl
function FunctionDecl.new(name, params, body, line, col)
    return setmetatable(
        { type = "FunctionDecl", name = name, params = params, body = body, line = line, col = col },
        FunctionDecl
    )
end

---@return string
function FunctionDecl:__tostring()
    return ("FunctionDecl(%s(%s), %d stmts)"):format(
        self.name, table.concat(self.params, ", "), #self.body
    )
end

return FunctionDecl
