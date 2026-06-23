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

local Error = require("error")
local statement_registry = require("frontend.schematic.statements")
local check_expr = require("frontend.schematic.expressions")
local Booleanity = require("frontend.schematic.booleanity")

---@class SemContext
---@field source      string
---@field properties  table<string, boolean>  Declared instance-property names (valid `.field` targets)
---@field methods     table<string, boolean>  Instance-method names (valid `.method()` targets on the receiver)
---@field in_instance boolean                  True while analysing an instance method/constructor body (a receiver exists)
local SemContext = {}
SemContext.__index = SemContext

---@param source string
---@return SemContext
function SemContext.new(source)
    return setmetatable(
        { source = source, properties = {}, methods = {}, in_instance = false },
        SemContext
    )
end

--- Throw if `name` is already declared in the *current* scope. Reference
--- lookups still fall through to parent scopes (lexical scoping); `rawget`
--- answers the narrower question "declared *here*?".
---@param symbols SymbolTable
---@param name    string
---@param node    Stmt
function SemContext:check_duplicate(symbols, name, node)
    if rawget(symbols, name) then
        -- Callers pass a concrete declaration node (FunctionDecl/VariableDecl);
        -- the abstract `Stmt` base omits the positional fields every node carries.
        ---@cast node { line: integer|nil, col: integer|nil }
        Error.throw(
            Error.Type.SEMANTIC_ERROR,
            "Duplicate declaration '" .. name .. "'",
            node.line,
            node.col,
            self.source,
            #name
        )
    end
end

--- Bind a name in the given scope.
---
--- The language is untyped; the only static fact tracked about a value is whether
--- it is provably **not** a function (`noncallable`), so a call on it can be
--- rejected up front (see `expressions/call.lua`).
---@param symbols      SymbolTable
---@param name         string
---@param kind         string
---@param mutable?     boolean  Whether the binding may be reassigned (default false)
---@param noncallable? boolean  True when the bound value is statically known not to be a function
-- Method of the SemContext API, invoked as `ctx:bind(...)` across the rule
-- modules; the colon convention is required even though this body ignores `self`.
---@diagnostic disable-next-line: unused
function SemContext:bind(symbols, name, kind, mutable, noncallable)
    symbols[name] = { kind = kind, mutable = mutable or false, noncallable = noncallable or false }
end

--- Validate an expression (and its sub-expressions) against visible symbols.
--- The instance context (`properties`, `in_instance`) is threaded so that a
--- `.field` access can be checked for a receiver and a declared property.
---@param node    Expr
---@param symbols SymbolTable
function SemContext:check_expr(node, symbols)
    check_expr(
        node,
        symbols,
        self.source,
        { properties = self.properties, methods = self.methods, in_instance = self.in_instance }
    )
end

--- Validate an expression used as a **condition** (`if`/`while`/`for`). The
--- language has no truthiness, so a condition must be a boolean. The check is
--- best-effort: it rejects only values that are provably non-boolean (see
--- `booleanity.lua`), leaving maybe-boolean expressions (names, fields, calls)
--- alone.
---@param node    Expr
---@param symbols SymbolTable
function SemContext:check_condition(node, symbols)
    self:check_expr(node, symbols)
    local reason = Booleanity.non_bool_reason(node)
    if reason then
        Error.throw(
            Error.Type.SEMANTIC_ERROR,
            "Condition must be a boolean, but this is "
                .. reason
                .. "; the language has no truthiness, so use an explicit comparison"
                .. " or a boolean method (e.g. '.is_some()')",
            node.line,
            node.col,
            self.source
        )
    end
end

--- Create a child scope that inherits visible declarations from `parent`.
--- Declarations made in the child stay local to it.
---@param parent SymbolTable
---@return SymbolTable
-- Method of the SemContext API, invoked as `ctx:child_scope(...)` across the rule
-- modules; the colon convention is required even though this body ignores `self`.
---@diagnostic disable-next-line: unused
function SemContext:child_scope(parent) return setmetatable({}, { __index = parent }) end

--- Walk a block in source order, dispatching each statement to its rule.
--- Statement types with no registered rule are ignored.
---@param stmts       Stmt[]
---@param symbols     SymbolTable
---@param in_function boolean
---@param in_loop?    boolean   True inside a loop body (governs `break` legality)
---@param return_type? string   Declared return type of the enclosing function, threaded to `return`
---@param in_constructor? boolean  True inside a constructor body (locals allowed, but `return` is not)
function SemContext:analyze_block(stmts, symbols, in_function, in_loop, return_type, in_constructor)
    for idx, stmt in ipairs(stmts) do
        local rule = statement_registry[stmt.type]
        if rule then
            rule.check(self, {
                stmt = stmt,
                idx = idx,
                stmts = stmts,
                symbols = symbols,
                in_function = in_function,
                in_loop = in_loop or false,
                return_type = return_type,
                in_constructor = in_constructor or false,
            })
        end
    end
end

---@param ast          AST
---@param source       string
---@param class_name?  string    The enclosing class name (default "Main"), bound so construction `ClassName(...)` resolves.
---@param import_names? string[]  Imported class names, bound so `Other(...)` / `Other.static()` resolve to a visible class.
local function analyze(ast, source, class_name, import_names)
    local root = {}
    root[class_name or "Main"] = { kind = "class", mutable = false, noncallable = false }
    if import_names then
        for _, name in ipairs(import_names) do
            root[name] = { kind = "class", mutable = false, noncallable = false }
        end
    end

    local ctx = SemContext.new(source)
    -- Collect the class's instance properties and instance methods up front, so a
    -- `.field` / `.method()` access on the receiver resolves regardless of whether
    -- the member is declared before or after the code that uses it.
    for _, stmt in ipairs(ast.body) do
        if stmt.type == "VariableDecl" and stmt.visibility and not stmt.is_static then
            if ctx.properties[stmt.name] then
                Error.throw(
                    Error.Type.SEMANTIC_ERROR,
                    "Duplicate declaration '" .. stmt.name .. "'",
                    stmt.line,
                    stmt.col,
                    source,
                    #stmt.name
                )
            end
            ctx.properties[stmt.name] = true
        elseif stmt.type == "FunctionDecl" and not stmt.is_static then
            ctx.methods[stmt.name] = true
        end
    end

    ctx:analyze_block(ast.body, root, false, false)
end

return { analyze = analyze }
