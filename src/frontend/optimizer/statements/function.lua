--- Fold rule for function declarations.
---
--- The body is folded in a child context that inherits the enclosing constants,
--- so they still propagate inward — except a parameter of the same name shadows
--- the constant and is dropped from the child's table (see `FoldContext:child`).

local FoldStatement = require("frontend.optimizer.statements.statement_fold")

return FoldStatement.new("FunctionDecl", function(ctx, frame)
    local stmt = frame.stmt --[[@as FunctionDecl]]
    ctx:child(stmt.params):fold_block(stmt.body)
end)
