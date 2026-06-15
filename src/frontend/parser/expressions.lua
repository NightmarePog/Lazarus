--- Expression parsing rules for the recursive-descent parser.
---
--- Operator precedence (lowest → highest):
---   additive       (+  -)
---   multiplicative (*)
---   primary        (literals, identifiers, grouped expressions)
---
--- Each level calls the next-higher level for its operands, which
--- automatically enforces the correct binding strength.

local Error          = require("error")
local LiteralExpr    = require("frontend.parser.nodes.literal")
local IdentifierExpr = require("frontend.parser.nodes.identifier")
local BinaryExpr     = require("frontend.parser.nodes.binary")

return {
    --- Entry point — delegates to the lowest-precedence rule.
    ---@param self Parser
    ---@return Expr
    _expression = function(self)
        return self:_additive()
    end,

    --- Parse additive expressions (`+`, `-`), left-associative.
    ---@param self Parser
    ---@return Expr
    _additive = function(self)
        local left = self:_multiplicative()

        while self:_match("PLUS", "MINUS") do
            local op    = self:_previous() --[[@as Token]]
            local right = self:_multiplicative()
            left = BinaryExpr.new(op.type, left, right, op.line, op.column)
        end

        return left
    end,

    --- Parse multiplicative expressions (`*`), left-associative.
    ---@param self Parser
    ---@return Expr
    _multiplicative = function(self)
        local left = self:_primary()

        while self:_match("MULTIPLY") do
            local op    = self:_previous() --[[@as Token]]
            local right = self:_primary()
            left = BinaryExpr.new(op.type, left, right, op.line, op.column)
        end

        return left
    end,

    --- Parse a primary: a literal, identifier, or parenthesised sub-expression.
    ---@param self Parser
    ---@return Expr
    _primary = function(self)
        local token = self:_current()

        if not token then
            local prev = self:_previous()
            Error.throw(Error.Type.UNEXPECTED_EOF, "Unexpected end of input",
                (prev and prev.line)   --[[@as integer|nil]],
                (prev and prev.column) --[[@as integer|nil]],
                self.source)
        end

        local tok = token --[[@as Token]]

        if tok.type == "LEFT_BRACKET" then
            self:_advance()
            local expr = self:_expression()
            self:_consume("RIGHT_BRACKET", "Expected ')' after expression")
            return expr
        end

        if tok.type == "NUMBER" then
            self:_advance()
            return LiteralExpr.new("number", tok.literal, tok.line, tok.column)
        end

        if tok.type == "STRING" then
            self:_advance()
            return LiteralExpr.new("string", tok.literal, tok.line, tok.column)
        end

        if tok.type == "IDENTIFIER" then
            self:_advance()
            return IdentifierExpr.new(tok.value, tok.line, tok.column)
        end

        Error.throw(Error.Type.UNEXPECTED_TOKEN,
            "Unexpected token '" .. tok.value .. "'",
            tok.line, tok.column, self.source, #tok.value)
        error("unreachable")
    end,
}
