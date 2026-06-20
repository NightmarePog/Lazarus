--- Semantic check for call expressions: validate the callee and every argument.
---
--- Beyond checking that the callee and arguments are well-formed references, a
--- bare-name call must target something callable. The check is **gradual**: it
--- only rejects a callee whose type is a known scalar (`int`/`float`/`str`/
--- `bool`) — those can never be invoked. An `any`-typed binding (e.g. an
--- un-annotated parameter) is allowed through, since it might hold a function.

local Error           = require("error")
local ExpressionCheck = require("frontend.schematic.expressions.expression_check")

-- Value types that can never be invoked as a function.
local NON_CALLABLE = { int = true, float = true, str = true, bool = true }

return ExpressionCheck.new("CallExpr", function(node, symbols, source, recurse)
    ---@cast node CallExpr
    recurse(node.callee, symbols, source)

    if node.callee.type == "IdentifierExpr" then
        local entry = symbols[node.callee.name]
        if entry and NON_CALLABLE[entry.vtype] then
            Error.throw(Error.Type.NOT_CALLABLE,
                "'" .. node.callee.name .. "' is not callable; it is a '" ..
                entry.vtype .. "', not a function",
                node.callee.line, node.callee.col, source, #node.callee.name)
        end
    end

    for _, arg in ipairs(node.args) do
        recurse(arg, symbols, source)
    end
end)
