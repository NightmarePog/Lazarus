--- Fold rule for a field assignment: fold the target's object and the value so
--- constants propagate into them.

local FoldStatement = require("frontend.optimizer.statements.statement_fold")

return FoldStatement.new("FieldAssign", function(ctx, frame)
    local stmt = frame.stmt --[[@as FieldAssign]]
    stmt.target = ctx:fold_expr(stmt.target)
    stmt.value  = ctx:fold_expr(stmt.value)
end)
