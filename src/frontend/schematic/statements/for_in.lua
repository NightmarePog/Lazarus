--- Semantic check for a `for-in` loop.
---
--- The iterated expression is validated in the enclosing scope, then the body is
--- analysed in a child scope holding the loop variable(s) — one (each value) or
--- two (key/index and value). Loop variables are fresh, immutable bindings scoped
--- to the loop and exempt from the top-level visibility rule. The body runs with
--- `in_loop` set so `break` is legal inside it.

local Error          = require("error")
local StatementCheck = require("frontend.schematic.statements.statement_check")
local Naming         = require("frontend.schematic.naming")

return StatementCheck.new("ForInStmt", function(ctx, frame)
    local stmt = frame.stmt --[[@as ForInStmt]]

    ctx:check_expr(stmt.iter, frame.symbols)

    local scope = ctx:child_scope(frame.symbols)
    for _, name in ipairs(stmt.vars) do
        if rawget(scope, name) then
            Error.throw(
                Error.Type.SEMANTIC_ERROR,
                "Duplicate loop variable '" .. name .. "'",
                stmt.line,
                stmt.col,
                ctx.source
            )
        end
        Naming.check_value(name, stmt, ctx.source, "Loop variable")
        ctx:bind(scope, name, "variable", false)
    end

    ctx:analyze_block(
        stmt.body,
        scope,
        frame.in_function,
        true,
        frame.return_type,
        frame.in_constructor
    )
end)
