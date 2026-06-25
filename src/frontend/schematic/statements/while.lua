--- Semantic check for `while`: validate the condition, then analyse the body in
--- a child scope with `in_loop` set so `break` is legal inside it.

local StatementCheck = require("frontend.schematic.statements.statement_check")

return StatementCheck.new("WhileStmt", function(ctx, frame)
    local stmt = frame.stmt --[[@as WhileStmt]]
    ctx:check_condition(stmt.condition, frame.symbols)
    ctx:analyze_block(
        stmt.body,
        ctx:child_scope(frame.symbols),
        frame.in_function,
        true,
        frame.return_type,
        frame.in_constructor
    )
end)
