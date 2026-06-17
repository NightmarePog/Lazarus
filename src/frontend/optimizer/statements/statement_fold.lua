--- Interface for node-type-keyed fold rules on statements.
---
--- Each statement rule returns a `FoldStatement` created with
--- `FoldStatement.new`. The dispatcher in `statements/init.lua` collects these
--- into a registry keyed by `type` and calls `rule.fold(ctx, frame)` for every
--- matching statement.
---
--- `ctx` is the shared fold context (see `optimizer/init.lua`) carrying the
--- cross-cutting helpers — expression folding, constant recording, child scopes
--- and block recursion; `frame` holds everything about the current statement.
--- Statements are mutated in place, so a rule has nothing to return.

---@class FoldFrame
---@field stmt  Stmt      The statement being folded
---@field idx   integer   Its 1-based index within `stmts`
---@field stmts Stmt[]    The enclosing block

---@class FoldStatement
---@field type string                                  AST node `type` this rule handles
---@field fold fun(ctx: FoldContext, frame: FoldFrame)
local FoldStatement = {}

---@param node_type string
---@param fold_fn   fun(ctx: FoldContext, frame: FoldFrame)
---@return FoldStatement
function FoldStatement.new(node_type, fold_fn)
    assert(type(node_type) == "string",   "FoldStatement.new: type must be a string")
    assert(type(fold_fn)   == "function", "FoldStatement.new: fold must be a function")
    return { type = node_type, fold = fold_fn } --[[@as FoldStatement]]
end

return FoldStatement
