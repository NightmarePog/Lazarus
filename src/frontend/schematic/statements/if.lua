--- Semantic check for `if` / `else if` / `else`.
---
--- Every clause condition is validated against the visible symbols, and each
--- block is analysed in its own child scope so a binding declared in one branch
--- neither leaks out nor collides with another branch. `in_function`/`in_loop`
--- are inherited so `return`/`break` placed inside a branch are judged by the
--- enclosing context.

local StatementCheck = require("frontend.schematic.statements.statement_check")

return StatementCheck.new("IfStmt", function(ctx, frame)
    local stmt = frame.stmt --[[@as IfStmt]]

    for _, clause in ipairs(stmt.clauses) do
        ctx:check_expr(clause.condition, frame.symbols)
        ctx:analyze_block(clause.body, ctx:child_scope(frame.symbols),
            frame.in_function, frame.in_loop)
    end

    if stmt.else_body then
        ctx:analyze_block(stmt.else_body, ctx:child_scope(frame.symbols),
            frame.in_function, frame.in_loop)
    end
end)
