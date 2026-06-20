--- Semantic check for `loop`: analyse the body in a child scope with `in_loop`
--- set so `break` is legal inside it.

local StatementCheck = require("frontend.schematic.statements.statement_check")

return StatementCheck.new("LoopStmt", function(ctx, frame)
    local stmt = frame.stmt --[[@as LoopStmt]]
    ctx:analyze_block(stmt.body, ctx:child_scope(frame.symbols),
        frame.in_function, true, frame.return_type, frame.in_constructor)
end)
