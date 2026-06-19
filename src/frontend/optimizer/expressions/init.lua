--- Expression-fold dispatcher.
---
--- Collects the per-node-type `FoldExpression` rules into a registry and exposes
--- a single `fold_expr(node, constants)` that routes to the matching rule. Node
--- types with no rule (e.g. literals) are already in their final form and are
--- returned untouched.
---
--- To add a rule, create a `FoldExpression` module and list it in `HANDLERS`.

---@type FoldExpression[]
local HANDLERS = {
    (require("frontend.optimizer.expressions.identifier")),
    (require("frontend.optimizer.expressions.binary")),
    (require("frontend.optimizer.expressions.call")),
    (require("frontend.optimizer.expressions.unary")),
}

---@type table<string, FoldExpression>
local registry = {}
for _, handler in ipairs(HANDLERS) do
    registry[handler.type] = handler
end

--- Fold an expression (and, recursively, its sub-expressions), returning the
--- possibly-replaced node.
---@param node      Expr
---@param constants table<string, LiteralExpr>
---@return Expr
local function fold_expr(node, constants)
    local rule = registry[node.type]
    if rule then
        return rule.fold(node, constants, fold_expr)
    end
    return node
end

return fold_expr
