--- Fold rule for variable bindings.
---
--- The initialiser is folded first. Then, if this is an *immutable* declaration
--- (not `mut`, not a reassignment) whose value collapsed to a `LiteralExpr`, the
--- name is recorded as a constant so later statements in the block can
--- substitute it inline (constant propagation). Mutable bindings and
--- reassignments are skipped — their value can change at runtime.

local FoldStatement = require("frontend.optimizer.statements.statement_fold")

return FoldStatement.new("VariableDecl", function(ctx, frame)
    local stmt = frame.stmt --[[@as VariableDecl]]

    if stmt.value then stmt.value = ctx:fold_expr(stmt.value) end

    if not stmt.mutable and not stmt.reassign then
        local val = stmt.value
        if val and val.type == "LiteralExpr" then
            ---@cast val LiteralExpr
            ctx:record_constant(stmt.name, val)
        end
    end
end)
