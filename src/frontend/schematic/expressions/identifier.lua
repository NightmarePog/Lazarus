--- Semantic check for identifier references: the name must be visible in scope.

local Error = require("error")
local ExpressionCheck = require("frontend.schematic.expressions.expression_check")

return ExpressionCheck.new("IdentifierExpr", function(node, symbols, source)
    ---@cast node IdentifierExpr
    -- `self` is a keyword (a `SelfExpr`), never an identifier, so it does not
    -- reach this rule.
    if not symbols[node.name] then
        Error.throw(
            Error.Type.SEMANTIC_ERROR,
            "Undeclared identifier '" .. node.name .. "'",
            node.line,
            node.col,
            source,
            #node.name
        )
    end
end)
