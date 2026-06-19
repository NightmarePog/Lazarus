--- Base type annotations shared across all AST node modules, plus the parser
--- helper for reading a type annotation.
---
--- `Expr` and `Stmt` are abstract base classes; concrete node types inherit
--- from one of these (e.g. `---@class BinaryExpr: Expr`).

--- Base class for all expression nodes.
---@class Expr
---@field type string Discriminant tag (e.g. `"BinaryExpr"`, `"LiteralExpr"`)

--- Base class for all statement nodes.
---@class Stmt
---@field type string Discriminant tag (e.g. `"VariableDecl"`, `"ExpressionStmt"`)

--- A parsed type annotation. For the v1 skeleton a type is a bare name: a
--- built-in scalar (`int`/`float`/`str`/`bool`) or a user type name. Structured
--- forms (`[T]`, `{K:V}`) are added with collections later.
---@class TypeRef
---@field name string         The type name as written
---@field line integer | nil  1-based source line of the name
---@field col  integer | nil  1-based source column of the name

local Types = {}

--- The built-in scalar type names (lower-case, exempt from PascalCase casing).
---@type table<string, boolean>
Types.SCALARS = { int = true, float = true, str = true, bool = true }

--- Parse a type annotation. The caller has already consumed the leading `:`.
---@param parser Parser
---@return TypeRef
function Types.read_type(parser)
    local name = parser:_consume("IDENTIFIER", "Expected a type name after ':'")
    return { name = name.value, line = name.line, col = name.column }
end

return Types
