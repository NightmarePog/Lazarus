--- Semantic check for call expressions: validate the callee and every argument.
---
--- Beyond checking that the callee and arguments are well-formed references, a
--- bare-name call must target something callable. The language is untyped, so the
--- check is conservative: it rejects a callee only when the bound value is
--- *provably* not a function (a literal, an arithmetic/logical result — see
--- `schematic/callability.lua`). A name that might hold a function (a parameter,
--- a call result) is allowed through.

local Error = require("error")
local ExpressionCheck = require("frontend.schematic.expressions.expression_check")

return ExpressionCheck.new("CallExpr", function(node, symbols, source, recurse, cx)
    ---@cast node CallExpr
    recurse(node.callee, symbols, source, cx)

    if node.callee.type == "IdentifierExpr" then
        local entry = symbols[node.callee.name]
        if entry and entry.noncallable then
            Error.throw(
                Error.Type.NOT_CALLABLE,
                "'" .. node.callee.name .. "' is not callable; it holds a value, not a function",
                node.callee.line,
                node.callee.col,
                source,
                #node.callee.name
            )
        end
    end

    for _, arg in ipairs(node.args) do
        recurse(arg, symbols, source, cx)
    end
end)
