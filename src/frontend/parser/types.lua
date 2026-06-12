--- Base type annotations shared across all AST node modules.
---
--- `Expr` and `Stmt` are abstract base classes; concrete node types inherit
--- from one of these (e.g. `---@class BinaryExpr: Expr`).

--- Base class for all expression nodes.
---@class Expr
---@field type string  Discriminant tag (e.g. `"BinaryExpr"`, `"LiteralExpr"`)

--- Base class for all statement nodes.
---@class Stmt
---@field type string  Discriminant tag (e.g. `"VariableDecl"`, `"ExpressionStmt"`)
