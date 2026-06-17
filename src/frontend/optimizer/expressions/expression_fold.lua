--- Interface for node-type-keyed fold rules on expressions.
---
--- Each expression rule returns a `FoldExpression` created with
--- `FoldExpression.new`. The dispatcher in `expressions/init.lua` keys them by
--- `type` and calls `rule.fold(node, constants, recurse)`, where `recurse`
--- re-enters the folder for any sub-expressions.
---
--- Unlike statement rules, an expression rule *returns* a node: folding may
--- replace one node with another (e.g. a `BinaryExpr` collapsing to a
--- `LiteralExpr`), so the caller assigns the result back.

---@alias FoldRecurse fun(node: Expr, constants: table<string, LiteralExpr>): Expr

---@class FoldExpression
---@field type string                                  AST node `type` this rule handles
---@field fold fun(node: Expr, constants: table<string, LiteralExpr>, recurse: FoldRecurse): Expr
local FoldExpression = {}

---@param node_type string
---@param fold_fn   fun(node: Expr, constants: table<string, LiteralExpr>, recurse: FoldRecurse): Expr
---@return FoldExpression
function FoldExpression.new(node_type, fold_fn)
    assert(type(node_type) == "string",   "FoldExpression.new: type must be a string")
    assert(type(fold_fn)   == "function", "FoldExpression.new: fold must be a function")
    return { type = node_type, fold = fold_fn } --[[@as FoldExpression]]
end

return FoldExpression
