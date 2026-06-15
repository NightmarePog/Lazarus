--- Expression emitter: converts an `Expr` AST node to a Lua source string.

local OP_MAP = { PLUS = "+", MINUS = "-", MULTIPLY = "*" }

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
        return node.name
    end

    if node.type == "BinaryExpr" then
        ---@cast node BinaryExpr
        local op = OP_MAP[node.op]
        assert(op, "emit_expr: unknown operator: " .. tostring(node.op))

        local l = emit_expr(node.left)
        local r = emit_expr(node.right)

        if node.left.type  == "BinaryExpr" then l = "(" .. l .. ")" end
        if node.right.type == "BinaryExpr" then r = "(" .. r .. ")" end

        return l .. " " .. op .. " " .. r
    end

    error("emit_expr: unknown node type: " .. tostring(node.type))
end

return emit_expr
