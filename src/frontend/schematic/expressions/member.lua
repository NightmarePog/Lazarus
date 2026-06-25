--- Semantic check for field access (`object.field`).
---
--- A leading-dot access (`.field`) parses to a `MemberExpr` whose object is a
--- `SelfExpr` — the implicit receiver. It is valid only where a receiver exists
--- (an instance method or constructor) and must name a **declared** instance
--- property or an instance **method** (`.method()`); an undeclared `.bogus` or a
--- `.field` in a static/top-level context is an error.
---
--- For any other object (a local, a parameter, a constructed value) the field is
--- a dynamic table key, not a scope name, so only the object expression is
--- validated — instance field typing on arbitrary values arrives with imports.

local Error = require("error")
local ExpressionCheck = require("frontend.schematic.expressions.expression_check")

return ExpressionCheck.new("MemberExpr", function(node, symbols, source, recurse, cx)
    ---@cast node MemberExpr
    if node.object.type == "SelfExpr" then
        if not (cx and cx.in_instance) then
            Error.throw(
                Error.Type.SEMANTIC_ERROR,
                "'."
                    .. node.field
                    .. "' refers to an instance field, but there is no "
                    .. "receiver here; it is valid only inside an instance method or constructor",
                node.line,
                node.col,
                source,
                #node.field + 1
            )
        end
        ---@cast cx -nil  the guard above throws (noreturn) when cx is nil
        local known = (cx.properties and cx.properties[node.field])
            or (cx.methods and cx.methods[node.field])
        if not known then
            Error.throw(
                Error.Type.SEMANTIC_ERROR,
                "Unknown instance member '."
                    .. node.field
                    .. "'; declare it as a "
                    .. "'private'/'public' property or an instance method",
                node.line,
                node.col,
                source,
                #node.field + 1
            )
        end
        return
    end

    recurse(node.object, symbols, source, cx)
end)
