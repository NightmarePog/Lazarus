--- Semantic check for an index assignment (`object[index] = value`): validate
--- the target (its object and index) and the value. The collection's element
--- type is not tracked (untyped), so the value is not type-checked.

local StatementCheck = require("frontend.schematic.statements.statement_check")

return StatementCheck.new("IndexAssign", function(ctx, frame)
    local stmt = frame.stmt --[[@as IndexAssign]]
    ctx:check_expr(stmt.target, frame.symbols)
    ctx:check_expr(stmt.value, frame.symbols)
end)
