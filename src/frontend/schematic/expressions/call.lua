--- Semantic check for call expressions: validate the callee and every argument.

local ExpressionCheck = require("frontend.schematic.expressions.expression_check")

return ExpressionCheck.new("CallExpr", function(node, symbols, source, recurse)
    ---@cast node CallExpr
    recurse(node.callee, symbols, source)
    for _, arg in ipairs(node.args) do
        recurse(arg, symbols, source)
    end
end)
