--- Semantic check for field access (`object.field`): validate the object
--- expression. The field name is a dynamic table key, not a scope name, so it is
--- not checked here (instance field typing arrives with class fields later).

local ExpressionCheck = require("frontend.schematic.expressions.expression_check")

return ExpressionCheck.new("MemberExpr", function(node, symbols, source, recurse)
    ---@cast node MemberExpr
    recurse(node.object, symbols, source)
end)
