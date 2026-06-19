--- Interface for node-type-keyed semantic checks on statements.
---
--- Each statement rule returns a `StatementCheck` created with
--- `StatementCheck.new`. The dispatcher in `statements/init.lua` collects these
--- into a registry keyed by `type` and calls `rule.check(ctx, frame)` for every
--- matching statement.
---
--- `ctx` is the shared analysis context (see `schematic/init.lua`) carrying the
--- cross-cutting helpers; `frame` holds everything about the current statement.

---@class SemFrame
---@field stmt        Stmt                            The statement being checked
---@field idx         integer                         Its 1-based index within `stmts`
---@field stmts       Stmt[]                          The enclosing block
---@field symbols     table<string, {kind: string}>   Symbols visible in this scope
---@field in_function boolean                          True inside a function body
---@field in_loop     boolean                          True inside a loop body

---@class StatementCheck
---@field type  string                                AST node `type` this rule handles
---@field check fun(ctx: SemContext, frame: SemFrame)
local StatementCheck = {}

---@param node_type string
---@param check_fn  fun(ctx: SemContext, frame: SemFrame)
---@return StatementCheck
function StatementCheck.new(node_type, check_fn)
    assert(type(node_type) == "string",   "StatementCheck.new: type must be a string")
    assert(type(check_fn)  == "function", "StatementCheck.new: check must be a function")
    return { type = node_type, check = check_fn } --[[@as StatementCheck]]
end

return StatementCheck
