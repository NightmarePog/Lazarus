--- Semantic check for a field assignment (`object.field = value`): validate the
--- target's object and the value. Instance field types are not tracked yet, so
--- the assignment is not type-checked against a declared field type.

local StatementCheck = require("frontend.schematic.statements.statement_check")

return StatementCheck.new("FieldAssign", function(ctx, frame)
    local stmt = frame.stmt --[[@as FieldAssign]]
    ctx:check_expr(stmt.target, frame.symbols)
    ctx:check_expr(stmt.value, frame.symbols)
end)
