--- Expression emitter: converts an `Expr` AST node to a Lua source string.

local Context = require("backend.lua50.context")

--- Lazarus binary operator token → Lua operator. Most map straight through;
--- `!=` becomes Lua's `~=`, `++` becomes Lua's `..`, and the logical/comparison
--- words are identical. `MODULO` is absent on purpose — Lua 5.0 has no `%`, so it
--- is synthesised in `emit_expr` instead.
local OP_MAP = {
    PLUS = "+",
    MINUS = "-",
    MULTIPLY = "*",
    DIVIDE = "/",
    POWER = "^",
    CONCAT = "..",
    EQ = "==",
    NEQ = "~=",
    LESS = "<",
    LESS_EQUAL = "<=",
    GREATER = ">",
    GREATER_EQUAL = ">=",
    AND = "and",
    OR = "or",
}

--- Lazarus unary operator token → Lua operator.
local UNARY_OP_MAP = { NOT = "not" }

--- Built-in collection / Option methods. A `<expr>.<name>(args)` call whose
--- method name is here lowers to the runtime helper `__lz_<helper>(<expr>, args)`
--- instead of class-method dispatch — so these names are reserved as built-ins.
---@type table<string, string>
local BUILTIN_METHODS = {
    len = "__lz_len",
    push = "__lz_push",
    pop = "__lz_pop",
    get = "__lz_get",
    has = "__lz_has",
    is_some = "__lz_is_some",
    is_none = "__lz_is_none",
    unwrap = "__lz_unwrap",
    unwrap_or = "__lz_unwrap_or",
}

---@type fun(node: Expr): string
local emit_expr

emit_expr = function(node)
    if node.type == "LiteralExpr" then
        ---@cast node LiteralExpr
        if node.kind == "string" then return string.format("%q", node.value) end
        return tostring(node.value)
    end

    if node.type == "IdentifierExpr" then
        ---@cast node IdentifierExpr
        return Context.emit_name(node.name)
    end

    -- The implicit receiver of a `.field` access. There is no `self` keyword in
    -- the source; it lowers to the receiver name codegen passes to every instance
    -- member (`self`), so `.x` (a MemberExpr over this) becomes `self.x`.
    if node.type == "SelfExpr" then return "self" end

    if node.type == "MemberExpr" then
        ---@cast node MemberExpr
        local object = emit_expr(node.object)
        -- A binary or unary operand is not directly indexable; parenthesise it.
        if node.object.type == "BinaryExpr" or node.object.type == "UnaryExpr" then
            object = "(" .. object .. ")"
        end
        return object .. "." .. node.field
    end

    -- A list literal `[a, b, c]` lowers to a tagged value built by the runtime
    -- helper `__lz_list(a, b, c)`.
    if node.type == "ListExpr" then
        ---@cast node ListExpr
        Context.uses_collections = true
        local parts = {}
        for i, element in ipairs(node.elements) do
            parts[i] = emit_expr(element)
        end
        return "__lz_list(" .. table.concat(parts, ", ") .. ")"
    end

    -- A map literal `["k": v, …]` lowers to `__lz_map({ [k] = v, … })`.
    if node.type == "MapExpr" then
        ---@cast node MapExpr
        Context.uses_collections = true
        local parts = {}
        for i, entry in ipairs(node.entries) do
            parts[i] = "[" .. emit_expr(entry.key) .. "] = " .. emit_expr(entry.value)
        end
        return "__lz_map({" .. table.concat(parts, ", ") .. "})"
    end

    -- An index read `c[i]` lowers to `__lz_idx_get(c, i)` (the helper applies the
    -- 0-based→1-based offset for lists and uses the raw key for maps).
    if node.type == "IndexExpr" then
        ---@cast node IndexExpr
        Context.uses_collections = true
        return "__lz_idx_get(" .. emit_expr(node.object) .. ", " .. emit_expr(node.index) .. ")"
    end

    if node.type == "CallExpr" then
        ---@cast node CallExpr
        local args = {}
        for i, arg in ipairs(node.args) do
            args[i] = emit_expr(arg)
        end

        -- Built-in collection / Option method: `c.len()`, `o.unwrap()`, … lower to
        -- the matching runtime helper with the receiver as the first argument.
        if node.callee.type == "MemberExpr" and BUILTIN_METHODS[node.callee.field] then
            Context.uses_collections = true
            table.insert(args, 1, emit_expr(node.callee.object))
            return BUILTIN_METHODS[node.callee.field] .. "(" .. table.concat(args, ", ") .. ")"
        end

        -- Construction: calling the class by name lowers to `C.new(...)` (the
        -- class table itself is not callable). The class name is the only
        -- PascalCase identifier in call position; locals are snake_case.
        if node.callee.type == "IdentifierExpr" and node.callee.name == Context.class then
            return Context.class .. ".new(" .. table.concat(args, ", ") .. ")"
        end

        -- Instance-method dispatch: `obj.m(args)` where `m` is one of the
        -- class's instance methods lowers to receiver-passing `C.m(obj, args)`
        -- (no metatables). A field call on a name that is *not* a class method
        -- (e.g. an external object) is left as a plain `obj.m(args)`.
        if node.callee.type == "MemberExpr" and Context.instance_methods[node.callee.field] then
            local object = emit_expr(node.callee.object)
            if
                node.callee.object.type == "BinaryExpr"
                or node.callee.object.type == "UnaryExpr"
            then
                object = "(" .. object .. ")"
            end
            table.insert(args, 1, object)
            return Context.class
                .. "."
                .. node.callee.field
                .. "("
                .. table.concat(args, ", ")
                .. ")"
        end

        local callee = emit_expr(node.callee)
        -- A binary expression is not directly callable in Lua; parenthesise it
        -- defensively so the emitted text stays syntactically valid.
        if node.callee.type == "BinaryExpr" then callee = "(" .. callee .. ")" end

        return callee .. "(" .. table.concat(args, ", ") .. ")"
    end

    if node.type == "UnaryExpr" then
        ---@cast node UnaryExpr
        local op = UNARY_OP_MAP[node.op]
        assert(op, "emit_expr: unknown unary operator: " .. tostring(node.op))

        local operand = emit_expr(node.operand)
        -- A binary operand must be parenthesised: `not a == b` would otherwise
        -- parse as `(not a) == b` in Lua.
        if node.operand.type == "BinaryExpr" then operand = "(" .. operand .. ")" end
        return op .. " " .. operand
    end

    if node.type == "BinaryExpr" then
        ---@cast node BinaryExpr
        local l = emit_expr(node.left)
        local r = emit_expr(node.right)

        if node.left.type == "BinaryExpr" then l = "(" .. l .. ")" end
        if node.right.type == "BinaryExpr" then r = "(" .. r .. ")" end

        -- Lua 5.0 has no `%`; synthesise `a % b` as `(a - math.floor(a / b) * b)`.
        -- NOTE: this duplicates both operands, so side-effecting operands would
        -- evaluate twice. Acceptable for now; revisit by binding to temporaries.
        if node.op == "MODULO" then
            return "(" .. l .. " - math.floor(" .. l .. " / " .. r .. ") * " .. r .. ")"
        end

        local op = OP_MAP[node.op]
        assert(op, "emit_expr: unknown operator: " .. tostring(node.op))

        return l .. " " .. op .. " " .. r
    end

    error("emit_expr: unknown node type: " .. tostring(node.type))
end

return emit_expr
