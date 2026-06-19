--- Semantic analysis pass: walks the AST and enforces semantic rules.
---
--- The rules themselves live next to this file, one module per node type:
---   • `statements/` — a `StatementCheck` per statement (variable, function, …)
---   • `expressions/` — an `ExpressionCheck` per expression (identifier, call, …)
---
--- This module is just the driver. It builds a shared `SemContext` and walks
--- each block, dispatching every statement to its registered rule. The
--- cross-cutting helpers a rule might need — duplicate detection, name binding,
--- expression checking, child-scope creation, recursion into nested blocks —
--- live on the context so the individual rules stay small and focused.

local Error              = require("error")
local statement_registry = require("frontend.schematic.statements")
local check_expr         = require("frontend.schematic.expressions")
local TypeCheck          = require("frontend.schematic.types")

---@class SemContext
---@field source string
local SemContext = {}
SemContext.__index = SemContext

---@param source string
---@return SemContext
function SemContext.new(source)
    return setmetatable({ source = source }, SemContext)
end

--- Throw if `name` is already declared in the *current* scope. Reference
--- lookups still fall through to parent scopes (lexical scoping); `rawget`
--- answers the narrower question "declared *here*?".
---@param symbols table<string, {kind: string}>
---@param name    string
---@param node    Stmt
function SemContext:check_duplicate(symbols, name, node)
    if rawget(symbols, name) then
        Error.throw(Error.Type.SEMANTIC_ERROR,
            "Duplicate declaration '" .. name .. "'",
            node.line, node.col, self.source, #name)
    end
end

--- Bind a name in the given scope.
---@param symbols  table<string, {kind: string, mutable: boolean, vtype: string?}>
---@param name     string
---@param kind     string
---@param mutable? boolean  Whether the binding may be reassigned (default false)
---@param vtype?   string   The binding's static type ("int"/"float"/"str"/"bool"/"any")
function SemContext:bind(symbols, name, kind, mutable, vtype)
    symbols[name] = { kind = kind, mutable = mutable or false, vtype = vtype or "any" }
end

--- Validate an expression (and its sub-expressions) against visible symbols.
---@param node    Expr
---@param symbols table<string, {kind: string}>
function SemContext:check_expr(node, symbols)
    check_expr(node, symbols, self.source)
end

--- Infer an expression's type (and type-check its operators).
---@param node    Expr
---@param symbols table<string, {vtype: string?}>
---@return string
function SemContext:infer(node, symbols)
    return TypeCheck.infer(node, symbols, self.source)
end

--- Require a condition expression to be `bool`.
---@param node    Expr
---@param symbols table
---@param what    string
function SemContext:expect_bool(node, symbols, what)
    TypeCheck.expect_bool(node, symbols, self.source, what)
end

--- Resolve a parsed annotation to an internal type string.
---@param ref TypeRef | nil
---@return string
function SemContext:resolve_type(ref)
    return TypeCheck.resolve(ref)
end

--- Require `actual` to be assignable to `expected` (gradual; `any` accepted).
---@param expected string
---@param actual   string
---@param node     Expr
---@param what     string
function SemContext:expect_assignable(expected, actual, node, what)
    TypeCheck.expect_assignable(expected, actual, node, self.source, what)
end

--- Create a child scope that inherits visible declarations from `parent`.
--- Declarations made in the child stay local to it.
---@param parent table<string, {kind: string}>
---@return table<string, {kind: string}>
function SemContext:child_scope(parent)
    return setmetatable({}, { __index = parent })
end

--- Walk a block in source order, dispatching each statement to its rule.
--- Statement types with no registered rule are ignored.
---@param stmts       Stmt[]
---@param symbols     table<string, {kind: string}>
---@param in_function boolean
---@param in_loop?    boolean   True inside a loop body (governs `break` legality)
---@param return_type? string   Declared return type of the enclosing function, threaded to `return`
function SemContext:analyze_block(stmts, symbols, in_function, in_loop, return_type)
    for idx, stmt in ipairs(stmts) do
        local rule = statement_registry[stmt.type]
        if rule then
            rule.check(self, {
                stmt        = stmt,
                idx         = idx,
                stmts       = stmts,
                symbols     = symbols,
                in_function = in_function,
                in_loop     = in_loop or false,
                return_type = return_type,
            })
        end
    end
end

---@param ast    AST
---@param source string
local function analyze(ast, source)
    SemContext.new(source):analyze_block(ast.body, {}, false, false)
end

return { analyze = analyze }
