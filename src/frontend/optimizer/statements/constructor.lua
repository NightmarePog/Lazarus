--- Fold rule for a constructor: fold its body in a child context that inherits
--- the enclosing constants, with the parameters (and `self`) shadowing them.

local FoldStatement = require("frontend.optimizer.statements.statement_fold")

return FoldStatement.new("ConstructorDecl", function(ctx, frame)
    local stmt = frame.stmt --[[@as ConstructorDecl]]
    ctx:child(stmt.params):fold_block(stmt.body)
end)
