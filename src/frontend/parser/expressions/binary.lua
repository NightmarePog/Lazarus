--- Binary (infix) expression parsing via precedence climbing.
---
--- A single generic rule handles every infix operator. Precedence and the set
--- of operators are data — see `operators.lua`. Operands are parsed by the
--- next-tighter level (`_call`).

local BinaryExpr = require("frontend.parser.nodes.binary")
local PRECEDENCE = require("frontend.parser.expressions.operators")

return {
    --- Entry point — parse a full expression (lowest precedence).
    ---@param self Parser
    ---@return Expr
    _expression = function(self)
        return self:_binary(1)
    end,

    --- Parse a left-associative binary expression whose operators all have
    --- precedence `>= min_prec`. Recurses with `prec + 1` on the right so equal
    --- precedence groups to the left.
    ---@param self     Parser
    ---@param min_prec integer
    ---@return Expr
    _binary = function(self, min_prec)
        local left = self:_call()

        while true do
            local token = self:_current()
            if not token then break end

            local prec = PRECEDENCE[token.type]
            if not prec or prec < min_prec then break end

            self:_advance()
            local right = self:_binary(prec + 1)
            left = BinaryExpr.new(token.type, left, right, token.line, token.column)
        end

        return left
    end,
}
