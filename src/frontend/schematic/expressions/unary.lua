--- Semantic check for unary expressions (`not x`): validate the operand.

local ExpressionCheck = require("frontend.schematic.expressions.expression_check")

return ExpressionCheck.new("UnaryExpr", function(node, symbols, source, recurse)
    ---@cast node UnaryExpr
    recurse(node.operand, symbols, source)
end)
