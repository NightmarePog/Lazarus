--- AST node for an `extern` declaration.
---
--- `extern name(params) = "lua.target"` binds a namespace member to a raw Lua
--- name. Extern declarations live in a namespace file (filename = namespace, e.g.
--- `Sys.laz`), are made visible with `import Sys`, and are called qualified:
--- `Sys.name(args)`. At codegen the call lowers to the raw Lua `target` applied to
--- the (forwarded, un-arity-checked) arguments, with the result wrapped at the
--- Option boundary (a Lua `nil` becomes `none`, any other value `some`).
---
--- Like imports, extern declarations are metadata: they are collected by the
--- linker/bundler and emit no class code of their own. `params` is documentation
--- only — extern calls are not arity-checked, so variadic Lua targets work.

---@class ExternDecl: Stmt
---@field type "ExternDecl"
---@field name   string    Member name, called as `<Namespace>.<name>(...)`
---@field params string[]  Declared parameter names (documentation only)
---@field target string    Raw Lua target the call lowers to (e.g. "string.sub")
---@field line   integer | nil
---@field col    integer | nil
local ExternDecl = {}
ExternDecl.__index = ExternDecl

---@param name   string
---@param params string[]
---@param target string
---@param line?  integer
---@param col?   integer
---@return ExternDecl
function ExternDecl.new(name, params, target, line, col)
    return setmetatable(
        { type = "ExternDecl", name = name, params = params, target = target, line = line, col = col },
        ExternDecl
    )
end

---@return string
function ExternDecl:__tostring()
    return ("ExternDecl(%s(%d) = %q)"):format(self.name, #self.params, self.target)
end

return ExternDecl
