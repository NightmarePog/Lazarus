--- AST node for a variable binding.
---
--- Covers every binding form the parser produces:
---   `private a = 1`      visibility "private", immutable
---   `public  a = 1`      visibility "public",  immutable
---   `private mut a = 1`  visibility "private", mutable
---   `mut a = 1`          no visibility (local), mutable
---   `a = 1`              no visibility (local), immutable — may also be a
---                        *reassignment*; Schematic decides by scope and sets
---                        `reassign`.

---@class VariableDecl: Stmt
---@field type       "VariableDecl"
---@field name       string                     Identifier name
---@field value      Expr | nil                 Initialiser expression, or `nil` when omitted (mutable only)
---@field visibility "private" | "public" | nil Explicit visibility, or `nil` for a function-local binding
---@field mutable    boolean                    Whether the binding may be reassigned
---@field is_static  boolean                    `static` modifier: a class-level member (vs. an instance property)
---@field type_ann   TypeRef | nil              Declared type annotation (`name: Type`), or `nil` if inferred
---@field reassign   boolean | nil              Set by Schematic: true when this rebinds an existing name
---@field line       integer | nil              1-based source line of the name
---@field col        integer | nil              1-based source column of the name
local VariableDecl = {}
VariableDecl.__index = VariableDecl

---@param name        string
---@param value       Expr | nil
---@param visibility? "private" | "public" | nil
---@param mutable?    boolean
---@param line?       integer
---@param col?        integer
---@param type_ann?   TypeRef
---@param is_static?  boolean
---@return VariableDecl
function VariableDecl.new(name, value, visibility, mutable, line, col, type_ann, is_static)
    return setmetatable({
        type = "VariableDecl",
        name = name,
        value = value,
        visibility = visibility,
        mutable = mutable or false,
        is_static = is_static or false,
        type_ann = type_ann,
        line = line,
        col = col,
    }, VariableDecl)
end

---@return string
function VariableDecl:__tostring()
    local prefix = (self.visibility and (self.visibility .. " ") or "")
        .. (self.mutable and "mut " or "")
    if self.value then
        return ("VariableDecl(%s%s = %s)"):format(prefix, self.name, tostring(self.value))
    end
    return ("VariableDecl(%s%s)"):format(prefix, self.name)
end

return VariableDecl
