--- Primary expressions: the atoms of the grammar — literals, identifiers, and
--- parenthesised sub-expressions. This is the tightest-binding level.

local Error          = require("error")
local LiteralExpr    = require("frontend.parser.nodes.literal")
local IdentifierExpr = require("frontend.parser.nodes.identifier")

return {
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

        if tok.type == "TRUE" or tok.type == "FALSE" then
            self:_advance()
            return LiteralExpr.new("boolean", tok.type == "TRUE", tok.line, tok.column)
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
