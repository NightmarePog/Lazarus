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
---
--- The language is untyped, so no value/annotation type checking happens here;
--- the only fact recorded is whether the value is provably not a function, used
--- to reject a later call on it (`expressions/call.lua`).
---
--- A top-level non-static visibility binding is an **instance property**: it is
--- reached only via `.field`, never as a bare name, so it is validated but *not*
--- bound into the scope (its name is collected up front in `schematic/init.lua`).
--- A `static` member, by contrast, is a bare-name class member and is bound.

local Error = require("error")
local StatementCheck = require("frontend.schematic.statements.statement_check")
local Naming = require("frontend.schematic.naming")
local Callability = require("frontend.schematic.callability")

return StatementCheck.new("VariableDecl", function(ctx, frame)
    local stmt = frame.stmt --[[@as VariableDecl]]
    local symbols = frame.symbols

    -- An instance property (top-level, visible, non-static): validate its name
    -- and default, but do not bind a bare name — it is only ever touched as `.x`.
    if not frame.in_function and stmt.visibility ~= nil and not stmt.is_static then
        Naming.check_value(stmt.name, stmt, ctx.source, "Property")
        if stmt.value then ctx:check_expr(stmt.value, symbols) end
        stmt.reassign = false
        return
    end

    -- A visibility modifier or `mut` forces a declaration; a bare form is a
    -- declaration only when the name is not already visible.
    local forced_decl = stmt.visibility ~= nil or stmt.mutable
    local existing = symbols[stmt.name]
    local is_decl = forced_decl or existing == nil

    if is_decl then
        if not frame.in_function and stmt.visibility == nil then
            Error.throw(
                Error.Type.SEMANTIC_ERROR,
                "Top-level binding '"
                    .. stmt.name
                    .. "' must declare visibility ('private' or 'public')",
                stmt.line,
                stmt.col,
                ctx.source,
                #stmt.name
            )
        end

        ctx:check_duplicate(symbols, stmt.name, stmt)
        Naming.check_value(stmt.name, stmt, ctx.source, "Binding")

        if stmt.value then ctx:check_expr(stmt.value, symbols) end

        ctx:bind(
            symbols,
            stmt.name,
            stmt.mutable and "variable" or "constant",
            stmt.mutable,
            Callability.is_noncallable(stmt.value)
        )
        stmt.reassign = false
    else
        if not existing.mutable then
            Error.throw(
                Error.Type.SEMANTIC_ERROR,
                "Cannot assign to immutable binding '" .. stmt.name .. "'",
                stmt.line,
                stmt.col,
                ctx.source,
                #stmt.name
            )
        end

        if stmt.value then
            ctx:check_expr(stmt.value, symbols)
            -- Keep the callability fact current so a value reassigned from a
            -- function to a scalar (or vice versa) is judged on its latest value.
            existing.noncallable = Callability.is_noncallable(stmt.value)
        end
        stmt.reassign = true
    end
end)
