--- Fold rule for identifier references: constant propagation.
---
--- If the name resolves to a known compile-time literal (recorded by the
--- variable rule when an immutable binding folded to a `LiteralExpr`), the
--- reference is replaced with that literal. Otherwise the identifier survives.

local FoldExpression = require("frontend.optimizer.expressions.expression_fold")

return FoldExpression.new("IdentifierExpr", function(node, constants)
    ---@cast node IdentifierExpr
    return constants[node.name] or node
end)
