--- Fold rule for `if` statements: fold each clause condition against the
--- enclosing constants, and fold each block in a child context so constants
--- recorded inside one branch never leak out to siblings or later statements.

local FoldStatement = require("frontend.optimizer.statements.statement_fold")

return FoldStatement.new("IfStmt", function(ctx, frame)
    local stmt = frame.stmt --[[@as IfStmt]]

    for _, clause in ipairs(stmt.clauses) do
        clause.condition = ctx:fold_expr(clause.condition)
        ctx:child({}):fold_block(clause.body)
    end

    if stmt.else_body then
        ctx:child({}):fold_block(stmt.else_body)
    end
end)
