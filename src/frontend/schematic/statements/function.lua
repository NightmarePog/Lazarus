--- Semantic check for method / function declarations.
---
--- The name is bound in the enclosing scope *before* the body is walked, so a
--- function may call itself (recursion). The body is checked in a child scope
--- that inherits the enclosing declarations and adds the parameters. A top-level
--- **instance** method (not `static`, not nested in a function) is analysed with
--- a receiver in scope (`in_instance`), so `.field` accesses are permitted.

local Error = require("error")
local StatementCheck = require("frontend.schematic.statements.statement_check")
local Naming = require("frontend.schematic.naming")

return StatementCheck.new("FunctionDecl", function(ctx, frame)
    local stmt = frame.stmt --[[@as FunctionDecl]]
    ctx:check_duplicate(frame.symbols, stmt.name, stmt)
    Naming.check_value(stmt.name, stmt, ctx.source, "Function")
    ctx:bind(frame.symbols, stmt.name, "function")

    local scope = ctx:child_scope(frame.symbols)

    -- An instance method has a receiver, so `.field` is valid in its body. Static
    -- methods and nested local functions do not. (`frame.in_function` is true for
    -- a nested declaration, which is an ordinary local function with no receiver.)
    local is_instance = not stmt.is_static and not frame.in_function

    for _, param in ipairs(stmt.params) do
        if rawget(scope, param) then
            Error.throw(
                Error.Type.SEMANTIC_ERROR,
                "Duplicate parameter '" .. param .. "'",
                stmt.line,
                stmt.col,
                ctx.source
            )
        end
        Naming.check_value(param, stmt, ctx.source, "Parameter")
        scope[param] = { kind = "variable" }
    end

    local outer = ctx.in_instance
    ctx.in_instance = is_instance
    ctx:analyze_block(stmt.body, scope, true, false)
    ctx.in_instance = outer
end)
