--- Fold rule for binary expressions: constant folding.
---
--- Both operands are folded first; when both collapse to numeric literals the
--- whole node is evaluated at compile time and replaced with a single literal.
---
--- Note on algebraic identities (`x + 0 → x`, `x * 0 → 0`, `x * 1 → x`, …):
--- these are intentionally NOT applied to non-literal operands. Lazarus has no
--- type system, so an identifier could hold a non-numeric value at runtime
--- (e.g. a string), where Lua's arithmetic would raise an error. Rewriting
--- `s * 0` to `0` would silently delete that error and change observable
--- behaviour. The only sound case — both operands being numeric literals — is
--- already handled by constant folding below. Re-introduce identity rewrites
--- once a type-analysis pass can prove the surviving operand is numeric.

local FoldExpression = require("frontend.optimizer.expressions.expression_fold")
local LiteralExpr    = require("frontend.parser.nodes.literal")

--- Operators eligible for compile-time folding when both operands are numeric
--- literals. Division is absent until `/` is implemented across all stages
--- (lexer, parser, codegen).
local FOLD_OPS = {
    PLUS     = function(a, b) return a + b end,
    MINUS    = function(a, b) return a - b end,
    MULTIPLY = function(a, b) return a * b end,
}

---@param node Expr
---@return number?
local function num(node)
    if node.type ~= "LiteralExpr" then return nil end
    ---@cast node LiteralExpr
    if node.kind ~= "number" then return nil end
    return node.value --[[@as number]]
end

return FoldExpression.new("BinaryExpr", function(node, constants, recurse)
    ---@cast node BinaryExpr
    local left  = recurse(node.left,  constants)
    local right = recurse(node.right, constants)
    local lv    = num(left)
    local rv    = num(right)

    -- Constant folding: only when both operands are known numeric literals.
    if lv ~= nil and rv ~= nil then
        local fn = FOLD_OPS[node.op]
        if fn then return LiteralExpr.new("number", fn(lv, rv), node.line, node.col) end
    end

    node.left  = left
    node.right = right
    return node
end)
