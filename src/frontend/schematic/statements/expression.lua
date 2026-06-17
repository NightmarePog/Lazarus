--- Semantic check for expression statements.
---
--- A call is the only expression that is a valid Lua statement. Anything else
--- (a bare literal, identifier or arithmetic) has no effect and cannot be
--- lowered to loadable Lua, so it is rejected.

local Error          = require("error")
local StatementCheck = require("frontend.schematic.statements.statement_check")

return StatementCheck.new("ExpressionStmt", function(ctx, frame)
    local stmt = frame.stmt --[[@as ExpressionStmt]]
    ctx:check_expr(stmt.expression, frame.symbols)
    if stmt.expression.type ~= "CallExpr" then
        Error.throw(Error.Type.SEMANTIC_ERROR,
            "Bare expressions are not valid statements",
            stmt.line, stmt.col, ctx.source)
    end
end)
