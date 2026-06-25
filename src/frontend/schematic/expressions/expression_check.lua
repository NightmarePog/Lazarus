--- Interface for node-type-keyed semantic checks on expressions.
---
--- Each expression rule returns an `ExpressionCheck` created with
--- `ExpressionCheck.new`. The dispatcher in `expressions/init.lua` keys them by
--- `type` and calls `rule.check(node, symbols, source, recurse, cx)`, where
--- `recurse` re-enters the checker for any sub-expressions and `cx` carries the
--- instance context used to validate `.field` / `self` accesses.

--- A symbol-table entry. The language is untyped; the only static facts tracked
--- about a binding are its `kind`, whether it may be reassigned (`mutable`) and
--- whether it is provably **not** a function (`noncallable`). Every entry is
--- created by `SemContext:bind` (or the class-root literal), both of which set
--- `noncallable`; `mutable` may be left absent (treated as false).
---@alias SymbolEntry { kind: string, mutable?: boolean, noncallable: boolean }

--- Names visible in a scope, keyed by identifier.
---@alias SymbolTable table<string, SymbolEntry>

--- Instance context threaded through expression checks so a `.field` / `self`
--- access can be validated against a receiver and the class's declared members.
---@alias ExprContext { properties: table<string, boolean>, methods: table<string, boolean>, in_instance: boolean }

---@alias ExprRecurse fun(node: Expr, symbols: SymbolTable, source: string, cx?: ExprContext)

---@class ExpressionCheck
---@field type  string                                  AST node `type` this rule handles
---@field check fun(node: Expr, symbols: SymbolTable, source: string, recurse: ExprRecurse, cx?: ExprContext)
local ExpressionCheck = {}

---@param node_type string
---@param check_fn  fun(node: Expr, symbols: SymbolTable, source: string, recurse: ExprRecurse, cx?: ExprContext)
---@return ExpressionCheck
function ExpressionCheck.new(node_type, check_fn)
    assert(type(node_type) == "string", "ExpressionCheck.new: type must be a string")
    assert(type(check_fn) == "function", "ExpressionCheck.new: check must be a function")
    return { type = node_type, check = check_fn } --[[@as ExpressionCheck]]
end

return ExpressionCheck
