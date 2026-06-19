--- Fold rule for field access: fold the object expression so constants propagate
--- into it. The field access itself is not evaluated at compile time.

local FoldExpression = require("frontend.optimizer.expressions.expression_fold")

return FoldExpression.new("MemberExpr", function(node, constants, recurse)
    ---@cast node MemberExpr
    node.object = recurse(node.object, constants)
    return node
end)
