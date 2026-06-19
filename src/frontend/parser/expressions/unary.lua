--- Unary prefix expressions (`not x`). Binds tighter than every infix operator
--- but looser than calls, so `not f(x)` is `not (f(x))` and `not a == b` is
--- `(not a) == b` — matching Lua's precedence. Falls through to `_call` when no
--- prefix operator is present.

local UnaryExpr = require("frontend.parser.nodes.unary")

return {
    ---@param self Parser
    ---@return Expr
    _unary = function(self)
        if self:_check("NOT") then
            local op = self:_advance() --[[@as Token]]
            local operand = self:_unary()
            return UnaryExpr.new(op.type, operand, op.line, op.column)
        end
        return self:_call()
    end,
}
