--- Postfix call expressions: a primary followed by zero or more argument lists.
---
--- Examples: `f`, `f()`, `f(a, b)`, `g()()`, `f(g(x))`. Calls bind tighter than
--- any infix operator, so they sit between `_binary` and `_primary`.

local CallExpr = require("frontend.parser.nodes.call")

return {
    ---@param self Parser
    ---@return Expr
    _call = function(self)
        local expr = self:_primary()

        while self:_check("LEFT_BRACKET") do
            local paren = self:_advance() --[[@as Token]]

            ---@type Expr[]
            local args = {}
            if not self:_check("RIGHT_BRACKET") then
                repeat
                    args[#args + 1] = self:_expression()
                until not self:_match("COMMA")
            end

            self:_consume("RIGHT_BRACKET", "Expected ')' after arguments")
            expr = CallExpr.new(expr, args, paren.line, paren.column)
        end

        return expr
    end,
}
