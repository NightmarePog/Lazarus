--- Semantic check for identifier references: the name must be visible in scope.

local Error = require("error")
local ExpressionCheck = require("frontend.schematic.expressions.expression_check")

return ExpressionCheck.new("IdentifierExpr", function(node, symbols, source)
    ---@cast node IdentifierExpr
    -- `self` is reserved: the receiver has no name, instance fields are written
    -- with a leading dot (`.field`). Catch a bare `self` with a pointed message.
    if node.name == "self" then
        Error.throw(
            Error.Type.SEMANTIC_ERROR,
            "'self' is not a value; write instance fields with a leading dot ('.field')",
            node.line,
            node.col,
            source,
            #node.name
        )
    end
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
