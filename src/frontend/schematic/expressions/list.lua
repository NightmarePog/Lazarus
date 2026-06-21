--- Semantic check for a list literal: validate each element expression.

local ExpressionCheck = require("frontend.schematic.expressions.expression_check")

return ExpressionCheck.new("ListExpr", function(node, symbols, source, recurse, cx)
    ---@cast node ListExpr
    for _, element in ipairs(node.elements) do
        recurse(element, symbols, source, cx)
    end
end)
