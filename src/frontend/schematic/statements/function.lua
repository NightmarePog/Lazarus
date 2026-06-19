--- Semantic check for function declarations.
---
--- The name is bound in the enclosing scope *before* the body is walked, so a
--- function may call itself (recursion). The body is checked in a child scope
--- that inherits the enclosing declarations and adds the parameters.

local Error          = require("error")
local StatementCheck = require("frontend.schematic.statements.statement_check")
local Naming         = require("frontend.schematic.naming")

return StatementCheck.new("FunctionDecl", function(ctx, frame)
    local stmt = frame.stmt --[[@as FunctionDecl]]
    ctx:check_duplicate(frame.symbols, stmt.name, stmt)
    Naming.check_value(stmt.name, stmt, ctx.source, "Function")
    ctx:bind(frame.symbols, stmt.name, "function")

    Naming.check_type(stmt.return_type, ctx.source)

    local scope = ctx:child_scope(frame.symbols)
    for i, param in ipairs(stmt.params) do
        if rawget(scope, param) then
            Error.throw(Error.Type.SEMANTIC_ERROR,
                "Duplicate parameter '" .. param .. "'",
                stmt.line, stmt.col, ctx.source)
        end
        Naming.check_value(param, stmt, ctx.source, "Parameter")
        Naming.check_type(stmt.param_types[i], ctx.source)
        scope[param] = { kind = "variable", vtype = ctx:resolve_type(stmt.param_types[i]) }
    end

    local return_type = ctx:resolve_type(stmt.return_type)
    ctx:analyze_block(stmt.body, scope, true, false, return_type)
end)
