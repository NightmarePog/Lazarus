--- Semantic check for a map literal: validate each key and value expression.

local ExpressionCheck = require("frontend.schematic.expressions.expression_check")

return ExpressionCheck.new("MapExpr", function(node, symbols, source, recurse, cx)
    ---@cast node MapExpr
    for _, entry in ipairs(node.entries) do
        recurse(entry.key, symbols, source, cx)
        recurse(entry.value, symbols, source, cx)
    end
end)
