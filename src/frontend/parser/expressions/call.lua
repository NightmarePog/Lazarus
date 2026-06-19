--- Postfix expressions: a primary followed by zero or more argument lists
--- (`f(...)`) and field accesses (`.name`).
---
--- Examples: `f`, `f()`, `f(a, b)`, `g()()`, `f(g(x))`, `self.x`, `p.x.y`,
--- `obj.method()`. These bind tighter than any infix operator, so they sit
--- between `_binary` and `_primary`.

local CallExpr   = require("frontend.parser.nodes.call")
local MemberExpr = require("frontend.parser.nodes.member")

return {
    ---@param self Parser
    ---@return Expr
    _call = function(self)
        local expr = self:_primary()

        while true do
            if self:_check("LEFT_BRACKET") then
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
            elseif self:_check("DOT") then
                local dot   = self:_advance() --[[@as Token]]
                local field = self:_consume("IDENTIFIER", "Expected a field name after '.'")
                expr = MemberExpr.new(expr, field.value, dot.line, dot.column)
            else
                break
            end
        end

        return expr
    end,
}
