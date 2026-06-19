--- Semantic check for `break`: legal only inside a loop, and — because Lua 5.0
--- requires it — only as the last statement of its block (mirrors the `return`
--- rule).

local Error          = require("error")
local StatementCheck = require("frontend.schematic.statements.statement_check")

return StatementCheck.new("BreakStmt", function(ctx, frame)
    local stmt = frame.stmt --[[@as BreakStmt]]

    if not frame.in_loop then
        Error.throw(Error.Type.SEMANTIC_ERROR,
            "'break' outside of a loop",
            stmt.line, stmt.col, ctx.source)
    end

    if frame.idx ~= #frame.stmts then
        Error.throw(Error.Type.SEMANTIC_ERROR,
            "'break' must be the last statement in a block",
            stmt.line, stmt.col, ctx.source)
    end
end)
