--- Semantic check for a class constructor.
---
--- Must appear at the top level of a class (not nested in a function). Its
--- parameters and the implicit `self` are bound in a child scope, then the body
--- is analysed. A constructor body is a function-like scope (local bindings are
--- allowed), but it must not `return` — the instance is returned implicitly — so
--- it is analysed with `in_constructor = true`, which `return.lua` rejects.

local Error          = require("error")
local StatementCheck = require("frontend.schematic.statements.statement_check")
local Naming         = require("frontend.schematic.naming")

return StatementCheck.new("ConstructorDecl", function(ctx, frame)
    local stmt = frame.stmt --[[@as ConstructorDecl]]

    if frame.in_function then
        Error.throw(Error.Type.SEMANTIC_ERROR,
            "'constructor' must be at the top level of a class",
            stmt.line, stmt.col, ctx.source)
    end

    local scope = ctx:child_scope(frame.symbols)
    for i, param in ipairs(stmt.params) do
        if rawget(scope, param) then
            Error.throw(Error.Type.SEMANTIC_ERROR,
                "Duplicate parameter '" .. param .. "'",
                stmt.line, stmt.col, ctx.source)
        end
        Naming.check_value(param, stmt, ctx.source, "Parameter")
        Naming.check_type(stmt.param_types[i], ctx.source)
        scope[param] = { kind = "variable", vtype = ctx:resolve_type(stmt.param_types[i]) }
    end
    scope["self"] = { kind = "variable", vtype = "any" }

    ctx:analyze_block(stmt.body, scope, true, false, nil, true)
end)
