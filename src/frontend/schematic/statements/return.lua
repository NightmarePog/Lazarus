--- Semantic check for `return` statements: only legal inside a function and
--- only as the last statement of its block (mirrors Lua).

local Error          = require("error")
local StatementCheck = require("frontend.schematic.statements.statement_check")

return StatementCheck.new("ReturnStmt", function(ctx, frame)
    local stmt = frame.stmt --[[@as ReturnStmt]]

    if frame.in_constructor then
        Error.throw(Error.Type.SEMANTIC_ERROR,
            "'return' is not allowed in a constructor; the instance is returned implicitly",
            stmt.line, stmt.col, ctx.source)
    end

    if not frame.in_function then
        Error.throw(Error.Type.SEMANTIC_ERROR,
            "'return' outside of a function",
            stmt.line, stmt.col, ctx.source)
    end

    if frame.idx ~= #frame.stmts then
        Error.throw(Error.Type.SEMANTIC_ERROR,
            "'return' must be the last statement in a block",
            stmt.line, stmt.col, ctx.source)
    end

    if stmt.value then
        ctx:check_expr(stmt.value, frame.symbols)
        local value_type = ctx:infer(stmt.value, frame.symbols)
        ctx:expect_assignable(frame.return_type or "any", value_type, stmt.value,
            "Function return")
    end
end)
