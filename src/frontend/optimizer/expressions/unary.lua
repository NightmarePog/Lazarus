--- Fold rule for unary expressions: fold the operand so constants propagate into
--- it. The operation itself is not evaluated at compile time.

local FoldExpression = require("frontend.optimizer.expressions.expression_fold")

return FoldExpression.new("UnaryExpr", function(node, constants, recurse)
    ---@cast node UnaryExpr
    node.operand = recurse(node.operand, constants)
    return node
end)
