--- Semantic check for the C-style `for` loop.
---
--- The loop variable bound by `init` is a fresh, implicitly-**mutable** binding
--- scoped to the loop, so the `step` (e.g. `i += 1`) may reassign it. Being a
--- loop-local, it is exempt from the top-level visibility rule. The condition,
--- step and body all see that variable; the body runs in a further child scope
--- so its declarations do not leak.

local StatementCheck = require("frontend.schematic.statements.statement_check")
local Naming         = require("frontend.schematic.naming")

return StatementCheck.new("ForStmt", function(ctx, frame)
    local stmt  = frame.stmt --[[@as ForStmt]]
    local scope = ctx:child_scope(frame.symbols)

    if stmt.init then
        local init  = stmt.init --[[@as VariableDecl]]
        Naming.check_value(init.name, init, ctx.source, "Loop variable")
        Naming.check_type(init.type_ann, ctx.source)
        local vtype = ctx:resolve_type(init.type_ann)
        if init.value then
            ctx:check_expr(init.value, scope)
            local value_type = ctx:infer(init.value, scope)
            if vtype ~= "any" then
                ctx:expect_assignable(vtype, value_type, init.value, "Loop variable '" .. init.name .. "'")
            else
                vtype = value_type
            end
        end
        ctx:bind(scope, init.name, "variable", true, vtype)
        init.reassign = false
    end

    if stmt.condition then
        ctx:check_expr(stmt.condition, scope)
        ctx:expect_bool(stmt.condition, scope, "loop condition")
    end
    if stmt.step then
        ctx:analyze_block({ stmt.step }, scope, frame.in_function, true, frame.return_type)
    end

    ctx:analyze_block(stmt.body, ctx:child_scope(scope), frame.in_function, true, frame.return_type)
end)
