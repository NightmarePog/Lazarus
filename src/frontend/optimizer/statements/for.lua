--- Fold rule for the C-style `for` loop.
---
--- The init's initialiser is folded against the enclosing constants. The loop
--- variable is **mutable across iterations**, so it is deliberately never
--- recorded as a constant: the init is folded directly rather than through the
--- variable rule, and the loop variable's name is shadowed out of the child
--- context used for the condition, step and body.

local FoldStatement = require("frontend.optimizer.statements.statement_fold")

return FoldStatement.new("ForStmt", function(ctx, frame)
    local stmt  = frame.stmt --[[@as ForStmt]]
    local inner = ctx:child(stmt.init and { stmt.init.name } or {})

    if stmt.init and stmt.init.value then
        stmt.init.value = ctx:fold_expr(stmt.init.value)
    end
    if stmt.condition then stmt.condition = inner:fold_expr(stmt.condition) end
    if stmt.step then inner:fold_block({ stmt.step }) end

    inner:fold_block(stmt.body)
end)
