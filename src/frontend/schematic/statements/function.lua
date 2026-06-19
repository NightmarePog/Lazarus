--- Semantic check for function declarations.
---
--- The name is bound in the enclosing scope *before* the body is walked, so a
--- function may call itself (recursion). The body is checked in a child scope
--- that inherits the enclosing declarations and adds the parameters.

local Error          = require("error")
local StatementCheck = require("frontend.schematic.statements.statement_check")

return StatementCheck.new("FunctionDecl", function(ctx, frame)
    local stmt = frame.stmt --[[@as FunctionDecl]]
    ctx:check_duplicate(frame.symbols, stmt.name, stmt)
    ctx:bind(frame.symbols, stmt.name, "function")

    local scope = ctx:child_scope(frame.symbols)
    for _, param in ipairs(stmt.params) do
        if rawget(scope, param) then
            Error.throw(Error.Type.SEMANTIC_ERROR,
                "Duplicate parameter '" .. param .. "'",
                stmt.line, stmt.col, ctx.source)
        end
        scope[param] = { kind = "variable" }
    end

    ctx:analyze_block(stmt.body, scope, true, false)
end)
