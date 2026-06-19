--- Fold rule for `loop`: fold the body in a child context (so body-local
--- constants do not leak out).

local FoldStatement = require("frontend.optimizer.statements.statement_fold")

return FoldStatement.new("LoopStmt", function(ctx, frame)
    local stmt = frame.stmt --[[@as LoopStmt]]
    ctx:child({}):fold_block(stmt.body)
end)
