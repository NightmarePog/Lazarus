--- Semantic check for variable bindings.
---
--- A binding statement is either a *declaration* or a *reassignment*:
---   • Forms carrying `private`/`public`/`mut` are always declarations.
---   • A bare `a = expr` is a declaration the first time the name is seen and a
---     reassignment thereafter — resolved here by scope lookup.
---
--- Rules enforced:
---   • Top-level declarations must carry a visibility modifier.
---   • Reassigning an immutable binding is an error.
---   • The initialiser is checked *before* the name is bound, so a declaration
---     cannot refer to itself (`private x = x` is undeclared `x`).

local Error          = require("error")
local StatementCheck = require("frontend.schematic.statements.statement_check")
local Naming         = require("frontend.schematic.naming")

return StatementCheck.new("VariableDecl", function(ctx, frame)
    local stmt    = frame.stmt --[[@as VariableDecl]]
    local symbols = frame.symbols

    -- A visibility modifier or `mut` forces a declaration; a bare form is a
    -- declaration only when the name is not already visible.
    local forced_decl = stmt.visibility ~= nil or stmt.mutable
    local existing    = symbols[stmt.name]
    local is_decl     = forced_decl or existing == nil

    if is_decl then
        if not frame.in_function and stmt.visibility == nil then
            Error.throw(Error.Type.SEMANTIC_ERROR,
                "Top-level binding '" .. stmt.name ..
                "' must declare visibility ('private' or 'public')",
                stmt.line, stmt.col, ctx.source, #stmt.name)
        end

        ctx:check_duplicate(symbols, stmt.name, stmt)
        Naming.check_value(stmt.name, stmt, ctx.source, "Binding")
        Naming.check_type(stmt.type_ann, ctx.source)

        -- Determine the binding's static type: the annotation if present and
        -- checked against the initialiser, otherwise inferred from it.
        local declared = ctx:resolve_type(stmt.type_ann)
        local vtype    = declared
        if stmt.value then
            ctx:check_expr(stmt.value, symbols)
            local value_type = ctx:infer(stmt.value, symbols)
            if declared ~= "any" then
                ctx:expect_assignable(declared, value_type, stmt.value,
                    "Binding '" .. stmt.name .. "'")
            else
                vtype = value_type
            end
        end

        ctx:bind(symbols, stmt.name, stmt.mutable and "variable" or "constant", stmt.mutable, vtype)
        stmt.reassign = false
    else
        if not existing.mutable then
            Error.throw(Error.Type.SEMANTIC_ERROR,
                "Cannot assign to immutable binding '" .. stmt.name .. "'",
                stmt.line, stmt.col, ctx.source, #stmt.name)
        end

        if stmt.value then
            ctx:check_expr(stmt.value, symbols)
            -- A typed mutable only accepts values of its declared type.
            local value_type = ctx:infer(stmt.value, symbols)
            ctx:expect_assignable(existing.vtype or "any", value_type, stmt.value,
                "Binding '" .. stmt.name .. "'")
        end
        stmt.reassign = true
    end
end)
