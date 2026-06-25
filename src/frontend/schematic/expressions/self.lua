--- Semantic check for the receiver value `self` (a `SelfExpr`).
---
--- `self` (and its shorthand `.field`) names the implicit receiver, so it is
--- valid only where one exists: inside an instance method or constructor. In a
--- `static` method or at the top level there is no receiver, so a bare `self`
--- is an error. A `.field` access (`MemberExpr` over a `SelfExpr`) is validated
--- by the member rule, which handles the receiver case itself; this rule fires
--- for `self` used as a standalone value (`return self`, `f(self)`, …).

local Error = require("error")
local ExpressionCheck = require("frontend.schematic.expressions.expression_check")

return ExpressionCheck.new("SelfExpr", function(node, _symbols, source, _recurse, cx)
    ---@cast node SelfExpr
    if not (cx and cx.in_instance) then
        Error.throw(
            Error.Type.SEMANTIC_ERROR,
            "'self' has no receiver here; it is valid only inside an instance method or constructor",
            node.line,
            node.col,
            source,
            4
        )
    end
end)
