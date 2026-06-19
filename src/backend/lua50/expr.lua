--- Expression emitter: converts an `Expr` AST node to a Lua source string.

local Context = require("backend.lua50.context")

--- Lazarus binary operator token → Lua operator. Most map straight through;
--- `!=` becomes Lua's `~=`, `++` becomes Lua's `..`, and the logical/comparison
--- words are identical. `MODULO` is absent on purpose — Lua 5.0 has no `%`, so it
--- is synthesised in `emit_expr` instead.
local OP_MAP = {
    PLUS = "+", MINUS = "-", MULTIPLY = "*", DIVIDE = "/", POWER = "^",
    CONCAT = "..",
    EQ = "==", NEQ = "~=",
    LESS = "<", LESS_EQUAL = "<=", GREATER = ">", GREATER_EQUAL = ">=",
    AND = "and", OR = "or",
}

--- Lazarus unary operator token → Lua operator.
local UNARY_OP_MAP = { NOT = "not" }

---@type fun(node: Expr): string
local emit_expr

emit_expr = function(node)
    if node.type == "LiteralExpr" then
        ---@cast node LiteralExpr
        if node.kind == "string" then
            return string.format("%q", node.value)
        end
        return tostring(node.value)
    end

    if node.type == "IdentifierExpr" then
        ---@cast node IdentifierExpr
        return Context.emit_name(node.name)
    end

    if node.type == "MemberExpr" then
        ---@cast node MemberExpr
        local object = emit_expr(node.object)
        -- A binary or unary operand is not directly indexable; parenthesise it.
        if node.object.type == "BinaryExpr" or node.object.type == "UnaryExpr" then
            object = "(" .. object .. ")"
        end
        return object .. "." .. node.field
    end

    if node.type == "CallExpr" then
        ---@cast node CallExpr
        local args = {}
        for i, arg in ipairs(node.args) do
            args[i] = emit_expr(arg)
        end

        local callee = emit_expr(node.callee)
        -- A binary expression is not directly callable in Lua; parenthesise it
        -- defensively so the emitted text stays syntactically valid.
        if node.callee.type == "BinaryExpr" then
            callee = "(" .. callee .. ")"
        end

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

        if node.left.type  == "BinaryExpr" then l = "(" .. l .. ")" end
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
