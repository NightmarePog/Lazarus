--- Semantic check for binary expressions: validate both operands.

local ExpressionCheck = require("frontend.schematic.expressions.expression_check")

return ExpressionCheck.new("BinaryExpr", function(node, symbols, source, recurse, cx)
    ---@cast node BinaryExpr
    recurse(node.left, symbols, source, cx)
    recurse(node.right, symbols, source, cx)
end)
