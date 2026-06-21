--- Semantic check for an index access (`object[index]`): validate both the
--- indexed expression and the index/key expression. The element type is not
--- tracked (the language is untyped), so nothing more is checked here.

local ExpressionCheck = require("frontend.schematic.expressions.expression_check")

return ExpressionCheck.new("IndexExpr", function(node, symbols, source, recurse, cx)
    ---@cast node IndexExpr
    recurse(node.object, symbols, source, cx)
    recurse(node.index, symbols, source, cx)
end)
