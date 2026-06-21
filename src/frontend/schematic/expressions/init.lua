--- Expression-check dispatcher.
---
--- Collects the per-node-type `ExpressionCheck` rules into a registry and
--- exposes a single `check_expr(node, symbols, source)` that routes to the
--- matching rule. Node types with no rule (e.g. literals) need no validation
--- and are silently ignored.
---
--- To add a rule, create an `ExpressionCheck` module and list it in `HANDLERS`.

---@type ExpressionCheck[]
local HANDLERS = {
    (require("frontend.schematic.expressions.identifier")),
    (require("frontend.schematic.expressions.binary")),
    (require("frontend.schematic.expressions.call")),
    (require("frontend.schematic.expressions.unary")),
    (require("frontend.schematic.expressions.member")),
    (require("frontend.schematic.expressions.self")),
    (require("frontend.schematic.expressions.list")),
    (require("frontend.schematic.expressions.map")),
    (require("frontend.schematic.expressions.index")),
}

---@type table<string, ExpressionCheck>
local registry = {}
for _, handler in ipairs(HANDLERS) do
    registry[handler.type] = handler
end

--- Validate an expression (and, recursively, its sub-expressions).
---@param node    Expr
---@param symbols table<string, {kind: string}>
---@param source  string
---@param cx?     { properties: table<string, boolean>, in_instance: boolean }  Instance context for `.field` checks
local function check_expr(node, symbols, source, cx)
    local rule = registry[node.type]
    if rule then rule.check(node, symbols, source, check_expr, cx) end
end

return check_expr
