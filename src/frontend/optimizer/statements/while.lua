--- Fold rule for `while`: fold the condition against the enclosing constants and
--- fold the body in a child context (so body-local constants do not leak out).

local FoldStatement = require("frontend.optimizer.statements.statement_fold")

return FoldStatement.new("WhileStmt", function(ctx, frame)
    local stmt = frame.stmt --[[@as WhileStmt]]
    stmt.condition = ctx:fold_expr(stmt.condition)
    ctx:child({}):fold_block(stmt.body)
end)
