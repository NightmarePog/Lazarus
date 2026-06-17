--- Fold rule for call expressions.
---
--- Calls are never folded — their result is only known at runtime — but their
--- callee and arguments are folded, so constants still propagate inward.

local FoldExpression = require("frontend.optimizer.expressions.expression_fold")

return FoldExpression.new("CallExpr", function(node, constants, recurse)
    ---@cast node CallExpr
    node.callee = recurse(node.callee, constants)
    for i, arg in ipairs(node.args) do
        node.args[i] = recurse(arg, constants)
    end
    return node
end)
