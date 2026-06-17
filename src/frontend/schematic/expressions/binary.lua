--- Semantic check for binary expressions: validate both operands.

local ExpressionCheck = require("frontend.schematic.expressions.expression_check")

return ExpressionCheck.new("BinaryExpr", function(node, symbols, source, recurse)
    ---@cast node BinaryExpr
    recurse(node.left,  symbols, source)
    recurse(node.right, symbols, source)
end)
