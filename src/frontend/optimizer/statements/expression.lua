--- Fold rule for expression statements: fold the wrapped expression so
--- constants propagate into it (the call's callee and arguments).

local FoldStatement = require("frontend.optimizer.statements.statement_fold")

return FoldStatement.new("ExpressionStmt", function(ctx, frame)
    local stmt = frame.stmt --[[@as ExpressionStmt]]
    stmt.expression = ctx:fold_expr(stmt.expression)
end)
