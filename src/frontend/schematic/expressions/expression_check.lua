--- Interface for node-type-keyed semantic checks on expressions.
---
--- Each expression rule returns an `ExpressionCheck` created with
--- `ExpressionCheck.new`. The dispatcher in `expressions/init.lua` keys them by
--- `type` and calls `rule.check(node, symbols, source, recurse)`, where
--- `recurse` re-enters the checker for any sub-expressions.

---@alias ExprRecurse fun(node: Expr, symbols: table<string, {kind: string}>, source: string)

---@class ExpressionCheck
---@field type  string                                  AST node `type` this rule handles
---@field check fun(node: Expr, symbols: table<string, {kind: string}>, source: string, recurse: ExprRecurse)
local ExpressionCheck = {}

---@param node_type string
---@param check_fn  fun(node: Expr, symbols: table<string, {kind: string}>, source: string, recurse: ExprRecurse)
---@return ExpressionCheck
function ExpressionCheck.new(node_type, check_fn)
    assert(type(node_type) == "string",   "ExpressionCheck.new: type must be a string")
    assert(type(check_fn)  == "function", "ExpressionCheck.new: check must be a function")
    return { type = node_type, check = check_fn } --[[@as ExpressionCheck]]
end

return ExpressionCheck
