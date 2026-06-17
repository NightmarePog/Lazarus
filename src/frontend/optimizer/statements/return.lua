--- Fold rule for `return` statements: fold the optional return value. A bare
--- `return` carries no value and is left untouched.

local FoldStatement = require("frontend.optimizer.statements.statement_fold")

return FoldStatement.new("ReturnStmt", function(ctx, frame)
    local stmt = frame.stmt --[[@as ReturnStmt]]
    if stmt.value then stmt.value = ctx:fold_expr(stmt.value) end
end)
