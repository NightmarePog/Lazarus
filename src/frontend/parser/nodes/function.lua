--- AST node for a method / function declaration.
---
--- A top-level declaration is a class method: `name(params) { body }` is an
--- **instance** method (implicit `self` receiver) and `static name(params) { … }`
--- is a **static** (class) method. A declaration nested inside a body is an
--- ordinary `local function`. `is_static` distinguishes the two top-level kinds;
--- `visibility` (`"private"`/`"public"`/nil) records the access modifier
--- (methods default to private when none is written).

---@class FunctionDecl: Stmt
---@field type        "FunctionDecl"
---@field name        string                 Function name
---@field params      string[]               Parameter names, in declaration order
---@field param_types (TypeRef | nil)[]      Per-parameter type annotation (parallel to `params`; entries may be nil)
---@field return_type TypeRef | nil          Declared return type (`name(): T`), or nil
---@field body        Stmt[]                 Statements forming the function body
---@field is_static   boolean                True for a `static` (class) method; false for an instance method
---@field visibility  string | nil           "private" | "public" | nil (defaults to private)
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
---@param is_static?   boolean
---@param visibility?  string
---@return FunctionDecl
function FunctionDecl.new(name, params, body, line, col, param_types, return_type, is_static, visibility)
    return setmetatable({
        type        = "FunctionDecl",
        name        = name,
        params      = params,
        param_types = param_types or {},
        return_type = return_type,
        is_static   = is_static or false,
        visibility  = visibility,
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
